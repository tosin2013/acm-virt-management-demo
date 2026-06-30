#!/usr/bin/env bash
# check-quota.sh — AWS quota pre-flight for ACM Virt Management Demo
#
# Checks that the target AWS region has sufficient quota for deploying
# the hub cluster + N student clusters (default: 2).
#
# Each OCP 4.22 IPI cluster on AWS typically requires:
#   - 3 control plane nodes (m6i.xlarge = 4 vCPU each = 12 vCPU)
#   - 3 worker nodes (m5.metal = 96 vCPU each = 288 vCPU for bare-metal/KVM)
#     OR standard workers (m6i.2xlarge = 8 vCPU each = 24 vCPU)
#   - 1 bastion (t3.medium = 2 vCPU)
#   - 1 VPC
#   - 2 Elastic IPs (API + ingress)
#   - 2 Network Load Balancers
#   - 1 NAT Gateway
#   - 1 S3 bucket (bootstrap ignition)
set -euo pipefail

REGION="${AWS_REGION:-us-east-2}"
NUM_STUDENTS="${NUM_STUDENTS:-2}"
TOTAL_CLUSTERS=$((1 + NUM_STUDENTS))
WORKER_TYPE="${WORKER_TYPE:-m5.metal}"
STUDENT_TYPE="${STUDENT_TYPE:-sno}"

echo "================================================================"
echo "  AWS Quota Pre-flight Check"
echo "  Region:   $REGION"
echo "  Clusters: $TOTAL_CLUSTERS (1 hub + $NUM_STUDENTS students)"
echo "  Hub workers:     $WORKER_TYPE"
echo "  Student type:    $STUDENT_TYPE"
echo "================================================================"
echo ""

# vCPU calculation for hub
if [[ "$WORKER_TYPE" == "m5.metal" ]]; then
  VCPU_PER_HUB_WORKER=96
elif [[ "$WORKER_TYPE" == "m6i.2xlarge" ]]; then
  VCPU_PER_HUB_WORKER=8
elif [[ "$WORKER_TYPE" == "m5.2xlarge" ]]; then
  VCPU_PER_HUB_WORKER=8
else
  VCPU_PER_HUB_WORKER=8
fi

VCPU_HUB_CONTROL=12     # 3 x m6i.xlarge (4 vCPU each)
VCPU_HUB_WORKERS=$((3 * VCPU_PER_HUB_WORKER))
VCPU_HUB_BASTION=2      # t3.medium
VCPU_HUB=$((VCPU_HUB_CONTROL + VCPU_HUB_WORKERS + VCPU_HUB_BASTION))

# vCPU calculation for student clusters
if [[ "$STUDENT_TYPE" == "sno" ]]; then
  # SNO: single bare-metal node (m5zn.metal = 48 vCPU) + bastion
  VCPU_PER_STUDENT=50    # 48 (m5zn.metal) + 2 (bastion)
  STUDENT_DESC="SNO m5zn.metal"
else
  # Multi-node: 3 masters + 3 metal workers + bastion
  VCPU_STUDENT_CONTROL=12
  VCPU_STUDENT_WORKERS=$((3 * VCPU_PER_HUB_WORKER))
  VCPU_STUDENT_BASTION=2
  VCPU_PER_STUDENT=$((VCPU_STUDENT_CONTROL + VCPU_STUDENT_WORKERS + VCPU_STUDENT_BASTION))
  STUDENT_DESC="multi-node $WORKER_TYPE"
fi

VCPU_TOTAL=$((VCPU_HUB + (VCPU_PER_STUDENT * NUM_STUDENTS)))

EIP_PER_CLUSTER=2
EIP_TOTAL=$((EIP_PER_CLUSTER * TOTAL_CLUSTERS))

VPC_TOTAL=$TOTAL_CLUSTERS
NLB_TOTAL=$((2 * TOTAL_CLUSTERS))
NAT_TOTAL=$TOTAL_CLUSTERS

PASS=0
FAIL=0
WARN=0

check_quota() {
  local label="$1"
  local required="$2"
  local quota="$3"
  local current="$4"
  local available=$((${quota%.*} - current))

  if (( available >= required )); then
    echo "  PASS  $label: need $required, available $available (quota ${quota%.*}, used $current)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label: need $required, available $available (quota ${quota%.*}, used $current)"
    echo "        → Request increase to at least $((current + required))"
    FAIL=$((FAIL + 1))
  fi
}

echo "Checking quotas..."
echo ""

# vCPU quota
VCPU_QUOTA=$(aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-1216C47A \
  --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "0")
VCPU_USED=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].CpuOptions.CoreCount' \
  --output text 2>/dev/null | awk '{s+=$1*2} END {print s+0}')
check_quota "On-Demand vCPUs" "$VCPU_TOTAL" "$VCPU_QUOTA" "$VCPU_USED"

# Elastic IPs
EIP_QUOTA=$(aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-0263D0A3 \
  --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "5")
EIP_USED=$(aws ec2 describe-addresses --region "$REGION" \
  --query 'Addresses' --output json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
check_quota "Elastic IPs" "$EIP_TOTAL" "$EIP_QUOTA" "$EIP_USED"

# VPCs
VPC_QUOTA=$(aws service-quotas get-service-quota \
  --service-code vpc --quota-code L-F678F1CE \
  --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "5")
VPC_USED=$(aws ec2 describe-vpcs --region "$REGION" \
  --query 'Vpcs' --output json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
check_quota "VPCs" "$VPC_TOTAL" "$VPC_QUOTA" "$VPC_USED"

# NAT Gateways
NAT_QUOTA=$(aws service-quotas get-service-quota \
  --service-code vpc --quota-code L-FE5A380F \
  --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "5")
NAT_USED=$(aws ec2 describe-nat-gateways --region "$REGION" \
  --filter "Name=state,Values=available" \
  --query 'NatGateways' --output json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
check_quota "NAT Gateways" "$NAT_TOTAL" "$NAT_QUOTA" "$NAT_USED"

# NLBs
NLB_QUOTA=$(aws service-quotas get-service-quota \
  --service-code elasticloadbalancing --quota-code L-69A177A2 \
  --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "50")
NLB_USED=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[?Type==`network`]' --output json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
check_quota "Network Load Balancers" "$NLB_TOTAL" "$NLB_QUOTA" "$NLB_USED"

echo ""
echo "================================================================"
echo "  Resource Requirements Summary"
echo "================================================================"
echo "  Hub cluster ($WORKER_TYPE workers):"
echo "    vCPUs:          $VCPU_HUB ($VCPU_HUB_CONTROL control + $VCPU_HUB_WORKERS workers + $VCPU_HUB_BASTION bastion)"
echo ""
echo "  Per student cluster ($STUDENT_DESC):"
echo "    vCPUs:          $VCPU_PER_STUDENT"
echo ""
echo "  Total for 1 hub + $NUM_STUDENTS student(s):"
echo "    vCPUs:          $VCPU_TOTAL"
echo "    Elastic IPs:    $EIP_TOTAL"
echo "    VPCs:           $VPC_TOTAL"
echo "    NAT Gateways:   $NAT_TOTAL"
echo "    NLBs:           $NLB_TOTAL"
echo ""
echo "  Results: $PASS passed, $FAIL failed"
echo "================================================================"

if (( FAIL > 0 )); then
  echo ""
  echo "  ACTION REQUIRED: Request quota increases before deploying."
  echo "  AWS Console → Service Quotas → EC2 / VPC"
  echo "  https://console.aws.amazon.com/servicequotas/home?region=${REGION}"
  echo ""
  exit 1
fi

echo ""
echo "  All quotas sufficient. Ready to deploy."
exit 0

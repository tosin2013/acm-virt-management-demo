"""
diagrams.py — ACM Virt Management Demo deck diagrams.
"""
from dgen import Scene, PALETTE


def architecture_overview():
    """Hub + Student cluster architecture."""
    s = Scene("r01-architecture", width=1300, height=620,
              title="ACM Virt Management — Architecture",
              subtitle="Hub cluster governs student clusters running OpenShift Virtualization workloads.")

    # Hub cluster panel
    s.panel(40, 90, 560, 480)
    s.label(60, 120, "Hub Cluster", size=16, weight="bold", color=PALETTE["rest"])

    s.box(60, 140, 240, 60, "RHACM 2.17", ["Policy Engine + Fleet Mgmt"], kind="rest")
    s.box(310, 140, 240, 60, "Observability", ["Grafana + Thanos"], kind="govern")
    s.box(60, 220, 240, 60, "OpenShift GitOps", ["ArgoCD + ApplicationSets"], kind="svc")
    s.box(310, 220, 240, 60, "OADP / Velero", ["Backup Orchestration"], kind="data")
    s.box(60, 300, 240, 60, "Fine-Grained RBAC", ["MulticlusterRoleAssignment"], kind="platform")
    s.box(310, 300, 240, 60, "Fleet Virt Console", ["Centralized VM Lifecycle"], kind="platform")
    s.box(60, 380, 240, 60, "Showroom", ["Interactive Lab Guide"], kind="neutral")
    s.box(310, 380, 240, 60, "cert-manager", ["TLS Automation"], kind="neutral")

    # Managed cluster panel
    s.panel(700, 90, 560, 480)
    s.label(720, 120, "Managed Cluster (Student)", size=16, weight="bold", color=PALETTE["svc"])

    s.box(720, 140, 240, 60, "OpenShift Virt", ["KVM-based VM Workloads"], kind="svc")
    s.box(970, 140, 240, 60, "Fedora VMs", ["Container Disk Deploy"], kind="svc")
    s.box(720, 220, 240, 60, "Windows VMs", ["Tekton Pipeline Build"], kind="data")
    s.box(970, 220, 240, 60, "OpenShift Pipelines", ["Golden Image Factory"], kind="data")
    s.box(720, 300, 240, 60, "Klusterlet Agent", ["Policy + Addon Framework"], kind="platform")
    s.box(970, 300, 240, 60, "Search Collector", ["Metadata Streaming"], kind="platform")
    s.box(720, 380, 240, 60, "Prometheus", ["VM Metrics Collection"], kind="govern")
    s.box(970, 380, 240, 60, "Config Policy Ctrl", ["Compliance Enforcement"], kind="govern")

    # Arrows hub -> managed
    s.arrow(550, 170, 700, 170, label="Policies", kind="rest")
    s.arrow(550, 250, 700, 250, label="VM Deployments", kind="svc")
    s.arrow(970, 410, 550, 340, label="Metrics + Search Data", kind="govern", dashed=True)

    # AWS panel at bottom
    s.panel(40, 540, 1220, 40, fill=PALETTE["panel"])
    s.label(650, 567, "AWS  |  m5.xlarge (hub workers)  |  m5zn.metal (student SNO, bare-metal KVM)",
            size=12, anchor="middle", color=PALETTE["muted"])

    s.write()


def data_flow():
    """Policy, deployment, and metrics data flow."""
    s = Scene("r02-data-flow", width=1300, height=580,
              title="Governance and Deployment Data Flow",
              subtitle="Policies, deployments, and metrics flow between hub and managed clusters.")

    # Left: Git
    s.box(40, 220, 160, 80, "Git Repo", ["VM manifests", "Policy definitions"], kind="data")

    # Center: Hub
    s.box(280, 100, 200, 70, "RHACM Policy Engine", ["Governance framework"], kind="rest")
    s.box(280, 220, 200, 70, "ArgoCD", ["ApplicationSets"], kind="svc")
    s.box(280, 340, 200, 70, "Thanos + Grafana", ["Fleet observability"], kind="govern")

    # Right: Managed clusters
    s.panel(580, 80, 320, 130)
    s.label(600, 105, "Managed Cluster 1", size=14, weight="bold", color=PALETTE["svc"])
    s.box(600, 120, 130, 60, "VMs", ["Fedora, Win"], kind="svc")
    s.box(750, 120, 130, 60, "Policies", ["Enforced"], kind="platform")

    s.panel(580, 240, 320, 130)
    s.label(600, 265, "Managed Cluster N", size=14, weight="bold", color=PALETTE["svc"])
    s.box(600, 280, 130, 60, "VMs", ["Fedora, Win"], kind="svc")
    s.box(750, 280, 130, 60, "Policies", ["Enforced"], kind="platform")

    # Right: Compliance
    s.box(1000, 160, 200, 80, "Compliance", ["NIST SP 800-53", "DISA STIG", "PCI-DSS"], kind="govern")

    # Arrows
    s.arrow(200, 250, 280, 250, kind="data", label="Manifests")
    s.arrow(480, 135, 580, 135, kind="rest", label="Propagate")
    s.arrow(480, 255, 580, 290, kind="svc", label="Deploy VMs")
    s.arrow(730, 180, 380, 345, kind="govern", label="Metrics", dashed=True)
    s.arrow(730, 340, 380, 375, kind="govern", dashed=True)
    s.arrow(880, 180, 1000, 195, kind="govern", label="Report")

    s.write()


def defense_in_depth():
    """Cluster destruction prevention — two-layer defense."""
    s = Scene("r03-defense-in-depth", width=1200, height=520,
              title="Defense-in-Depth: Eradicate Cluster Destruction",
              subtitle="Two independent layers ensure accidental or malicious deletion is impossible.")

    # Attacker
    s.box(40, 200, 180, 80, "Operator / Script", ["oc delete managedcluster"], kind="danger", mono=False)

    # Layer 1: RBAC
    s.panel(300, 80, 340, 180)
    s.label(320, 105, "Layer 1: Non-Destructive ClusterRole", size=13, weight="bold", color=PALETTE["rest"])
    s.box(320, 125, 290, 50, "ClusterRole", ["get, list, watch only"], kind="rest")
    s.box(320, 190, 290, 50, "No delete permission", ["on managedcluster resources"], kind="rest")

    # Layer 2: Admission
    s.panel(300, 290, 340, 180)
    s.label(320, 315, "Layer 2: ValidatingAdmissionPolicy", size=13, weight="bold", color=PALETTE["platform"])
    s.box(320, 335, 290, 50, "Admission Controller", ["CEL expression match"], kind="platform")
    s.box(320, 400, 290, 50, "DELETE blocked", ["on hive.openshift.io/*"], kind="platform")

    # Result
    s.box(740, 200, 200, 80, "Forbidden", ["403: cluster deletion", "is impossible"], kind="danger")

    # Checkmark result
    s.box(1010, 200, 160, 80, "Cluster Safe", ["Production workloads", "fully protected"], kind="platform")

    # Arrows
    s.arrow(220, 240, 300, 170, kind="danger", label="Attempt")
    s.arrow(220, 240, 300, 380, kind="danger")
    s.arrow(640, 170, 740, 220, kind="danger", label="Denied")
    s.arrow(640, 380, 740, 260, kind="danger", label="Denied")
    s.arrow(940, 240, 1010, 240, kind="platform")

    s.write()


def vm_lifecycle():
    """VM deployment methods across the workshop."""
    s = Scene("r04-vm-lifecycle", width=1300, height=560,
              title="VM Deployment Methods",
              subtitle="Three paths to production VMs — all Git-driven, no direct CLI access required.")

    # Path 1: ArgoCD
    s.panel(40, 100, 380, 160)
    s.label(60, 125, "Path 1: ArgoCD ApplicationSet", size=14, weight="bold", color=PALETTE["svc"])
    s.box(60, 145, 160, 50, "Git Repository", ["VM manifests"], kind="data")
    s.box(240, 145, 160, 50, "ArgoCD", ["Auto-sync"], kind="svc")
    s.arrow(220, 170, 240, 170, kind="svc")
    s.box(60, 210, 340, 30, "Fedora VMs deployed to all matching clusters", kind="neutral")

    # Path 2: Tekton
    s.panel(40, 290, 380, 160)
    s.label(60, 315, "Path 2: Tekton Pipeline", size=14, weight="bold", color=PALETTE["data"])
    s.box(60, 335, 160, 50, "Windows ISO", ["autounattend.xml"], kind="data")
    s.box(240, 335, 160, 50, "Pipeline Run", ["Build + Import"], kind="data")
    s.arrow(220, 360, 240, 360, kind="data")
    s.box(60, 400, 340, 30, "Windows Server 2019 golden image VM", kind="neutral")

    # Path 3: Subscription
    s.panel(40, 480, 380, 60)
    s.label(60, 510, "Path 3: Git Subscription (no cluster-admin)", size=14, weight="bold", color=PALETTE["platform"])

    # Right side: deployed VMs
    s.panel(480, 100, 380, 420)
    s.label(500, 125, "Managed Clusters", size=16, weight="bold", color=PALETTE["svc"])

    s.box(500, 155, 160, 60, "Fedora VM", ["4 vCPU, 4Gi RAM", "container disk"], kind="svc")
    s.box(680, 155, 160, 60, "Fedora VM", ["Right-sized", "1Gi RAM"], kind="svc")
    s.box(500, 240, 160, 60, "Windows VM", ["2019 Server", "ISO + DataVolume"], kind="data")
    s.box(680, 240, 160, 60, "Subscription VM", ["Git-driven", "Non-admin deploy"], kind="platform")

    # Governance overlay
    s.panel(500, 330, 340, 70)
    s.label(520, 350, "Governance Policies Applied", size=13, weight="bold", color=PALETTE["govern"])
    s.label(520, 370, "Right-sizing | Backup | Network | Security", size=12, color=PALETTE["muted"])

    s.panel(500, 415, 340, 70)
    s.label(520, 435, "Fleet Observability Active", size=13, weight="bold", color=PALETTE["govern"])
    s.label(520, 455, "Grafana dashboards | Thanos metrics | Alerts", size=12, color=PALETTE["muted"])

    # Arrows from paths to managed
    s.arrow(420, 190, 480, 185, kind="svc")
    s.arrow(420, 375, 480, 270, kind="data")
    s.arrow(420, 510, 480, 340, kind="platform", dashed=True)

    # Right side: ACM capabilities
    s.panel(920, 100, 340, 420)
    s.label(940, 125, "ACM Capabilities Proven", size=16, weight="bold", color=PALETTE["rest"])

    s.box(940, 155, 300, 45, "Fleet VM Governance", ["Policies as code"], kind="rest")
    s.box(940, 215, 300, 45, "Centralized Observability", ["Single pane of glass"], kind="govern")
    s.box(940, 275, 300, 45, "Right-Sizing Recommendations", ["Replace VMware DRS"], kind="govern")
    s.box(940, 335, 300, 45, "Fine-Grained RBAC", ["Zero-trust permissions"], kind="platform")
    s.box(940, 395, 300, 45, "Destruction Prevention", ["Defense-in-depth"], kind="danger")

    s.write()


def right_sizing_pipeline():
    """Metrics pipeline for VM right-sizing recommendations."""
    s = Scene("r05-right-sizing", width=1300, height=520,
              title="VM Right-Sizing Pipeline",
              subtitle="Kubernetes-native replacement for VMware DRS — continuous, automated recommendations.")

    # Source: VMs
    s.box(40, 200, 150, 80, "VM Workloads", ["CPU + memory", "usage metrics"], kind="svc")

    # Prometheus
    s.box(250, 200, 180, 80, "Prometheus", ["kubevirt metrics", "14-day window"], kind="govern")
    s.arrow(190, 240, 250, 240, kind="govern")

    # Recording rules
    s.box(500, 200, 200, 80, "Recording Rules", ["acm_rs_vm:cpu_*", "acm_rs_vm:mem_*"], kind="govern", mono=False)
    s.arrow(430, 240, 500, 240, kind="govern")

    # Thanos
    s.box(770, 200, 160, 80, "Thanos", ["Fleet aggregation", "Long-term storage"], kind="data")
    s.arrow(700, 240, 770, 240, kind="data")

    # Grafana dashboards
    s.box(1000, 120, 240, 60, "Fleet Dashboard", ["All clusters, all VMs"], kind="govern")
    s.box(1000, 200, 240, 60, "Namespace View", ["Per-namespace drill-down"], kind="govern")
    s.box(1000, 280, 240, 60, "Per-VM Detail", ["Specific recommendations"], kind="govern")
    s.arrow(930, 230, 1000, 150, kind="govern")
    s.arrow(930, 240, 1000, 230, kind="govern")
    s.arrow(930, 250, 1000, 310, kind="govern")

    # Action loop
    s.panel(40, 360, 1220, 110)
    s.label(60, 385, "Action: Operator applies live resize based on recommendation", size=14, weight="bold", color=PALETTE["rest"])
    s.label(60, 410, "Example: Fedora VM resized from 4Gi to 1Gi RAM — zero downtime, verified in Grafana",
            size=12, color=PALETTE["muted"])
    s.label(60, 435, "Thresholds configurable via rs-virt-config ConfigMap — tailor to your SLAs",
            size=12, color=PALETTE["muted"])

    s.write()


SCENES = [
    architecture_overview,
    data_flow,
    defense_in_depth,
    vm_lifecycle,
    right_sizing_pipeline,
]


if __name__ == "__main__":
    for fn in SCENES:
        fn()
        print(f"  built {fn.__name__}")

"use strict";

const H = require("./deck-helpers.js");
const {
  COLOR, FONT, W, ASSETS,
  newDeck, addFooter, addContentTitle, addBullets, addTwoColBullets,
  addStatusTable, addCaption, addCodeSlide, addDiagramSlide, addSectionDivider, addNotes,
} = H;

const OUT = "./output/acm-virt-management-demo-r01.0.pptx";
const REV = "r01.0";

const pres = newDeck();
pres.title = "ACM Virtual Machine Management";
pres.author = "Tosin Akinosho";
pres.company = "Red Hat";
let pageNum = 0;

function S() {
  const s = pres.addSlide(); pageNum += 1; addFooter(s, pageNum); return s;
}
function divider(code, title, subtitle, notes) {
  const s = pres.addSlide(); pageNum += 1; addSectionDivider(s, code, title, subtitle); addNotes(s, notes);
}

// ============================================================
// SLIDE 1 — COVER
// ============================================================
{
  const s = pres.addSlide();
  pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("MULTICLUSTER VM GOVERNANCE", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 6, align: "left", valign: "middle" });
  s.addText([
    { text: "ACM Virtual Machine", options: { breakLine: true } },
    { text: "Management" }
  ], {
    x: 5.95, y: 2.42, w: 6.95, h: 2.00, fontFace: FONT.title, fontSize: 48, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("Red Hat Advanced Cluster Management + OpenShift Virtualization", { x: 6.00, y: 4.65, w: 6.70, h: 0.50,
    fontFace: FONT.body, fontSize: 16, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  s.addText("Tosin Akinosho", { x: 6.00, y: 5.30, w: 6.70, h: 0.40,
    fontFace: FONT.body, fontSize: 18, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText(REV, { x: 11.85, y: 5.85, w: 0.95, h: 0.30, fontFace: FONT.mono, fontSize: 11, color: COLOR.caption, align: "right", valign: "middle" });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.80, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, "Welcome everyone to the ACM Virtual Machine Management workshop. Today we will explore how Red Hat Advanced Cluster Management combined with OpenShift Virtualization provides enterprise-grade multicluster VM governance. This demo proves eight key capabilities that solve real operational challenges faced by organizations managing hundreds of virtual machines across multiple OpenShift clusters. My name is Tosin Akinosho and I will be guiding you through this hands-on experience.");
}

// ============================================================
// SECTION 1 — WHY THIS WORKSHOP EXISTS
// ============================================================
divider("01", "Why This Workshop\nExists", "The enterprise VM governance gap.",
  "Let us start by understanding why this workshop matters. Organizations migrating away from legacy hypervisors face a critical governance gap — the tools they relied on for VM management don't translate to a Kubernetes-native world. This section frames the business challenge we are solving today.");

// SLIDE 3 — The Enterprise Challenge
{
  const s = S();
  addContentTitle(s, "THE PROBLEM", "Managing 200+ VMs across 15 clusters is broken");
  addBullets(s, [
    "No centralized VM governance — each cluster team manages policies independently, causing configuration drift",
    "Fragmented observability — operators log into each cluster individually, wasting hours per incident",
    "Overprivileged access — developers have cluster-admin everywhere because \"that is how it has always been done\"",
    "Destruction risk — a single oc delete managedcluster can take down production across an entire region",
    "Manual deployment — VM provisioning requires direct CLI access and tribal knowledge",
  ], { fontSize: 16 });
  addNotes(s, "Picture this scenario: you have a large enterprise running over 200 virtual machines across 15 OpenShift clusters in three regions. Each cluster team manages their own policies independently, creating configuration drift and compliance gaps. When an incident occurs, operators must log into each cluster individually to check VM health — wasting hours of precious response time. Developers have cluster-admin privileges everywhere because nobody has had time to set up proper RBAC. And the scariest part? A single mistyped command — oc delete managedcluster — could take down production workloads across an entire region. These are not theoretical problems. These are the operational realities that enterprise customers share with us every day.");
}

// SLIDE 4 — The Migration Imperative
{
  const s = S();
  addContentTitle(s, "THE OPPORTUNITY", "A unified Kubernetes-native VM control plane");
  addBullets(s, [
    "Organizations are migrating away from legacy hypervisor monopolies — but many workloads cannot yet be containerized",
    "OpenShift Virtualization runs KVM-based VMs natively on OpenShift — same platform, same tooling",
    "RHACM provides the governance layer — policies, RBAC, observability, and lifecycle management at fleet scale",
    "Result: one control plane for both containers and VMs across every cluster in every region",
  ], { fontSize: 16 });
  addCaption(s, "From fragmented VM management to unified multicluster governance.");
  addNotes(s, "The opportunity here is transformative. Organizations migrating away from VMware and other legacy hypervisors need to maintain operational rigor for workloads that simply cannot be containerized yet — databases, legacy Windows applications, specialized middleware. OpenShift Virtualization provides KVM-based VM hosting directly on the OpenShift platform, so your teams use the same tools, the same APIs, and the same workflows they already know. Red Hat Advanced Cluster Management adds the governance layer on top — declarative policies, fine-grained RBAC, fleet-wide observability, and lifecycle management that works at scale. The result is a single, unified control plane that manages both containers and virtual machines across every cluster in every region. That is what we are going to prove today.");
}

// ============================================================
// SECTION 2 — LEARNING OBJECTIVES
// ============================================================
divider("02", "Learning\nObjectives", "Eight capabilities you will prove today.",
  "This workshop is designed to prove eight specific capabilities of the RHACM plus OpenShift Virtualization combination. Each module builds on the previous one, telling a complete story from deployment through governance to operational safety. Let me walk you through what you will accomplish.");

// SLIDE 6 — What You Will Prove
{
  const s = S();
  addContentTitle(s, "EIGHT CAPABILITIES", "What you will prove in this workshop");
  addTwoColBullets(s,
    [
      { text: "1 · Deploy VMs at fleet scale via GitOps", options: { bullet: false } },
      { text: "2 · Visualize cross-cluster application topology", options: { bullet: false } },
      { text: "3 · Enforce VM governance as code", options: { bullet: false } },
      { text: "4 · Achieve fleet-wide observability", options: { bullet: false } },
    ],
    [
      { text: "5 · Right-size VMs with built-in recommendations", options: { bullet: false } },
      { text: "6 · Deploy VMs without cluster-admin", options: { bullet: false } },
      { text: "7 · Implement fine-grained RBAC with MRA", options: { bullet: false } },
      { text: "8 · Eradicate cluster destruction entirely", options: { bullet: false } },
    ],
    { fontSize: 17 }
  );
  addCaption(s, "Each module uses a Know (business context) and Show (hands-on) format.");
  addNotes(s, "Here are the eight capabilities we will prove today. First, we will deploy virtual machines at fleet scale using ArgoCD ApplicationSets and Tekton pipelines — no manual CLI access required. Second, we will visualize the cross-cluster topology so you can see exactly how your VMs, deployments, and clusters relate to each other. Third, we will enforce governance policies declaratively — right-sizing rules, backup schedules, network isolation, and security hardening, all as code. Fourth, we will show fleet-wide observability with custom Grafana dashboards and Thanos-backed metrics. Fifth, we will demonstrate the built-in VM right-sizing recommendations that replace VMware DRS functionality. Sixth, we will deploy VMs without needing cluster-admin privileges. Seventh, we will implement fine-grained RBAC using the new MulticlusterRoleAssignment API. And eighth, we will architecturally prevent cluster destruction — not just discourage it, but make it impossible. Each module follows a Know and Show format: first we explain the business value, then you do it hands-on.");
}

// ============================================================
// SECTION 3 — TECHNOLOGY STACK
// ============================================================
divider("03", "Technology\nStack", "Products, operators, and APIs.",
  "Before we dive into the hands-on modules, let me orient you on the technology stack we will be working with. Understanding these components and how they fit together will help you get the most out of each exercise.");

// SLIDE 8 — Core Products
{
  const s = S();
  addContentTitle(s, "RED HAT PRODUCTS", "Core platform components");
  addStatusTable(s, [
    { code: "RHACM 2.17+", name: "Advanced Cluster Management", purpose: "Multicluster governance, policy engine, fleet management, fine-grained RBAC" },
    { code: "OCP 4.22+", name: "OpenShift Container Platform", purpose: "Kubernetes platform with enterprise security and developer tooling" },
    { code: "CNV 4.22+", name: "OpenShift Virtualization", purpose: "KVM-based VM hosting — runs virtual machines natively on OpenShift" },
    { code: "OADP 1.6+", name: "API for Data Protection", purpose: "Velero-based VM backup with kubevirt plugin for consistent snapshots" },
    { code: "GitOps 1.21+", name: "OpenShift GitOps (ArgoCD)", purpose: "Declarative VM deployment via ApplicationSets across the fleet" },
    { code: "Pipelines", name: "OpenShift Pipelines (Tekton)", purpose: "Windows VM golden image build pipelines — ISO to running VM" },
  ], { colW: [2.60, 3.40, 6.09], rowH: 0.58 });
  addNotes(s, "Here is the technology stack. At the center is Red Hat Advanced Cluster Management version 2.17 or later — this provides the multicluster governance engine including the new fine-grained RBAC capabilities with MulticlusterRoleAssignment. OpenShift Container Platform 4.22 is our Kubernetes foundation. OpenShift Virtualization provides the KVM-based VM hosting layer — this is what lets us run virtual machines as native Kubernetes workloads. OADP gives us Velero-based backup with the kubevirt plugin for VM-consistent snapshots. OpenShift GitOps brings ArgoCD with ApplicationSet support for fleet-scale deployment. And OpenShift Pipelines provides Tekton for our Windows VM golden image build pipeline. All of these are production-supported Red Hat products, not community projects.");
}

// SLIDE 9 — RHACM Components
{
  const s = S();
  addContentTitle(s, "RHACM CAPABILITIES", "Governance components in action today");
  addStatusTable(s, [
    { code: "Policy Engine", name: "ConfigurationPolicy", purpose: "Declarative compliance — enforce VM config, backup, network, security policies" },
    { code: "Observability", name: "Grafana + Thanos", purpose: "Fleet-wide metrics aggregation with S3-backed long-term storage" },
    { code: "Fleet Virt", name: "Virtualization Perspective", purpose: "Centralized VM lifecycle — start, stop, restart, snapshot via cluster-proxy" },
    { code: "Fine RBAC", name: "MulticlusterRoleAssignment", purpose: "Distribute scoped Kubernetes roles across managed clusters (RHACM 2.17)" },
    { code: "Search", name: "search-collector addon", purpose: "Real-time metadata streaming from managed clusters to hub" },
    { code: "Admission", name: "ValidatingAdmissionPolicy", purpose: "CEL-based cluster destruction prevention — defense-in-depth" },
  ], { colW: [2.60, 3.40, 6.09], rowH: 0.58 });
  addNotes(s, "Let me highlight the specific RHACM capabilities we will exercise today. The Policy Engine uses ConfigurationPolicy resources to declaratively enforce compliance — everything from VM right-sizing recording rules to backup schedules to network isolation. The Observability stack combines Grafana and Thanos for fleet-wide metrics with S3-backed long-term storage. The Fleet Virtualization perspective is a new RHACM 2.16 feature that gives you centralized VM lifecycle management — you can start, stop, restart, and snapshot VMs across all your clusters from a single console. Fine-grained RBAC through MulticlusterRoleAssignment is brand new in RHACM 2.17 — it lets you distribute scoped Kubernetes roles to specific users across specific managed clusters. The search-collector addon streams real-time metadata from managed clusters to the hub. And ValidatingAdmissionPolicy with CEL expressions provides our second layer of cluster destruction prevention.");
}

// ============================================================
// SECTION 4 — ARCHITECTURE
// ============================================================
divider("04", "Architecture", "Hub and managed cluster topology.",
  "Now let us look at the architecture. Understanding how the hub and managed clusters connect is essential for appreciating how governance policies, VM deployments, and observability data flow across the fleet.");

// SLIDE 11 — Architecture Diagram
{
  const s = S();
  addDiagramSlide(s, "ENVIRONMENT", "Hub and managed cluster architecture", "r01-architecture",
    "Hub runs RHACM, GitOps, and Observability. Managed clusters run OpenShift Virtualization workloads.");
  addNotes(s, "Here is the architecture. On the left is the hub cluster running RHACM 2.17 — this is the governance brain. It hosts the policy engine, ArgoCD for GitOps deployments, Thanos and Grafana for fleet observability, OADP for backup orchestration, the Fleet Virtualization console plugin, fine-grained RBAC, and the Showroom interactive lab guide. On the right are the managed student clusters. These run OpenShift Virtualization with KVM-based VM workloads — both Fedora VMs deployed from container disks and Windows Server 2019 VMs built through Tekton pipelines. Each managed cluster has a klusterlet agent, search-collector, config-policy-controller, and Prometheus for local metrics. Policies flow from hub to managed clusters. VM deployments are pushed via ArgoCD. Metrics and search data flow back to the hub for fleet-wide aggregation. The hub workers run on m5.xlarge instances, while each student SNO cluster runs on a single m5zn.metal bare-metal instance providing 48 vCPUs and 192 GiB of RAM for full KVM support.");
}

// SLIDE 12 — Data Flow Diagram
{
  const s = S();
  addDiagramSlide(s, "DATA FLOW", "Governance, deployment, and metrics pipeline", "r02-data-flow",
    "Git-driven policies and VMs propagate to clusters; metrics and compliance data flow back to the hub.");
  addNotes(s, "This diagram shows how data flows through the system. Starting from the left, Git is the single source of truth for both VM manifests and policy definitions. The RHACM policy engine propagates governance policies to all managed clusters via the governance-policy-propagator and config-policy-controller. ArgoCD deploys VMs to managed clusters using ApplicationSets with the clusterDecisionResource generator — this is what enables fleet-scale deployment where new clusters automatically receive the correct VM workloads. Metrics flow in the opposite direction: Prometheus on each managed cluster collects kubevirt VM metrics, which are streamed to the hub Thanos instance via the observability addon. Grafana dashboards on the hub provide fleet-wide, per-cluster, and per-VM views. Compliance data also flows back, with policy status reports mapped to NIST SP 800-53, DISA STIG, HIPAA, and PCI-DSS frameworks.");
}

// ============================================================
// SECTION 5 — WORKSHOP AGENDA
// ============================================================
divider("05", "Workshop\nAgenda", "Eight modules, approximately 90 minutes.",
  "Here is the workshop agenda. We have eight modules that build on each other, taking approximately 90 minutes total. Each module follows the Know and Show pattern — first we establish the business context, then you execute the hands-on steps.");

// SLIDE 14 — Agenda Overview
{
  const s = S();
  addContentTitle(s, "AGENDA", "Workshop flow — eight modules");
  addTwoColBullets(s,
    [
      { text: "Module 1: Deploy VM Workloads", options: { bullet: false, bold: true } },
      { text: "ArgoCD + Tekton — 10 min", muted: true },
      { text: "Module 2: Application Topology", options: { bullet: false, bold: true } },
      { text: "Interactive graphs + Fleet Virt — 8 min", muted: true },
      { text: "Module 3: VM Policies and Governance", options: { bullet: false, bold: true } },
      { text: "Compliance as code — 10 min", muted: true },
      { text: "Module 4: Fleet Observability", options: { bullet: false, bold: true } },
      { text: "Grafana + Thanos dashboards — 10 min", muted: true },
    ],
    [
      { text: "Module 5: VM Right-Sizing", options: { bullet: false, bold: true } },
      { text: "Replace VMware DRS — 15 min", muted: true },
      { text: "Module 6: Deploy Without Cluster-Admin", options: { bullet: false, bold: true } },
      { text: "Git Subscriptions — 8 min", muted: true },
      { text: "Module 7: Fine-Grained Permissions", options: { bullet: false, bold: true } },
      { text: "MulticlusterRoleAssignment — 10 min", muted: true },
      { text: "Module 8: Eradicate Cluster Destruction", options: { bullet: false, bold: true } },
      { text: "Defense-in-depth — 6 min", muted: true },
    ],
    { fontSize: 16 }
  );
  addCaption(s, "Total workshop time: ~90 minutes. Each module builds on the previous.");
  addNotes(s, "Here is how the workshop flows. Module 1 covers VM deployment using both ArgoCD ApplicationSets for Fedora VMs and Tekton pipelines for Windows Server 2019 golden images. Module 2 shows the ACM application topology views and the Fleet Virtualization perspective for centralized VM lifecycle management. Module 3 introduces governance policies — right-sizing recording rules, backup enforcement with OADP and Velero, network isolation with default-deny NetworkPolicies, resource guardrails with LimitRanges, and security hardening. Module 4 takes us into fleet observability with custom Grafana dashboards, Thanos-backed metrics, and custom alerting. Module 5 is the right-sizing deep dive — this is the VMware DRS replacement, including a live resize of a Fedora VM from 4Gi to 1Gi RAM. Module 6 proves zero-trust deployment using Git Subscriptions without cluster-admin. Module 7 introduces the new MulticlusterRoleAssignment API for distributing scoped roles. And Module 8 is the finale — architecturally preventing cluster destruction with two independent safety layers.");
}

// ============================================================
// SECTION 6 — MODULE DEEP DIVES
// ============================================================
divider("06", "Module\nDeep Dives", "Key concepts from each module.",
  "Let me walk you through the key concepts from each module so you have context before we begin the hands-on exercises. These summaries highlight the business value and technical approach for each capability.");

// SLIDE 16 — Module 1: Deploy VM Workloads
{
  const s = S();
  addContentTitle(s, "MODULE 1", "Deploy VM workloads at fleet scale");
  addBullets(s, [
    "ArgoCD ApplicationSets with clusterDecisionResource generator — new clusters automatically receive VMs",
    "Fedora VMs deployed from container disks (quay.io/containerdisks/fedora) — no ISO management needed",
    "Windows Server 2019 built via Tekton pipeline — ISO import, autounattend.xml, DataVolume creation",
    "ManagedClusterSet + Placement + GitOpsCluster bind ArgoCD to RHACM fleet topology",
    "Git is the single source of truth — no human touches a cluster CLI for deployment",
  ], { fontSize: 16 });
  addNotes(s, "Module 1 is where the story begins — deploying virtual machines at fleet scale using GitOps. We start by integrating ArgoCD with RHACM through the ManagedClusterSet, Placement, and GitOpsCluster APIs. This gives ArgoCD awareness of your entire fleet topology. Then we deploy Fedora VMs using an ApplicationSet with the clusterDecisionResource generator. This is powerful because it is dynamic — when a new cluster is added to the ManagedClusterSet, it automatically receives the VM workloads. No manual intervention needed. Fedora VMs are deployed from container disks hosted on quay.io, eliminating ISO management entirely. For Windows, we use a Tekton pipeline that imports the Server 2019 ISO into an in-cluster HTTP file server, creates a DataVolume with an autounattend.xml for unattended installation, and produces a running Windows VM. The key takeaway: Git is the single source of truth. No human touches a cluster CLI for deployment.");
}

// SLIDE 17 — Module 1: Deployment Paths Diagram
{
  const s = S();
  addDiagramSlide(s, "MODULE 1", "Three paths to production VMs", "r04-vm-lifecycle",
    "ArgoCD for Linux fleet, Tekton for Windows golden images, Git Subscriptions for non-admin deployments.");
  addNotes(s, "This diagram illustrates the three VM deployment paths you will use in the workshop. Path 1 is ArgoCD ApplicationSets for Fedora VMs — Git manifests are synced automatically to all matching clusters. Path 2 is the Tekton pipeline for Windows Server 2019 — taking a raw ISO through an automated build process to produce a golden image VM. Path 3, which we cover in Module 6, uses Git Subscriptions for deployment without cluster-admin privileges. On the right side you can see the resulting VMs on the managed clusters, the governance policies that are automatically applied, and the fleet observability that activates. The far right column shows the eight ACM capabilities that this workshop proves. Every deployment path is Git-driven — no direct CLI access required.");
}

// SLIDE 18 — Module 2: Application Topology
{
  const s = S();
  addContentTitle(s, "MODULE 2", "Application topology and Fleet Virtualization");
  addBullets(s, [
    "ACM topology graph shows cross-cluster dependencies — Subscriptions, Deployments, Pods, VMs in one interactive view",
    "Fleet Virtualization perspective provides centralized VM lifecycle management (RHACM 2.16+)",
    "Start, stop, restart, pause, snapshot VMs across all clusters from the hub console",
    "VM operations proxy through the cluster-proxy framework — no direct cluster access needed",
    "Remote log retrieval for VMs directly from the topology view",
  ], { fontSize: 16 });
  addNotes(s, "Module 2 showcases two powerful visualization and management capabilities. First, the ACM application topology graph. This is an interactive view that shows your cross-cluster dependencies — you can see how Subscriptions connect to Deployments, which create Pods and VMs, all mapped across your clusters. It is invaluable for understanding the blast radius of a change. Second, the Fleet Virtualization perspective, which is new in RHACM 2.16. This gives you a centralized VM management console where you can see every virtual machine across every managed cluster, and perform lifecycle operations — start, stop, restart, pause, and snapshot — all from the hub. These operations proxy through the cluster-proxy framework, so you never need direct access to the managed clusters. You can even retrieve VM logs directly from the topology view.");
}

// SLIDE 19 — Module 3: Governance Policies
{
  const s = S();
  addContentTitle(s, "MODULE 3", "VM policies and governance as code");
  addStatusTable(s, [
    { code: "Right-Sizing", name: "PrometheusRule", purpose: "Recording rules for CPU and memory utilization analysis (NIST CM-2)" },
    { code: "Backup", name: "OADP + Velero", purpose: "Daily backup schedules enforced across all VM namespaces (NIST CP-9)" },
    { code: "Network", name: "NetworkPolicy", purpose: "Default-deny ingress — explicit allow required per service (NIST SC-7)" },
    { code: "Resources", name: "LimitRange", purpose: "CPU/memory guardrails prevent resource contention (NIST CM-7)" },
    { code: "Eviction", name: "VirtualMachinePreference", purpose: "Eviction strategy ensures graceful VM handling (NIST CP-2)" },
    { code: "Security", name: "ClusterPreference", purpose: "Hardened boot and security configuration baselines (NIST SC-28)" },
  ], { colW: [2.40, 3.00, 6.69], rowH: 0.56 });
  addCaption(s, "All policies mapped to NIST SP 800-53 controls — also applicable to DISA STIG, HIPAA, and PCI-DSS.");
  addNotes(s, "Module 3 is where governance becomes concrete. We deploy six categories of ConfigurationPolicies, each mapped to specific NIST SP 800-53 compliance controls. Right-sizing policies deploy Prometheus recording rules that calculate CPU and memory utilization patterns — this maps to CM-2 Baseline Configuration. Backup policies enforce daily Velero schedules with the kubevirt plugin across all VM namespaces — that is CP-9 System Backup. Network isolation applies default-deny NetworkPolicies, requiring explicit allow rules per service — SC-7 Boundary Protection. Resource guardrails use LimitRange to prevent any single VM from monopolizing cluster resources — CM-7 Least Functionality. Eviction strategy policies ensure VMs are handled gracefully during node maintenance — CP-2 Contingency Plan. And security hardening applies VirtualMachineClusterPreference baselines — SC-28 Protection of Information at Rest and CM-6 Configuration Settings. These mappings are not theoretical — they are annotations on the actual policy objects, ready for auditor review.");
}

// SLIDE 20 — Module 4: Fleet Observability
{
  const s = S();
  addContentTitle(s, "MODULE 4", "Fleet-wide observability with custom dashboards");
  addBullets(s, [
    "Cluster Overview dashboard — fleet-wide health at a glance across all managed clusters",
    "Single cluster deep dive — per-cluster resource utilization, VM density, and health metrics",
    "Custom VM fleet dashboard deployed as code — dashboards-as-code via ConfigurationPolicy",
    "Thanos Ruler for custom alerting — trigger on fleet-wide VM conditions, not just per-cluster",
    "Right-sizing opportunity identification — surface VMs consuming more resources than needed",
  ], { fontSize: 16 });
  addNotes(s, "Module 4 takes us into fleet-wide observability. We start with the Cluster Overview Grafana dashboard that gives you fleet-wide health at a glance — CPU and memory utilization across all managed clusters on a single screen. Then we drill down to individual clusters with the single cluster deep dive view, showing per-cluster resource utilization, VM density, and health metrics. What makes this powerful is that all metrics are aggregated by Thanos, so you have a single queryable endpoint for your entire fleet with S3-backed long-term storage. We also deploy a custom VM fleet dashboard using dashboards-as-code — the dashboard definition is pushed as a ConfigurationPolicy, so it appears automatically on every hub cluster in your organization. Thanos Ruler enables custom alerting that triggers on fleet-wide conditions, not just per-cluster thresholds. And the right-sizing opportunity panels surface VMs that are consuming significantly more resources than they need — which leads us directly into Module 5.");
}

// SLIDE 21 — Module 5: Right-Sizing
{
  const s = S();
  addDiagramSlide(s, "MODULE 5", "VM right-sizing — replace VMware DRS", "r05-right-sizing",
    "Continuous right-sizing recommendations with live resize capability — zero downtime.");
  addNotes(s, "Module 5 is the VMware DRS replacement story. This diagram shows the metrics pipeline. VM workloads emit CPU and memory usage metrics, which Prometheus collects and stores with a 14-day analysis window. Recording rules with the acm_rs_vm prefix calculate utilization patterns — peak, average, and P95 values. Thanos aggregates these across the fleet for the complete picture. Three levels of Grafana dashboards surface the recommendations: the fleet dashboard shows all clusters and all VMs, the namespace view allows per-namespace drill-down, and the per-VM detail view shows specific resize recommendations. The key demo moment is the live resize — we take a Fedora VM that was provisioned with 4Gi of RAM, show that the recommendation says it only needs 1Gi, execute the live resize with zero downtime, and verify the change in Grafana. Customers are impressed by this because it directly replaces VMware DRS functionality with a Kubernetes-native solution. The recommendation thresholds are fully configurable via the rs-virt-config ConfigMap, so customers can tailor them to their own SLAs.");
}

// SLIDE 22 — Module 6: Zero-Trust Deployment
{
  const s = S();
  addContentTitle(s, "MODULE 6", "Deploy VMs without cluster-admin");
  addBullets(s, [
    "The problem: traditional VM deployment requires cluster-admin — an overprivileged, risky practice",
    "Solution: Git Subscription model — Channel + Placement + Subscription resources",
    "The subscription-admin ClusterRoleBinding grants deploy rights without cluster-admin privileges",
    "VM manifests live in Git, RHACM propagates them — operators never need direct cluster access",
    "Verification: prove that the non-admin user cannot perform destructive operations",
  ], { fontSize: 16 });
  addNotes(s, "Module 6 addresses the overprivileged access problem directly. In most organizations, deploying VMs requires cluster-admin privileges — because that is how it has always been done. This is risky. A user with cluster-admin can do anything, including deleting critical infrastructure. Our solution uses the RHACM Git Subscription model. We create a Channel that points to the Git repository containing VM manifests, a Placement that targets the correct managed clusters, and a Subscription that binds them together. The subscription-admin ClusterRoleBinding grants exactly the permissions needed to deploy VMs — and nothing more. The VM manifests live in Git, and RHACM propagates them to the target clusters. Operators never need direct cluster access. In the verification step, we prove that the non-admin user can deploy VMs successfully but cannot perform destructive operations like deleting the managed cluster or modifying governance policies. This is zero-trust deployment in practice.");
}

// SLIDE 23 — Module 7: Fine-Grained RBAC
{
  const s = S();
  addContentTitle(s, "MODULE 7", "Fine-grained permissions with MulticlusterRoleAssignment");
  addBullets(s, [
    "Enable fine-grained RBAC in MultiClusterHub — a foundational capability in RHACM 2.17",
    "Two-level model: hub-level roles control ACM console access, spoke-level roles control cluster actions",
    "MulticlusterRoleAssignment (MRA) distributes kubevirt.io:edit role to specific users on specific clusters",
    "Console-based role assignment UI for day-two operations — no YAML required",
    "Demo: compare admin console view vs. scoped vm-operator console — dramatic difference in permissions",
  ], { fontSize: 16 });
  addNotes(s, "Module 7 introduces the new MulticlusterRoleAssignment API, which is one of the headline features of RHACM 2.17. We start by enabling fine-grained RBAC in the MultiClusterHub configuration. The model has two levels: hub-level roles control what a user can see and do in the ACM console, and spoke-level roles control what actions they can perform on managed clusters. We create a scoped vm-operator user and use MulticlusterRoleAssignment to distribute the kubevirt.io:edit ClusterRole — this gives them permission to manage VMs but nothing else. The console comparison is the compelling demo moment: we show the admin view side by side with the vm-operator view, and the difference is dramatic. The admin sees everything — all clusters, all resources, all actions. The vm-operator sees only the VMs they are authorized to manage, on only the clusters they are assigned to. RHACM 2.17 also includes a console-based UI for creating role assignments, so day-two operations do not require YAML.");
}

// SLIDE 24 — Module 8: Eradicate Cluster Destruction
{
  const s = S();
  addDiagramSlide(s, "MODULE 8", "Eradicate cluster destruction — defense-in-depth", "r03-defense-in-depth",
    "Two independent safety layers make accidental or malicious cluster deletion architecturally impossible.");
  addNotes(s, "Module 8 is the grand finale, and it is designed to leave a lasting impression. The diagram shows our defense-in-depth approach with two independent safety layers. Layer 1 is a non-destructive ClusterRole that replaces the default permissions — it only allows get, list, and watch operations on managedcluster resources. No delete permission exists in the role. Layer 2 is a ValidatingAdmissionPolicy with a CEL expression that matches DELETE operations on hive.openshift.io resources and rejects them unconditionally. These two layers are independent — even if an attacker bypasses the RBAC layer through a misconfiguration or privilege escalation, the admission controller still blocks the deletion. The demo moment is the destruction test: we attempt to delete the managed cluster using oc delete managedcluster, and it fails with a 403 Forbidden error from the admission controller. The cluster is safe. The workloads are protected. This is not a best practice recommendation — it is an architectural guarantee. The customer walks away knowing that cluster destruction is not just unlikely, it is impossible.");
}

// ============================================================
// SECTION 7 — EXPECTED OUTCOMES
// ============================================================
divider("07", "Expected\nOutcomes", "What you will walk away with.",
  "After completing all eight modules, here is what you will have proven and what we recommend as next steps for your organization.");

// SLIDE 26 — Business Outcomes
{
  const s = S();
  addContentTitle(s, "PROVEN OUTCOMES", "What this workshop demonstrates");
  addBullets(s, [
    "Unified governance — one policy engine managing VMs and containers across all clusters",
    "Operational efficiency — fleet-wide observability eliminates per-cluster context switching",
    "Zero-trust deployment — Git is the single source of truth, no human CLI access to production",
    "Cost optimization — right-sizing recommendations surface overprovisioned VMs for immediate savings",
    "Compliance readiness — policies mapped to NIST SP 800-53, DISA STIG, HIPAA, and PCI-DSS",
    "Architectural safety — cluster destruction is impossible, not just discouraged",
  ], { fontSize: 16 });
  addNotes(s, "Let me summarize the business outcomes we have proven. First, unified governance — a single policy engine that manages both VMs and containers across every cluster in your fleet. No more per-cluster policy drift. Second, operational efficiency — fleet-wide observability means your operators see everything from one console. No more logging into 15 clusters to troubleshoot an incident. Third, zero-trust deployment — Git is the single source of truth. No human needs CLI access to production to deploy or manage VMs. Fourth, cost optimization — the right-sizing recommendations immediately surface overprovisioned VMs. In a fleet of 200+ VMs, even a 20% memory reduction across overprovisioned workloads translates to significant infrastructure savings. Fifth, compliance readiness — every governance policy is annotated with the specific NIST SP 800-53 control it satisfies, and the mappings extend to DISA STIG, HIPAA, and PCI-DSS frameworks. Your auditors can inspect the policies directly. And sixth, architectural safety — we have proven that cluster destruction is not a matter of discipline or process, it is architecturally impossible.");
}

// SLIDE 27 — Next Steps
{
  const s = S();
  addContentTitle(s, "NEXT STEPS", "Recommended path forward");
  addBullets(s, [
    { text: "1 · Proof of Concept — deploy RHACM + OpenShift Virtualization in your environment", options: { bullet: false } },
    { text: "2 · Policy Customization — tailor governance policies to your compliance requirements and SLAs", options: { bullet: false } },
    { text: "3 · RBAC Design Workshop — map your team structure to MulticlusterRoleAssignment configurations", options: { bullet: false } },
    { text: "4 · Migration Planning — use Migration Toolkit for Virtualization (MTV) for existing VM estates", options: { bullet: false } },
    { text: "5 · Progressive Rollout — start with non-production clusters, expand as confidence grows", options: { bullet: false } },
  ], { fontSize: 16 });
  addCaption(s, "Your Red Hat account team can help scope and plan each of these steps.");
  addNotes(s, "Here are the recommended next steps for your organization. First, a Proof of Concept — we deploy RHACM and OpenShift Virtualization in your environment with a representative subset of your VM workloads. This validates that everything we showed today works with your specific infrastructure and security requirements. Second, policy customization — we tailor the governance policies to your compliance frameworks and SLAs. The workshop used reference policies; your policies will reflect your organization's specific requirements. Third, an RBAC Design Workshop — this is where we map your team structure, your approval processes, and your least-privilege requirements to MulticlusterRoleAssignment configurations. Getting RBAC right from the start prevents the cluster-admin sprawl that plagues most organizations. Fourth, migration planning — for customers with existing VMware estates, the Migration Toolkit for Virtualization provides automated VM migration to OpenShift Virtualization. And fifth, a progressive rollout — start with non-production clusters to build operational confidence, then expand to production as your teams gain experience. Your Red Hat account team can help scope and plan each of these steps.");
}

// ============================================================
// SECTION 8 — QUESTIONS
// ============================================================
divider("08", "Questions?", "Let us discuss.",
  "We have covered a lot of ground today. Let us open the floor for questions before we move into the hands-on modules.");

// SLIDE 29 — Questions / Contact
{
  const s = S();
  addContentTitle(s, "THANK YOU", "Ready for the hands-on workshop");
  addBullets(s, [
    "Workshop guide available in your Showroom environment",
    "Each module includes click-to-execute commands — no copy-paste errors",
    "Presenter: Tosin Akinosho",
    "All workshop content is open source and available for reference",
  ], { fontSize: 18 });
  addCaption(s, "Let's begin the hands-on exercises.");
  addNotes(s, "Thank you for your attention during this overview. The hands-on workshop guide is available in your Showroom environment — it is an interactive Antora-based lab guide with embedded terminals. Every command is click-to-execute, so you will not have any copy-paste errors. I am Tosin Akinosho, and I will be available throughout the workshop to answer questions and help with any issues. All of the workshop content — the lab guide, the deployment automation, the policies, and the VM manifests — is open source and available in the GitHub repository for your reference after today. Let's begin.");
}

// ============================================================
// BUILD
// ============================================================
pres.writeFile({ fileName: OUT })
  .then(p => console.log("WROTE", p))
  .catch(e => { console.error(e); process.exit(1); });

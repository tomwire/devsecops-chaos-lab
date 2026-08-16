# DevSecOps Pipeline & Chaos Engineering Lab

A production-grade security automation and resilience engineering platform that demonstrates **shift-left security** integrated into every stage of the CI/CD pipeline, paired with **chaos engineering experiments** validating self-healing behavior under real-world failure conditions.

> **Portfolio Project** — Demonstrates proactive security hygiene, SRE-minded reliability engineering, and automated chaos validation in a unified GitOps delivery platform.

[![CI Pipeline](https://img.shields.io/badge/CI-Pipeline-green.svg)](.github/workflows/ci.yml)
[![Chaos Engineering](https://img.shields.io/badge/Chaos-Experiments-blue.svg)](chaos-engineering/)
[![Terraform](https://img.shields.io/badge/Terraform-1.10+-orange.svg)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📚 Table of Contents

- [Architecture](#architecture)
- [Security Gates](#security-gates)
- [Chaos Engineering](#chaos-engineering)
- [CI/CD Pipeline Flow](#cicd-pipeline-flow)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Running Chaos Experiments Locally](#running-chaos-experiments-locally)
- [Key Patterns](#key-patterns)
- [Security Posture Summary](#security-posture-summary)
- [Integration with Other Repos](#integration-with-other-repos)
- [Interview Talking Points](#interview-talking-points)

---

## 🏗️ Architecture

```
                     ┌─────────────────────────────────────────────────────┐
                     │              GitHub Actions (CI/CD)                 │
                     │                                                     │
  Push/PR → ┌────────▼────────┐    ┌───────────┐    ┌──────────────────┐   │
            │ CI: Security    │    │ CD Dev     │    │ CD Staging        │   │
            │ Gate (Parallel) │    │ (Auto)     │    │ (Manual Approval) │   │
            │                 │    │           │    │                  │   │
            │ • Trivy         │───►│ Deploy to  │───►│ Validate +      │   │
            │ • tfsec         │    │ Dev NS     │    │ Chaos Smoke Test│   │
            │ • Checkov       │    │           │    │ (pod failure)    │   │
            │ • CodeQL        │    └───────────┘    │                  │   │
            │ • Grype         │                     └────────┬─────────┘   │
            │ • Gitleaks      │                              │             │
            │ • OSV-Scanner   │                   workflow_dispatch           │
            └─────────────────┘                              │             │
                    ▲                                         ▼             │
                    │                         ┌──────────────────────┐        │
  ┌───────────────┐ │                         │ CD Production         │        │
  │ Sample App    │ ├────────────────────────►│ (2-of-3 Approval +   │        │
  │ (src/)        │ │                         │ Chaos Validation)    │        │
  │ - Express.js  │ │                         └──────────┬───────────┘        │
  │ - Multi-stage │ │                                    │                   │
  │   Dockerfile  │ │                              ┌─────▼──────┐            │
  └───────────────┘ │                              │ Drift Detect│            │
                    │                              │ + Auto-Heal │            │
                    ▼                              │ (4hr cycle) │            │
             ┌──────────────────┐                  └──────┬───────┘            │
             │ Docker Image     │                         │                   │
             │ ECR Registry     │◄────────────────────────┘                   │
             └────────┬───────┘                                               │
                      │                                                      │
                      ▼                                                      │
             ┌─────────────────────────────────────────────────────────┐      │
             │              Amazon EKS Cluster                          │      │
             │                                                          │      │
             │  secops-dev     secops-staging     secops-prod           │      │
             │  ├── sample-app  ├── sample-app   ├── sample-app         │      │
             │  └── chaos-litmus└── chaos-litmus └── chaos-litmus       │      │
             │                                                          │      │
             │        LitmusChaos experiments validate self-heal          │      │
             └──────────────────────────────────────────────────────────┘      │
                     ▲                                                      │
                     └──── ArgoCD GitOps (selfHeal, auto-sync) ──────────────┘
```

### Delivery Philosophy

**Shift-Left Security:** Every code change triggers parallel security scans before deployment. Vulnerabilities are caught at the PR level — not in production.

**Chaos-First Validation:** Staging deployments don't just "verify uptime" — they actively inject failures (pod kills, network latency, memory pressure) and confirm the system heals itself within SLO windows.

---

## 🛡️ Security Gates

The CI pipeline runs **7 parallel security scans**, each targeting a different threat surface:

| Gate | Tool | What It Scans | Severity Threshold |
|------|------|---------------|-------------------|
| **Container Vulnerability** | Trivy | OS + dependency CVEs in Docker image | CRITICAL / HIGH |
| **IaC Misconfiguration** | tfsec | AWS resource compliance (IAM, S3, EKS) | All findings |
| **IaC Policy Violations** | Checkov | Anti-patterns in Terraform HCL | All findings |
| **Static Application (SAST)** | CodeQL | JavaScript source code vulnerabilities | security-and-quality queries |
| **Dependency Vulnerabilities** | Grype + OSV-Scanner | npm package CVEs at runtime | CRITICAL / HIGH |
| **Secret Leakage** | TruffleHog + Gitleaks | API keys, tokens, passwords in git history | Verified secrets only |
| **Manifest Validity** | Kustomize build | YAML syntax and overlay consistency | Build success |

All scan results are uploaded to GitHub Security tab (SARIF format) for centralized vulnerability tracking.

### Portfolio Mode

When `AWS_ROLE_ARN` is not configured, the pipeline operates in **portfolio mode**: it validates security gates locally without requiring AWS credentials or EKS clusters. This means reviewers can see the pipeline pass/fail patterns by simply pushing to any branch — no infrastructure needed.

---

## 🧪 Chaos Engineering

Chaos engineering isn't an afterthought — it's a deployment gate. Before promoting to staging and production, the system runs **LitmusChaos experiments** that simulate real failure scenarios:

### Experiment Catalog

| Experiment | Method | Target | Expected Behavior |
|-----------|--------|--------|-------------------|
| **Pod Failure** | LitmusChaos `pod-delete` | Sample app pods | Remaining replicas serve traffic; new pod spins up within replica count SLO |
| **Network Latency** | LitmusChaos `network-latency` | Pod → Service | App maintains health checks despite 500ms+ latency injection |
| **OOM Kill** | Kernel-level OOM (LitmusChaos) | Memory-limited pod | Container restarts; limits enforced; no node instability |

### Self-Healing Verification

After each experiment, the pipeline validates:

1. **Replica Recovery:** `readyReplicas` returns to desired count within 5 minutes
2. **Health Check Pass:** `/healthz` endpoint responds successfully post-recovery
3. **No Cascade Failures:** No other pods or nodes affected
4. **Resource Limits Hold:** OOM killed container respects `memoryLimit` (no node impact)

### Drift Detection

A scheduled workflow (`drift-detection.yml`) runs every 4 hours in production:

1. Compares live cluster state vs. Git manifests
2. Identifies any configuration drift or unauthorized modifications
3. Logs discrepancies for on-call review
4. ArgoCD auto-heal corrects benign drift; critical drift triggers alerts

---

## 🔄 CI/CD Pipeline Flow

```
Branch Push / PR
       │
       ▼
  ┌─────────┐
  │   CI    │ ← 7 parallel security gates (block on CRITICAL/HIGH)
  │ Pipeline│
  └────┬────┘
       │ All pass
       ▼
  ┌──────────┐     workflow_dispatch?
  │ CD Dev   │ ←─ Auto-deploy to dev namespace
  │ (Auto)   │     confirm_staging='APPROVE-STAGING'
  └────┬─────┘     2-of-3 human approval + chaos validation
       │          ▼
       │    ┌──────────┐
       │    │ CD Stage │ ← Chaos smoke test: pod failure experiment
       │    └────┬─────┘     OOM kill experiment
       │         │           Network latency experiment
       │         ▼
       │    ┌──────────┐
       │    │ CD Prod  │ ← Full chaos validation suite
       │    └────┬─────┘     Self-heal verification
       │         │           No-rollback guarantee verified
       │         ▼
  ┌───────────────────────────────────────┐
  │ ArgoCD GitOps (4hr drift detection)   │
  │ • Auto-sync manifests from Git        │
  │ • Compare live state vs. desired      │
  │ • Report drift, alert on anomalies    │
  └───────────────────────────────────────┘
```

---

## 📁 Project Structure

```
devsecops-chaos-lab/
├── .github/workflows/
│   ├── ci.yml                    # Parallel security scans (7 gates)
│   ├── cd-dev.yml                # Auto-deploy to dev namespace
│   ├── cd-staging.yml            # Manual approval + chaos smoke test
│   ├── cd-prod.yml               # 2-of-3 approval + full chaos validation
│   └── drift-detection.yml       # Scheduled drift detection (4hr)
├── src/                          # Sample Express.js application
│   ├── app.js                    # Health check endpoints, graceful shutdown
│   ├── package.json              # Minimal dependencies (express only)
│   └── Dockerfile                # Multi-stage: build → distroless
├── k8s-manifests/
│   ├── base/                     # Deployment + Service (env-agnostic)
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── overlays/
│       ├── dev/kustomization.yaml    # 1 replica, low resources
│       ├── staging/kustomization.yaml # 2 replicas, chaos enabled
│       └── prod/kustomization.yaml   # 3 replicas, HPA-ready, strict limits
├── environments/                 # Terraform per-environment
│   ├── dev/main.tf + variables.tf    # Dev namespace + EKS config
│   ├── staging/main.tf + variables.tf
│   └── prod/main.tf + variables.tf
├── providers/                    # Shared AWS modules
│   ├── main.tf                       # EKS cluster, IRSA roles, S3 backends
│   ├── variables.tf
│   └── versions.tf
├── chaos-engineering/exp-sabotage/
│   ├── scenarios.md                 # Experiment catalog & runbook
│   ├── pod-failure.yaml             # LitmusChaos pod-delete experiment
│   ├── network-latency.yaml         # LitmusChaos network-delay experiment
│   └── oom-killing.yaml             # LitmusChaos OOM kill experiment
├── scripts/
│   ├── setup.sh                   # One-click local environment
│   └── destroy.sh                 # Full cleanup
├── Makefile                       # Unified build/deploy commands
├── LICENSE                        # MIT
└── README.md                      # This file
```

---

## 📋 Prerequisites

- **Git** + [gh CLI](https://cli.github.com/) (for portfolio mode)
- **Docker** (v20+ for multi-stage builds)
- **kubectl** (v1.28+) — for local cluster operations
- **terraform** (v1.10+) — for infrastructure management
- **aws-cli** (v2+) — for AWS operations (optional, portfolio mode skips this)
- **Node.js** (v20 LTS) — for running the sample app locally

---

## 🚀 Quick Start

### Portfolio Mode (No AWS Required)

The entire pipeline validates security gates without any infrastructure:

```bash
# 1. Clone and enter the repo
git clone https://github.com/twire/devsecops-chaos-lab.git
cd devsecops-chaos-lab

# 2. Build and test the sample app locally
npm ci --prefix src
node src/app.js &
curl http://localhost:3000/healthz   # → {"status":"ok"}

# 3. Build the Docker image (for Trivy scan)
docker build -t sample-app:test ./src/

# 4. Run Trivy container scan locally
trivy image --severity CRITICAL,HIGH --format sarif sample-app:test > trivy-results.sarif

# 5. Scan infrastructure configs
python3 -m pip install --quiet checkov tfsec
checkov -d environments/ --quiet
tfsec environments/dev/ --exit-code 1

# 6. Scan for secrets in git history
trufflehog filesystem . --only-verified
gitleaks detect --source . --report-format sarif

# 7. Build and validate Kustomize overlays
curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.4.0/kustomize_v5.4.0_linux_amd64.tar.gz" | tar xz -C /usr/local/bin/
kustomize build k8s-manifests/overlays/dev
```

### Production Mode (With AWS)

1. Configure `AWS_ROLE_ARN` secret in repository settings
2. Terraform plans provision dev/staging/prod namespaces on EKS
3. Push to `main` → CI runs → CD deploys to dev automatically
4. Trigger staging via workflow_dispatch with approval confirmation
5. Approve production via 2-of-3 human reviewers + chaos validation

---

## 🧪 Running Chaos Experiments Locally

### Install LitmusChaos (on a running cluster)

```bash
# Apply LitmusChaos operator and CRDs
kubectl create namespace litmus
kubectl apply -f https://github.com/litmuschaos/litmuschaos/releases/latest/download/litmus.yaml

# Verify installation
kubectl get pods -n litmus
```

### Run an Experiment Manually

```bash
# 1. Apply pod-failure experiment CR
kubectl apply -f chaos-engineering/exp-sabotage/pod-failure.yaml

# 2. Watch the chaos run (by default: 30s duration)
kubectl get chaosresults -n secops-dev -w

# 3. Verify self-healing
watch kubectl get pods -n secops-dev -l app=sample-app

# 4. Check deployment recovery
kubectl get deployment sample-app -n secops-dev -o jsonpath='{.status.readyReplicas}'
```

### Full Experiment Suite

```bash
for exp in pod-failure network-latency oom-killing; do
  echo "=== Running: $exp ==="
  kubectl apply -f chaos-engineering/exp-sabotage/${exp}.yaml
  sleep 90  # Allow experiment to complete
  kubectl delete -f chaos-engineering/exp-sabotage/${exp}.yaml
  echo "=== Cleaning up: $exp ==="
done
```

---

## 🔑 Key Patterns

### 1. Parallel Security Gates (CI)

All 7 scans run as independent jobs with `parallel: true` semantics (each is its own top-level job). If any gate fails, the entire CI stage fails — but results are still visible because each job reports independently to GitHub's security tab.

```yaml
jobs:
  container-scan:    # Job 1 - Trivy
    ...
  iac-scan:         # Job 2 - tfsec + Checkov (matrix over envs)
    ...
  sast-scan:        # Job 3 - CodeQL SAST
    ...
  dependency-scan:   # Job 4 - Grype + OSV-Scanner
    ...
  secret-scan:      # Job 5 - TruffleHog + Gitleaks
    ...
  kustomize-validate: # Job 6 - Kustomize build validation
    ...
  full-pipeline:     # Aggregator gate
    needs: [container-scan, iac-scan, sast-scan, dependency-scan, secret-scan, kustomize-validate]
```

### 2. Check-Creds Gating Pattern (CD)

Every CD workflow uses an early `check-creds` step that determines if AWS credentials are available. If not, the workflow gracefully degrades — reporting portfolio mode status without failing. This means:
- The repo works out-of-the-box for any reviewer
- Real deployments activate automatically when credentials are present
- No configuration drift between "demo" and "production" modes

### 3. Chaos as Deployment Gate (Staging)

Unlike traditional CI/CD where chaos is optional, this pipeline treats chaos validation as a **required deployment gate** in staging. The `cd-staging.yml` workflow includes an explicit step that runs a pod-failure experiment and verifies self-healing before confirming the promotion.

### 4. Drift Detection with Auto-Heal

The drift-detection workflow provides observability into cluster state vs. Git source of truth. ArgoCD handles benign drift correction; critical drift (e.g., unauthorized namespace changes) triggers alerts without auto-correction.

---

## 📊 Security Posture Summary

| Category | Tool | Coverage | Frequency |
|----------|------|----------|-----------|
| Container CVEs | Trivy | OS + application deps | Every push/PR |
| IaC Compliance | tfsec | AWS resource rules (100+ checks) | Every push |
| IaC Anti-patterns | Checkov | Terraform HCL best practices | Every push |
| SAST | CodeQL | JavaScript security queries | Every push |
| Dependency CVEs | Grype + OSV-Scanner | npm ecosystem | Every push |
| Secret Leakage | TruffleHog + Gitleaks | Full git history | Every push |
| Manifest Validity | Kustomize | Overlay consistency | Every push |

---

## 🔗 Integration with Other Repos

This project forms part of a cohesive portfolio:

| Repo | Role | Relationship |
|------|------|--------------|
| [enterprise-terraform-aws](https://github.com/twire/enterprise-terraform-aws) | Infrastructure provisioning | Provides EKS cluster, S3 backends, IAM roles |
| [eks-observability](https://github.com/twire/eks-observability) | Observability stack | Prometheus/Grafana/Loki monitor the devsecops workloads |
| [developer-portal](https://github.com/twire/developer-portal) | Platform engineering | Sample app could be scaffolded from Backstage templates here |
| **devsecops-chaos-lab** (you are here) | Security + Chaos | Validates security gates and resilience of all above |

---

## 🎤 Interview Talking Points

### "How do you approach security in CI/CD?"

> I believe security should be parallel, not sequential. In this project, 7 independent security scans run simultaneously on every push — container vulnerabilities (Trivy), IaC compliance (tfsec + Checkov), SAST (CodeQL), dependency CVEs (Grype + OSV-Scanner), and secret leakage (TruffleHog + Gitleaks). No single scan blocks the pipeline alone; they all must pass. This prevents false-positive-driven deployment delays while maintaining comprehensive coverage.

### "Why chaos engineering?"

> Most teams treat reliability as a feature — something you build. I treat it as a property — something you prove under stress. Before promoting to staging in this lab, I run LitmusChaos pod-failure experiments and verify the system self-heals within SLO windows. The goal isn't to break things — it's to prove that breaking them doesn't matter because the system recovers automatically.

### "What makes shift-left security different from traditional security?"

> Traditional security is a checkpoint at the end of the pipeline: "Is this deployable?" Shift-left asks earlier questions: "Was this infrastructure misconfigured?" "Does this container have known CVEs?" "Are there secrets committed to git history?" By pushing left, we catch issues when they're cheapest to fix — in the PR, not in production at 3 AM.

### "How do you handle portfolio mode vs production mode?"

> A common problem with demo repos is that they require specific infrastructure to pass CI. This project uses a `check-creds` gating pattern: every AWS-dependent step checks for credentials first and gracefully degrades if absent. The security scans (Trivy, tfsec, Checkov, CodeQL) run identically in both modes because they don't need AWS. Only deployment steps are conditional. This means any recruiter can see the pipeline pass by simply cloning and pushing — no AWS account required.

---

---

_Built with ❤️ by Thomas Wire — Platform Engineering Portfolio_

| Repo | Focus |
|------|-------|
| **[enterprise-terraform-aws](https://github.com/twire/enterprise-terraform-aws)** | Infrastructure as Code |
| **[eks-observability](https://github.com/twire/eks-observability)** | Platform Observability |
| **[multi-gitops-pipeline](https://github.com/twire/multi-gitops-pipeline)** | GitOps Workflows |
| **[developer-portal](https://github.com/twire/developer-portal)** | Developer Experience |
| **devsecops-chaos-lab** ⬅️ You are here | Security & Chaos Engineering |
# Test

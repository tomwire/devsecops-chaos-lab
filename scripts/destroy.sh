#!/usr/bin/env bash
# =============================================================================
# DevSecOps Chaos Lab — Cleanup Script
# ============================================================
# Removes all resources created by setup or manual deployment.
# WARNING: This deletes resources in the current kubectl context!
# ============================================================

set -euo pipefail

echo "============================================"
echo " DevSecOps Chaos Lab — Destroy"
echo "============================================"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Confirm before destructive action
read -p "This will delete chaos experiments and deployments from your current cluster. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ---------------------------------------------------------------------------
# Delete LitmusChaos experiments if installed
# ---------------------------------------------------------------------------
echo ""
echo "--- Cleaning up chaos experiments ---"
for ns in secops-dev secops-staging secops-prod; do
  if kubectl get namespace "$ns" &>/dev/null; then
    echo "Deleting resources in $ns..."
    kubectl delete -f chaos-engineering/exp-sabotage/pod-failure.yaml -n "$ns" --ignore-not-found 2>/dev/null || true
    kubectl delete -f chaos-engineering/exp-sabotage/network-latency.yaml -n "$ns" --ignore-not-found 2>/dev/null || true
    kubectl delete -f chaos-engineering/exp-sabotage/oom-killing.yaml -n "$ns" --ignore-not-found 2>/dev/null || true

    # Delete deployed resources if present
    kubectl delete deployment sample-app -n "$ns" --ignore-not-found 2>/dev/null || true
    kubectl delete service sample-app -n "$ns" --ignore-not-found 2>/dev/null || true
    ok "Cleaned $ns"
  else
    warn "$ns not found — skipping"
  fi
done

# ---------------------------------------------------------------------------
# Delete generated artifacts
# ---------------------------------------------------------------------------
echo ""
echo "--- Cleaning artifacts ---"
rm -f trivy-results.sarif grype-results.sarif *.sarif
ok "Removed SARIF reports"

# ---------------------------------------------------------------------------
# Terraform destroy (if initialized)
# ---------------------------------------------------------------------------
if [ -d "environments/dev/.terraform" ]; then
  echo ""
  echo "--- Destroying Terraform state ---"
  warn "Terraform state found in environments/dev/"
  cd environments/dev && terraform destroy -auto-approve 2>/dev/null || warn "Destroy failed or already clean"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
ok "Cleanup complete. Cluster resources removed."

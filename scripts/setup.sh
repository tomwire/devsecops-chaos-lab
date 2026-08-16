#!/usr/bin/env bash
# =============================================================================
# DevSecOps Chaos Lab — One-Click Local Setup
# ============================================================
# Installs all tooling needed for portfolio-mode validation:
#   - Trivy (container scanning)
#   - Checkov + tfsec (IaC scanning)
#   - Gitleaks (secret scanning)
#   - Kustomize (manifest building)
#   - Dependencies for sample app
# ============================================================

set -euo pipefail

echo "============================================"
echo " DevSecOps Chaos Lab — Local Setup"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}" && exit 1; }

# ---------------------------------------------------------------------------
# Detect OS for package manager
# ---------------------------------------------------------------------------
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PKG_MANAGER="apt"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &>/dev/null; then
    fail "Homebrew required on macOS. Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
  PKG_MANAGER="brew"
else
  warn "Unknown OS — using whatever's already installed"
  PKG_MANAGER="none"
fi

# ---------------------------------------------------------------------------
# Install Go (required for tfsec and gitleaks)
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking Go ---"
if command -v go &>/dev/null; then
  GO_VERSION=$(go version | grep -oP '\d+\.\d+')
  ok "Go $GO_VERSION already installed"
else
  warn "Go not found — installing via package manager..."
  if [ "$PKG_MANAGER" = "brew" ]; then
    brew install go
  elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get update && sudo apt-get install -y golang-go
  fi
fi
ok "Go available: $(go version | head -1)"

# ---------------------------------------------------------------------------
# Install Trivy (container scanning)
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing Trivy ---"
if command -v trivy &>/dev/null; then
  ok "Trivy already installed: $(trivy --version 2>/dev/null | head -1)"
else
  warn "Trivy not found — installing..."
  if [ "$PKG_MANAGER" = "brew" ]; then
    brew install aquasecurity/trivy/trivy
  else
    # GitHub releases fallback
    bash <(curl -sS https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh) -b /usr/local/bin
  fi
fi

# ---------------------------------------------------------------------------
# Install Checkov (IaC scanning — pip)
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing Checkov ---"
if command -v checkov &>/dev/null; then
  ok "Checkov already installed: $(checkov --version)"
else
  warn "Checkov not found — installing via pip..."
  pip3 install --quiet checkov
fi

# ---------------------------------------------------------------------------
# Install tfsec (IaC scanning)
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing tfsec ---"
if command -v tfsec &>/dev/null; then
  ok "tfsec already installed: $(tfsec --version)"
else
  warn "tfsec not found — installing via Go..."
  go install github.com/aquasecurity/tfsec/cmd/tfsec@latest 2>/dev/null || \
    warn "tfsec Go install failed — skip or install manually"
fi

# ---------------------------------------------------------------------------
# Install Gitleaks (secret scanning)
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing Gitleaks ---"
if command -v gitleaks &>/dev/null; then
  ok "Gitleaks already installed: $(gitleaks version)"
else
  warn "Gitleaks not found — installing..."
  if [ "$PKG_MANAGER" = "brew" ]; then
    brew install gitleaks
  else
    go install github.com/gitleaks/gitleaks/v2/cmd/gitleaks@latest 2>/dev/null || \
      warn "gitleaks Go install failed — skip or install manually"
  fi
fi

# ---------------------------------------------------------------------------
# Install Kustomize (K8s manifest building)
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing Kustomize ---"
if command -v kustomize &>/dev/null; then
  ok "Kustomize already installed: $(kustomize version --short)"
else
  warn "Kustomize not found — installing v5.4.0..."
  curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.4.0/kustomize_v5.4.0_linux_amd64.tar.gz" | \
    tar xz -C /usr/local/bin/ 2>/dev/null || warn "Kustomize install failed — skip or install manually"
fi

# ---------------------------------------------------------------------------
# Install Docker (for image building)
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking Docker ---"
if command -v docker &>/dev/null; then
  ok "Docker available: $(docker --version | head -1)"
else
  warn "Docker not found — required for Trivy container scanning"
  warn "Install from: https://docs.docker.com/get-docker/"
fi

# ---------------------------------------------------------------------------
# Install sample app dependencies
# ---------------------------------------------------------------------------
echo ""
echo "--- Installing sample app dependencies ---"
if [ -d "src/node_modules" ]; then
  ok "Sample app dependencies already installed"
else
  cd src && npm ci --ignore-scripts 2>/dev/null || npm install --production 2>/dev/null || warn "npm install failed"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
ok "Setup complete!"
echo ""
echo "Next steps:"
echo "  make build    — Build the sample app Docker image"
echo "  make scan     — Run all local security scans"
echo "  make drift-check — Validate Kustomize overlays"
echo "  make          — Show all available targets"
echo "============================================"

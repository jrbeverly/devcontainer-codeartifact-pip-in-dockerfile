#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPERIMENT="$(dirname "$SCRIPT_DIR")"
ARTIFACTS="$EXPERIMENT/artifacts"
mkdir -p "$ARTIFACTS"
EVIDENCE="$ARTIFACTS/evidence.txt"
: > "$EVIDENCE"

log() { echo "$*" | tee -a "$EVIDENCE"; }

log "run started: $(date -u)"

# Prerequisites
[ -f /.dockerenv ] || { log "FAIL: not running inside the outer container"; exit 1; }
for cmd in docker terraform aws; do
  command -v "$cmd" >/dev/null || { log "FAIL: $cmd not found"; exit 1; }
done
docker buildx version >/dev/null 2>&1 || { log "FAIL: docker buildx not available"; exit 1; }
CALLER=$(aws sts get-caller-identity --output text --query Arn)
log "identity: $CALLER"

# Terraform
terraform -chdir="$EXPERIMENT/infra" init -input=false >/dev/null 2>&1
terraform -chdir="$EXPERIMENT/infra" apply -auto-approve -no-color 2>&1 | tee -a "$EVIDENCE"

DOMAIN=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain)
DOMAIN_OWNER=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain_owner)
REPOSITORY=$(terraform -chdir="$EXPERIMENT/infra" output -raw repository)
REGION=$(terraform -chdir="$EXPERIMENT/infra" output -raw region)
ENDPOINT=$(terraform -chdir="$EXPERIMENT/infra" output -raw pip_endpoint)
log "domain: $DOMAIN  repository: $REPOSITORY  region: $REGION"

# Publish package
"$SCRIPT_DIR/publish.sh" 2>&1 | tee -a "$EVIDENCE"

PKG_VER=$(aws codeartifact list-package-versions \
  --domain "$DOMAIN" --domain-owner "$DOMAIN_OWNER" \
  --repository "$REPOSITORY" --format pypi \
  --package codeartifact-probe --region "$REGION" \
  --query 'versions[0].version' --output text)
log "package confirmed: codeartifact-probe==$PKG_VER"

# Mint token and build inner image
TOKEN=$(aws codeartifact get-authorization-token \
  --domain "$DOMAIN" --domain-owner "$DOMAIN_OWNER" \
  --region "$REGION" --query authorizationToken --output text)

TOKEN_FILE=$(mktemp)
printf '%s' "$TOKEN" > "$TOKEN_FILE"
unset TOKEN

docker buildx build \
  --secret "id=codeartifact_token,src=$TOKEN_FILE" \
  --build-arg "CODEARTIFACT_ENDPOINT=$ENDPOINT" \
  --tag codeartifact-pip-inner:latest \
  "$EXPERIMENT/inner-devcontainer" 2>&1 | tee -a "$EVIDENCE"
IMAGE_ID=$(docker inspect --format '{{.Id}}' codeartifact-pip-inner:latest)
log "image: $IMAGE_ID"

# Validate while token is in memory
"$SCRIPT_DIR/validate.sh" "$TOKEN_FILE" "$EXPERIMENT" 2>&1 | tee -a "$EVIDENCE"

# Cleanup
rm -f "$TOKEN_FILE"
log "token file removed"

for f in "$HOME/.config/pip/pip.conf" "$HOME/.pip/pip.conf" /etc/pip.conf "$HOME/.pypirc"; do
  [ ! -f "$f" ] || log "WARN: residual $f"
done
log "host pip config check: PASS"

log "run complete: $(date -u)"

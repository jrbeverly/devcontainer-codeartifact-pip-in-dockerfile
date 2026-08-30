#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPERIMENT="$(dirname "$SCRIPT_DIR")"

python3 -c 'import build' 2>/dev/null || pip install --quiet build
python3 -c 'import twine' 2>/dev/null || pip install --quiet twine

python3 -m build --wheel "$EXPERIMENT/package" --outdir "$EXPERIMENT/package/dist"

DOMAIN=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain)
DOMAIN_OWNER=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain_owner)
REPOSITORY=$(terraform -chdir="$EXPERIMENT/infra" output -raw repository)
REGION=$(terraform -chdir="$EXPERIMENT/infra" output -raw region)
ENDPOINT=$(terraform -chdir="$EXPERIMENT/infra" output -raw pip_endpoint)

TOKEN=$(aws codeartifact get-authorization-token \
  --domain "$DOMAIN" \
  --domain-owner "$DOMAIN_OWNER" \
  --region "$REGION" \
  --query authorizationToken \
  --output text)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK" "$EXPERIMENT/package/dist"' EXIT

cat > "$WORK/.pypirc" <<EOF
[distutils]
index-servers = ca
[ca]
repository = $ENDPOINT
username = aws
password = $TOKEN
EOF
unset TOKEN

python3 -m twine upload \
  --config-file "$WORK/.pypirc" \
  --repository ca \
  --non-interactive \
  "$EXPERIMENT/package/dist/"*.whl

echo "published: aws codeartifact list-package-versions --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --format pypi --package codeartifact-probe --region $REGION"

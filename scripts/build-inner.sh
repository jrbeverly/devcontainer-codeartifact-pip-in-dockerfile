#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPERIMENT="$(dirname "$SCRIPT_DIR")"

DOMAIN=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain)
DOMAIN_OWNER=$(terraform -chdir="$EXPERIMENT/infra" output -raw domain_owner)
REGION=$(terraform -chdir="$EXPERIMENT/infra" output -raw region)
ENDPOINT=$(terraform -chdir="$EXPERIMENT/infra" output -raw pip_endpoint)

TOKEN=$(aws codeartifact get-authorization-token \
  --domain "$DOMAIN" \
  --domain-owner "$DOMAIN_OWNER" \
  --region "$REGION" \
  --query authorizationToken \
  --output text)

TOKEN_FILE=$(mktemp)
trap 'rm -f "$TOKEN_FILE"' EXIT

printf '%s' "$TOKEN" > "$TOKEN_FILE"
unset TOKEN

docker buildx build \
  --secret "id=codeartifact_token,src=$TOKEN_FILE" \
  --build-arg "CODEARTIFACT_ENDPOINT=$ENDPOINT" \
  --tag codeartifact-pip-inner:latest \
  "$EXPERIMENT/inner-devcontainer"

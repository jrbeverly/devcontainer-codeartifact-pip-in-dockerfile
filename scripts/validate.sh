#!/usr/bin/env bash
set -euo pipefail

TOKEN=$(cat "$1")
EXPERIMENT="$2"
IMAGE=codeartifact-pip-inner:latest
GIT_ROOT=$(git -C "$EXPERIMENT" rev-parse --show-toplevel)
EXPERIMENT_REL="${EXPERIMENT#$GIT_ROOT/}"

# Functional check: import package offline, no AWS env or network
RESULT=$(docker run --network none --rm "$IMAGE" \
  python -c "from codeartifact_probe import probe; print(probe())")
[ "$RESULT" = "codeartifact-probe@1.0.0" ] || { echo "functional: FAIL ($RESULT)"; exit 1; }
echo "functional: PASS ($RESULT)"

# Token scan: tracked source files
MATCH=$(cd "$GIT_ROOT" && git ls-files -- "$EXPERIMENT_REL" | xargs -r grep -lF "$TOKEN" 2>/dev/null || true)
[ -z "$MATCH" ] || { echo "source scan: FAIL (token found in: $MATCH)"; exit 1; }
echo "source scan: PASS"

# Token scan: docker history
HISTORY_HIT=0
docker history --no-trunc "$IMAGE" | grep -qF "$TOKEN" && HISTORY_HIT=1 || true
[ "$HISTORY_HIT" -eq 0 ] || { echo "history scan: FAIL (token found in docker history)"; exit 1; }
echo "history scan: PASS"

# Token scan + pip residue: exported image filesystem
CID=""
EXPORT_DIR=$(mktemp -d)
trap 'rm -rf "$EXPORT_DIR"; [ -n "$CID" ] && docker rm "$CID" 2>/dev/null || true' EXIT

CID=$(docker create "$IMAGE")
docker export "$CID" | tar -x -C "$EXPORT_DIR" --exclude='./dev' 2>/dev/null
docker rm "$CID"; CID=""

FS_HIT=0
grep -rqF "$TOKEN" "$EXPORT_DIR" 2>/dev/null && FS_HIT=1 || true
[ "$FS_HIT" -eq 0 ] || { echo "filesystem token scan: FAIL"; exit 1; }
echo "filesystem token scan: PASS"

PIP_CREDS=$(find "$EXPORT_DIR" \( -name "pip.conf" -o -name ".pypirc" \) 2>/dev/null || true)
[ -z "$PIP_CREDS" ] || { echo "pip credential files: FAIL ($PIP_CREDS)"; exit 1; }
echo "pip credential files: PASS"

URL_HIT=0
grep -rq 'aws:.*@' "$EXPORT_DIR" 2>/dev/null && URL_HIT=1 || true
[ "$URL_HIT" -eq 0 ] || { echo "authenticated index URL: FAIL"; exit 1; }
echo "authenticated index URL: PASS"

echo "validate: all checks PASS"

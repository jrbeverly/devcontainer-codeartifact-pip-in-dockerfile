# syntax=docker/dockerfile:1
FROM python:3.12-slim

ARG CODEARTIFACT_ENDPOINT

RUN --mount=type=secret,id=codeartifact_token \
    printf '[global]\nindex-url = https://aws:%s@%ssimple/\n' \
      "$(cat /run/secrets/codeartifact_token)" \
      "${CODEARTIFACT_ENDPOINT#https://}" \
    > /tmp/pip.conf \
    && PIP_CONFIG_FILE=/tmp/pip.conf pip install --no-cache-dir codeartifact-probe==1.0.0 \
    && rm /tmp/pip.conf

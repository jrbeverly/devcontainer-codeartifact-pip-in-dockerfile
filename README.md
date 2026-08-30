# CodeArtifact pip Install in a Dev Container Build

> [!WARNING]
> **AI-authored:** This change was autonomously planned and implemented by an AI software factory from a human-authored specification, with possible subsequent human review or modification.

Installs a private Python package from AWS CodeArtifact during an inner image build without retaining the short-lived token.

```sh
bash scripts/run.sh
terraform -chdir=infra destroy -auto-approve
```

## Notes

- kind of neat exploration; probably not worth pursuing
- original idea; simple dev container + script producing a code pipeline artifact
- mostly experimentation/fiddling with the flow
- do not currently see this becoming a real direction
- leaning toward different approaches for package management/distribution instead

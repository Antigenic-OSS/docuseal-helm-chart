# antigenic-docuseal-helm-chart

[![Tag](https://img.shields.io/github/v/tag/Antigenic-OSS/docuseal-helm-chart?sort=semver)](https://github.com/Antigenic-OSS/docuseal-helm-chart/tags)
[![Chart CI](https://img.shields.io/github/actions/workflow/status/Antigenic-OSS/docuseal-helm-chart/chart-ci.yaml?label=chart%20ci)](https://github.com/Antigenic-OSS/docuseal-helm-chart/actions/workflows/chart-ci.yaml)
[![Publish OCI](https://img.shields.io/github/actions/workflow/status/Antigenic-OSS/docuseal-helm-chart/release-chart.yaml?label=publish%20oci)](https://github.com/Antigenic-OSS/docuseal-helm-chart/actions/workflows/release-chart.yaml)
[![GHCR](https://img.shields.io/badge/oci-ghcr.io%2Fantigenic--oss%2Fcharts-blue)](https://github.com/orgs/Antigenic-OSS/packages?repo_name=docuseal-helm-chart)
[![License](https://img.shields.io/github/license/Antigenic-OSS/docuseal-helm-chart)](https://github.com/Antigenic-OSS/docuseal-helm-chart/blob/main/LICENSE)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/antigenic-docuseal-helm-chart)](https://artifacthub.io/packages/search?repo=antigenic-docuseal-helm-chart)

Production-focused Helm chart for deploying [DocuSeal](https://www.docuseal.com/) on Kubernetes.

Maintained by [Antigenic](https://antigenic.org).

> Disclaimer: This is an unofficial, community-maintained chart. Antigenic is not affiliated with, endorsed by, or sponsored by DocuSeal.

## What This Chart Optimizes

- External PostgreSQL only (`DATABASE_URL`; no SQLite deployment mode).
- Secure secret handling (value or existing Secret references).
- Enterprise ingress options (Service, Ingress, or Gateway API HTTPRoute).
- Explicit HA and storage guidance for multi-replica deployments.
- Hardened default container security context.
- Renovate-driven image updates with automatic chart version bumping.

## Storage Strategy (Important)

DocuSeal needs shared document storage. PostgreSQL alone does not store all document files.

| Strategy | persistence.enabled | Object storage (S3/GCS/Azure) | HA readiness |
|---|---:|---:|---|
| Local PV | true | false | Single replica by default; multi-replica requires RWX |
| Stateless + S3 | false | true | Recommended for HA |
| Stateless + GCS | false | true | Recommended for HA |
| Stateless + Azure Blob | false | true | Recommended for HA |

If `s3.enabled=true` (or `gcs.enabled=true`, `azure.enabled=true`), running without PVC is valid and usually preferred for scalable HA.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.14+
- Reachable PostgreSQL instance
- A Kubernetes Secret containing at least:
  - `DATABASE_URL`
  - `SECRET_KEY_BASE`

Generate `SECRET_KEY_BASE` with:

```bash
openssl rand -hex 64
```

## Quick Start

Create required secret:

```bash
kubectl -n docuseal create secret generic docuseal-secrets \
  --from-literal=DATABASE_URL='postgresql://docuseal:<password>@postgres-rw.database.svc.cluster.local:5432/docuseal?sslmode=require' \
  --from-literal=SECRET_KEY_BASE='<openssl-rand-hex-64>'
```

Install:

```bash
helm upgrade --install docuseal \
  oci://ghcr.io/antigenic-oss/charts/antigenic-docuseal-helm-chart \
  --version 0.1.0 \
  --namespace docuseal \
  --create-namespace
```

## HA Example: S3 Without PVC

```yaml
replicaCount: 3

persistence:
  enabled: false

s3:
  enabled: true
  region: us-east-1
  attachmentsBucket: docuseal-prod
  accessKeyId:
    existingSecret:
      enabled: true
      name: docuseal-s3
      key: AWS_ACCESS_KEY_ID
  secretAccessKey:
    existingSecret:
      enabled: true
      name: docuseal-s3
      key: AWS_SECRET_ACCESS_KEY
```

## Configuration Model

### Core app config

- `DATABASE_URL`: use one source only:
  - `database.url`
  - `database.existingSecret.*`
  - `secret.data.DATABASE_URL`
  - Security note: `database.url` is plaintext in rendered manifests and Helm release history. Prefer secret-backed modes for production.
- `SECRET_KEY_BASE`:
  - `env.SECRET_KEY_BASE` or `secret.data.SECRET_KEY_BASE`
  - Keep stable across restarts/upgrades, or sessions/tokens become invalid.
- General:
  - `general.forceSsl` -> `FORCE_SSL`
  - `general.host` -> `HOST`

### SMTP

Supported:

- `SMTP_USERNAME`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`
- `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_FROM`
- `SMTP_ENABLE_STARTTLS`, `SMTP_SSL_VERIFY`

Use `smtp.enabled=true` and provide required fields. Username/password support either direct values or existing secret refs.

### Object storage backends

Supported providers:

- S3: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_ATTACHMENTS_BUCKET`
- GCS: `GCS_CREDENTIALS`, `GCS_PROJECT`, `GCS_BUCKET`
- Azure: `AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_STORAGE_ACCESS_KEY`, `AZURE_CONTAINER`

Validation enforces only one provider enabled at a time.

### Networking exposure

- `service.type`: `ClusterIP` / `NodePort` / `LoadBalancer`
- `ingress.enabled=true` for Ingress API
- `httpRoute.enabled=true` for Gateway API

Ingress and HTTPRoute are mutually exclusive by validation.

## Security And Validation Guardrails

This chart intentionally fails render for unsafe or ambiguous setups, including:

- conflicting `DATABASE_URL` sources
- unsupported `env.DATABASE_URL` override
- insecure placeholder secrets (`change-me`)
- multiple storage backends enabled simultaneously
- `replicaCount > 1` with PVC + non-RWX storage
- `replicaCount > 1` with `persistence.enabled=false` and no shared object storage backend (`s3/gcs/azure`)
- missing required fields for enabled SMTP/storage providers

Operational note for external secret rotation:

- If you rely on external secret controllers, enable `secretReloader.enabled=true` to add Stakater Reloader annotations for watched secret names.

NetworkPolicy note:

- `networkPolicy.egress.allowDns` defaults to `false` for least-privilege posture.
- `networkPolicy.egress.allowDns=true` allows DNS egress on port 53.
- Set `networkPolicy.egress.dnsTo` to scope DNS egress to trusted DNS endpoints (for example CoreDNS selectors) instead of any destination.

## Recommended Production Patterns

- Use existing Kubernetes Secrets for all credentials.
- Use S3/GCS/Azure object storage with `persistence.enabled=false` for HA.
- Set `replicaCount >= 2` only when shared storage model is in place.
- Enable TLS at ingress/gateway layer and set `general.forceSsl=true`.
- Keep `SECRET_KEY_BASE` stable and rotate deliberately.

## Render And Lint

```bash
helm lint .
helm template docuseal . >/tmp/docuseal-rendered.yaml
```

## Upstream References

- DocuSeal environment variables: https://www.docuseal.com/self-hosting/environment-variables
- DocuSeal requirements: https://www.docuseal.com/self-hosting/requirements
- DocuSeal source: https://github.com/docusealco/docuseal

## License

MIT

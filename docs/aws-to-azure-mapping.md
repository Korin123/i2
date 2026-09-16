# Mapping to i2's ansible-i2a (AWS) reference

Same application, different platform layer. Source of the AWS side: i2 `ansible-i2a` (AWS CDK brownfield stacks + the `i2group.adt` Ansible collection) and `analyze-deployment-tooling` (https://github.com/i2group/analyze-deployment-tooling).

## Platform services

| i2 ansible-i2a (AWS) | This repo (Azure) | Notes |
|---|---|---|
| AWS CDK brownfield stacks | Bicep (`bicep/`) | VNet imported, never created (brownfield) |
| Ansible controller (EC2, SSM) | Pipeline stages calling `scripts/` | No controller VM; self-hosted agent on the VNet |
| ECS Fargate (Liberty, connectors) | AKS Deployments | Stateless tier |
| Dedicated EC2 (Solr, ZooKeeper) | AKS StatefulSets | Stable identity; see decisions.md |
| RDS PostgreSQL 17 | Azure SQL Managed Instance (SQL Server) | Engine change; DB_DIALECT=sqlserver |
| ECR | Azure Container Registry (private) | Images pushed by the local ADT build |
| Secrets Manager | Azure Key Vault | Secret + PKI set |
| SSM Parameter Store | Key Vault / App Configuration | Endpoints, ports |
| S3 artefact bucket | Azure Blob storage | Distribution + shared config |
| ALB / NLB (OIDC) | Application Gateway / internal LB + Entra | Internal only |
| CloudWatch / CloudMap | Azure Monitor / private DNS | Logs, metrics, service discovery |
| IAM roles / instance profiles | Managed identities + Azure RBAC | Workload identity for pods |

## Ansible roles to Azure implementation

| i2group.adt role | Azure equivalent here |
|---|---|
| `pki` | `scripts/20-seed-secrets-pki.sh` generates the CA + leaf certs into Key Vault |
| `provision_secrets` | same script seeds the password set into Key Vault (idempotent) |
| `pull_ecr_images` / `pull_remote_images` | `scripts/30-build-images.sh` (az acr import / docker push of the ADT-built `solr_redhat` to ACR) |
| `liberty_build` | `scripts/30-build-images.sh` runs ADT `deploy -c base-demo -t package` locally, pushes the configured image to ACR |
| `zookeeper_otb` / `solr_otb` | `k8s/zookeeper-statefulset.yaml` / `k8s/solr-statefulset.yaml` (containers, not OTB on VMs) |
| `postgres` | replaced by SQL Managed Instance (`bicep/modules/sql-mi.bicep`) |
| `db_init` | scripts generated at build time (`deploy -t generate-db-scripts`, baked into `images/db-init`), then Job `k8s/jobs/db-init-job.yaml` runs ADT's SQL Server sequence against the MI, resumable per step |
| `solr_collections` | schemas generated at build time (`scripts/30`), then Jobs `k8s/jobs/solr-zk-init-job.yaml` (chroot, urlScheme, security.json, configsets) and `solr-collections-job.yaml` (8 collections), run by `scripts/40` |
| `liberty_ecs` | `k8s/liberty-statefulset.yaml` (AKS StatefulSet with a /data volume per pod, like ADT's liberty1/liberty2 volumes, instead of an ECS service) |
| `start` / `stop` / `teardown` | `kubectl` scale + `az` (documented in operations) |
| `sanity_tests` | `scripts/60-sanity.sh` |

## Application contract (ADT 3.2.2, which the AWS reference consumes)

- Liberty `/opal` on 9443, HADR mode on, a persistent `/data` volume per server, `ZK_HOST` without the Solr chroot.
- Solr (ADT `solr_redhat` image) TLS on 8983, `SOLR_HOST` = pod FQDN, BasicAuth via `security.json` (admin `solr`, application `liberty`), 8 collections (main_index, match_index1, match_index2, highlight_index, chart_index, vq_index, recordshare_index, daod_index), numShards=4, replicationFactor=1.
- ZooKeeper secure client 2281, digest ACLs set by clients (users `solr` and `readonly-user`), quorum ports 2888/3888.
- Secret set: DB passwords (postgres/dba/dbb/etl/i2etl/i2analyze/i2public), liberty admin, Solr admin + application digest passwords, ZK digest + read-only digest passwords, `security.json`. PKI: CA + leaf cert/key for postgres/solr/solr-client/zookeeper/liberty/jwt/external_gateway_user.
- TLS end to end, offline-first (nodes pull only from the private ACR), no inbound SSH.

# i2 Analyze on Azure

Infrastructure-as-code, Kubernetes manifests and pipelines to deploy i2 Analyze on Microsoft Azure. This is the Azure counterpart to i2's `ansible-i2a` reference (AWS CDK + Ansible). It keeps the i2 application contract identical and swaps the AWS platform layer for Azure-native services.

Author: Korin Taunton, Lead Architect. Shared with i2 Group for collaboration.

## What this deploys

i2 Analyze as containers on Azure Kubernetes Service (AKS), with the data tier on Azure SQL Managed Instance:

- Liberty (i2 Analyze application) - AKS Deployment, 2 replicas
- i2 Connect connectors - AKS Deployments, mutual TLS
- SolrCloud - AKS StatefulSet, 2 nodes (on containers)
- ZooKeeper - AKS StatefulSet, 3 nodes
- Information Store - Azure SQL Managed Instance (managed, off containers)

Around the cluster: Azure Container Registry (private, builds the configured Liberty image), Key Vault (the i2 secret and PKI set), Azure Monitor (Log Analytics, managed Prometheus and Grafana), Blob storage (the i2 distribution and shared config), and an internal ingress. Everything is private: private AKS API, private endpoints, no public data paths.

See `docs/architecture.svg` for the target diagram and `docs/architecture.md` for the narrative.

## How it maps to i2's `ansible-i2a`

Same application, different platform layer. Full detail in `docs/aws-to-azure-mapping.md`.

| i2 `ansible-i2a` (AWS) | This repo (Azure) |
|---|---|
| AWS CDK (brownfield stacks) | Bicep (`bicep/`) |
| Ansible controller + roles | Pipeline stages calling `scripts/` |
| ECS Fargate (Liberty, connectors) | AKS Deployments |
| Dedicated EC2 (Solr, ZooKeeper) | AKS StatefulSets |
| RDS PostgreSQL | Azure SQL Managed Instance (SQL Server) |
| ECR | Azure Container Registry |
| Secrets Manager + SSM | Azure Key Vault |
| S3 artefact bucket | Azure Blob storage |
| ALB / NLB | Azure Application Gateway / internal Load Balancer |
| CloudWatch / CloudMap | Azure Monitor / private DNS |
| IAM roles | Managed identities + Azure RBAC |

The application contract is unchanged: Liberty `/opal` on 9443, Solr TLS on 8983, ZooKeeper secure client on 2281 with digest auth, the same secret and PKI set, the same 8 Solr collections, TLS end to end, offline-first, no inbound SSH.

## Repo layout

```
i2-analyze-azure/
  README.md
  docs/                     architecture, mapping, deployment order, decisions, familiarisation
    architecture.svg        Azure target diagram
  bicep/                    Azure infrastructure
    main.bicep              subscription-scope entry point
    bicepconfig.json        ACR naming-module alias
    modules/                network, keyvault, acr, aks, monitoring, workload-identity, storage, sql-mi
    parameters/             *.bicepparam (placeholders; real values via pipeline variables)
  k8s/                      Kubernetes manifests (Solr, ZooKeeper, Liberty, connectors, services, ingress)
    jobs/                   db_init and solr_collections bootstrap Jobs
  scripts/                  CI-agnostic deploy logic (run locally or from any pipeline)
  pipelines/                azure-pipelines.yml (Azure DevOps)
  config/                   where the i2 shared config lands (distribution obtained separately)
```

## Prerequisites

- An i2 Analyze licence and the i2 distribution / container images (obtained from i2, never committed here). See `config/README.md`.
- Azure subscription, region uksouth, and an existing (brownfield) VNet the i2 subnets attach to.
- A private container registry (ACR) reachable from the build agent, and a self-hosted pipeline agent on the VNet for the private endpoints and the private AKS API.
- The naming module `br/core:naming:latest` (ACR-hosted function import) available to Bicep.
- Tooling: az + Bicep, kubectl, kubelogin, Docker, openssl. The dev container (`.devcontainer/`) provides all of them - open the repo in VS Code and "Reopen in Container", then `az login`.

## Quickstart (discovery-first)

1. Obtain the i2 distribution and push the base images into ACR, or `az acr import` them. See `docs/deployment.md`.
2. Fill `bicep/parameters/alpha.bicepparam` (or supply via pipeline variables). No secrets in the file.
3. Deploy infrastructure: `scripts/10-deploy-infra.sh`.
4. Seed the secret and PKI set into Key Vault: `scripts/20-seed-secrets-pki.sh`.
5. Build and push the images with ADT locally (i2-recommended): on a build box with Docker and the licensed distribution, ADT builds the configured Liberty image and you push it plus the base images to ACR: `scripts/30-build-images.sh`.
6. Deploy the workload: `scripts/40-deploy-workload.sh`.
7. Bootstrap data (Information Store schema + Solr collections): `scripts/50-bootstrap-data.sh`.
8. Verify: `scripts/60-sanity.sh`.

The Azure DevOps pipeline (`pipelines/azure-pipelines.yml`) runs the same scripts as ordered stages.

## Status

Alpha proved the platform end to end on AKS (Liberty, Solr, ZooKeeper, and a SQL Server container all running). This repo is the canonical, shareable version and moves the data tier to SQL Managed Instance. See `docs/decisions.md`.

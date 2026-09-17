# i2 Analyze on Azure

Infrastructure-as-code, Kubernetes manifests and pipelines to deploy i2 Analyze on Microsoft Azure. This is the Azure counterpart to i2's `ansible-i2a` reference (AWS CDK + Ansible). It keeps the i2 application contract identical and swaps the AWS platform layer for Azure-native services.

Generic and reusable: any organisation can deploy it into its own subscription, with a new network or an existing one, through Azure DevOps. Developed in collaboration with i2 Group.

## What this deploys

i2 Analyze as containers on Azure Kubernetes Service (AKS), with the data tier on Azure SQL Managed Instance:

- Liberty (i2 Analyze application) - AKS StatefulSet, 2 replicas, a data volume each
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
| ECS Fargate (Liberty, connectors) | AKS StatefulSet (Liberty), Deployments (connectors) |
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
    naming/                 resource naming functions (CAF abbreviations, no registry needed)
    modules/                network, keyvault, acr, aks, monitoring, workload-identity, storage, sql-mi
    parameters/             <env>.bicepparam per environment; copy example.bicepparam
  k8s/                      Kubernetes manifests (Solr, ZooKeeper, Liberty, connectors, services, ingress)
    jobs/                   solr-zk-init, solr-collections, db-init and match-rules Jobs
  images/solr-init/         Solr cluster init image (ADT solr_client + generated configsets)
  images/db-init/           Information Store init image (ADT sqlserver_client + generated DB scripts)
  images/i2-tools/          i2 tools image for the system match rules Job (ADT i2a_tools + config)
  scripts/                  CI-agnostic deploy logic (run locally or from any pipeline)
  pipelines/                azure-pipelines.yml (Azure DevOps)
  config/                   where the i2 shared config lands (distribution obtained separately)
```

## Prerequisites

- An i2 Analyze licence and the **i2 Analyze minimal toolkit** (requested from i2 support, never committed here). See `config/README.md`.
- An Azure subscription, and an Azure DevOps project for the pipeline. A VNet is optional: `networkMode = 'new'` creates one, `'existing'` attaches to yours.
- A self-hosted Azure DevOps agent that can reach the i2 VNet (Key Vault, ACR and AKS are private). The deployment creates a subnet for it.
- Tooling comes in one dev container (`.devcontainer/adt`), **i2 - ADT + Azure**, opened from a WSL 2 clone: ADT for building images plus az, Bicep and kubectl. See [docs/how-to/set-up-the-dev-container.md](docs/how-to/set-up-the-dev-container.md).

## Getting started

Follow **[docs/how-to/runbook.md](docs/how-to/runbook.md)**: every step, where to do it (dev container or pipeline), what to do, and what you should see.

In short:
1. One-time setup: dev container, `bicep/parameters/<env>.bicepparam` (copy `example.bicepparam`), Azure DevOps (service connection, variable group, environment, pipeline).
2. **Pipeline:** create the infrastructure (Bicep: VNet, Key Vault, ACR, AKS, SQL MI, ...), then a self-hosted agent on its subnet, then secrets and certificates.
3. **Dev container:** build the i2 images with ADT, `scripts/30-build-images.sh` pushes them to ACR.
4. **Pipeline:** deploy i2 to AKS in ADT's order, then run the sanity checks.

Resource names come from the naming functions in `bicep/naming` (CAF abbreviations, for example `kv-i2-dev-001`); the scripts read them from the deployment, so they are never typed by hand. The pipeline never runs automatically; deploys run manually, stage by stage, with previews (what-if / diff) and per-component redeploys.

## Status

An earlier alpha proved the platform on AKS (Liberty, Solr, ZooKeeper and a SQL Server container). This repository is the generic, shareable version, with the data tier on SQL Managed Instance and the i2 application layer aligned to ADT 3.2.2. See `docs/decisions.md`.

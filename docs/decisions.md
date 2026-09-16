# Platform decisions

## Data tier: Azure SQL Managed Instance
SQL Server engine, on Managed Instance (managed, HA, backups), off containers. i2's cloud reference uses managed PostgreSQL (RDS); SQL Server is a supported ADT engine (i2 ships the SQL Server image and the MSSQL JDBC driver), so `DB_DIALECT=sqlserver`. MI is required rather than Azure SQL Database because the Information Store needs SQL Agent, server-level sysadmin (BULK INSERT), and instance collation. MI collation is set at creation and is immutable: confirm the i2-required collation against the 4.4.x prerequisites before deploying.

## Solr on containers (AKS StatefulSet)
i2's AWS reference runs Solr on dedicated EC2 for huge pages, local NVMe, low-jitter networking and stable node identity, which it notes are awkward under ECS task scheduling. That is a Fargate scheduling constraint, not a containers constraint. On AKS a StatefulSet gives stable identity, a dedicated node pool gives isolation, and huge pages / local-NVMe VM SKUs / Premium SSD cover the storage and memory needs. Solr runs as a StatefulSet here on its own tainted `i2solr` node pool. Proven 2/2 in alpha.
The VM setup ADT performs is reproduced in the cluster: ADT's `solr_redhat` image (i2 plugin jars), `SOLR_HOST` set to the pod FQDN, and Jobs for the ZooKeeper chroot / `urlScheme=https` / `security.json` / configsets and for the collections (see `images/solr-init`). Secrets and users match ADT 3.2.2 (`utils/server_functions.sh`, `scripts/deploy`).

## ZooKeeper on containers (AKS StatefulSet)
Agreed with i2. Three-node ensemble, secure client port 2281, digest auth. Proven 3/3 in alpha.

## Liberty and connectors on AKS
Liberty as a Deployment (stateless), i2 Connect connectors as their own Deployments with mutual TLS. Equivalent to the reference's ECS Fargate services.

## Net
Liberty, Solr and ZooKeeper all on AKS. SQL Managed Instance is the only off-cluster tier.

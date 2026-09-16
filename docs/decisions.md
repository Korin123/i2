# Platform decisions

## Data tier: Azure SQL Managed Instance
SQL Server engine, on Managed Instance (managed, HA, backups), off containers. i2's cloud reference uses managed PostgreSQL (RDS); SQL Server is a supported ADT engine (i2 ships the SQL Server image and the MSSQL JDBC driver), so `DB_DIALECT=sqlserver`. MI is required rather than Azure SQL Database because the Information Store needs SQL Agent, server-level sysadmin (BULK INSERT), and instance collation. MI collation is set at creation and is immutable.

**Collation.** i2 sets the Information Store collation in the i2 configuration (`Collation` in `InfoStoreNamesSQLServer.properties`), and applies it when the database is created. The value comes from the toolkit's copy of that file, so it is read from our config, not assumed: `scripts/30-build-images.sh` prints it next to `sqlMiCollation` and warns if they differ, and the db-init Job creates ISTORE with it and warns if the database and instance collations differ (tempdb uses the instance collation). Set `sqlMiCollation` to the config value before the Managed Instance is first created.

**Network path.** AKS nodes reach the MI on 1433 with no extra NSG rules: both subnets' NSGs carry no custom rules, so the default VirtualNetwork allow rules apply (AKS overlay pod traffic leaves from node IPs in the AKS subnet), no Kubernetes NetworkPolicies are defined, and the MI uses the Proxy connection type (1433 only; Redirect would also need 11000-11999). The `/27` MI subnet fits one General Purpose instance including scaling headroom (5 + 4 + 8 = 17 addresses, Microsoft's formula). Two things outside this repo must hold on the brownfield VNet: no hub firewall/UDR or deny rules blocking AKS subnet to MI subnet, and DNS that resolves the MI's `<name>.<zone>.database.windows.net` (custom DNS servers must forward to Azure DNS).

**TLS trust.** The MI presents a certificate from a public Microsoft chain, and i2 containers never skip certificate verification (ADT: external systems must be trusted via `SSL_ADDITIONAL_TRUST_CERTIFICATES`). `scripts/20-seed-secrets-pki.sh` stores the Azure SQL root CAs (DigiCert Global Root G2 / Global Root CA, Microsoft RSA Root CA 2017) in Key Vault as `ssl-additional-trust-certificates`, passed to Liberty and the db-init Job.

## Solr on containers (AKS StatefulSet)
i2's AWS reference runs Solr on dedicated EC2 for huge pages, local NVMe, low-jitter networking and stable node identity, which it notes are awkward under ECS task scheduling. That is a Fargate scheduling constraint, not a containers constraint. On AKS a StatefulSet gives stable identity, a dedicated node pool gives isolation, and huge pages / local-NVMe VM SKUs / Premium SSD cover the storage and memory needs. Solr runs as a StatefulSet here on its own tainted `i2solr` node pool. Proven 2/2 in alpha.
The VM setup ADT performs is reproduced in the cluster: ADT's `solr_redhat` image (i2 plugin jars), `SOLR_HOST` set to the pod FQDN, and Jobs for the ZooKeeper chroot / `urlScheme=https` / `security.json` / configsets and for the collections (see `images/solr-init`). Secrets and users match ADT 3.2.2 (`utils/server_functions.sh`, `scripts/deploy`).

## ZooKeeper on containers (AKS StatefulSet)
Agreed with i2. Three-node ensemble, secure client port 2281, digest auth. Proven 3/3 in alpha.

## Liberty and connectors on AKS
Liberty as a StatefulSet with a `/data` volume per pod (as ADT gives each Liberty server its own volume), i2 Connect connectors as their own Deployments with mutual TLS. Equivalent to the reference's ECS Fargate services.

## Net
Liberty, Solr and ZooKeeper all on AKS. SQL Managed Instance is the only off-cluster tier.

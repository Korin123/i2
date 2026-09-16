# Deployment

End-to-end order. Scripts in `scripts/` are CI-agnostic; `pipelines/azure-pipelines.yml` runs them as stages. i2's recommendation is to build and push the images with ADT locally, then deploy from Azure.

## Prerequisites
- i2 licence + distribution. In the dev container (from WSL 2), run `scripts/05-install-adt.sh` (ADT bootstrap, pulls `i2eng-analyze-containers-client:<version>`). Obtain the i2 base images and the shared config.
- Azure: subscription, region uksouth, existing VNet with the i2 /24 added, ACR, Key Vault, a self-hosted agent on the VNet.
- Naming module `br/core:naming:latest` available to Bicep.

## Steps

1. Infrastructure (`scripts/10-deploy-infra.sh`): `az deployment sub create` of `bicep/main.bicep` - network subnets (incl. the delegated SQL MI subnet), Key Vault, ACR, AKS, monitoring, workload identity, and the SQL Managed Instance. MI first creation takes hours; run it early.

2. Secrets + PKI (`scripts/20-seed-secrets-pki.sh`): generate the i2 password set and the CA + leaf certs, store in Key Vault. Idempotent - existing secrets are reused, never overwritten (no re-passwording a live system). Solr/ZooKeeper secrets follow ADT 3.2.2: Solr BasicAuth users `solr` (admin) and `liberty` (application) with a generated `security.json`, ZooKeeper digest users `solr` and `readonly-user`, and a `solr-client` cert. Solr/ZooKeeper leaf certs carry the headless-service wildcard SANs the pods are addressed by; to reissue existing certs run with `REISSUE_CERTS="solr zookeeper"`.

3. Build + push images with ADT in the dev container (`scripts/30-build-images.sh`), i2-recommended:
   - `az acr import` the image used as-is (i2 ZooKeeper) into ACR.
   - Link the ADT environment to the `base-demo` shared config (`manage-environment -t link`) and build the configured Liberty image (`deploy -c base-demo -t package`, produces `liberty_configured_redhat:base-demo-<version>`).
   - Generate the Solr configsets from the assembled config with `i2a_tools_redhat generateSolrSchemas.sh`, and bake them into `i2-solr-init` (ADT `solr_client_redhat` + `images/solr-init/solr-init.sh`).
   - Bake the scripts from `deploy -c base-demo -t generate-db-scripts` into `i2-db-init` (ADT `sqlserver_client_redhat` + `images/db-init/db-init.sh`).
   - Push the configured Liberty image, ADT's `solr_redhat` (i2eng-solr + i2 plugin jars), `i2-solr-init` and `i2-db-init` to ACR.
   This runs on a build box with Docker and the distribution; it is not run in-cluster.

4. Workload (`scripts/40-deploy-workload.sh`): `kubectl apply` in ADT's order - namespace, SecretProviderClass, services, ZooKeeper -> Job `i2-solr-zk-init` (create `/is_cluster`, `urlScheme=https`, upload `security.json` and the 8 configsets) -> Solr (dedicated `i2solr` node pool) -> Job `i2-solr-collections` (create the 8 collections) -> Liberty, connectors, ingress. The Jobs are idempotent and re-run on every deploy.

5. Bootstrap data (`scripts/50-bootstrap-data.sh`): run the `i2-db-init` Job - ADT's SQL Server sequence (`initialize_istore_database_for_sql_server` + `configure_istore_database`) against the MI as the MI admin login: create ISTORE (the generated creation script, or a plain `CREATE DATABASE` if Managed Instance rejects it), `dba` login/user, roles and grants, `dbb`/`i2analyze`/`i2etl`/`etl` logins, `etl` to sysadmin, static then dynamic scripts, `i2_public_role` and `deletion_by_rule` memberships. Each step is recorded as an `i2aks.<step>` extended property on ISTORE, so a failed run resumes where it stopped. The config must use `DB_DIALECT=sqlserver` when generating the scripts.

6. Sanity (`scripts/60-sanity.sh`): ZK ruok/mntr, Solr mode=solrcloud and 8 collections present, MI reachable, Liberty health and context root.

## Notes
- MI collation is immutable at creation - confirm the i2-required value first.
- The build box needs outbound to i2's image source once to seed ACR; AKS nodes pull only from the private ACR.

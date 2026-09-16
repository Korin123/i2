# Deployment

End-to-end order. Scripts in `scripts/` are CI-agnostic; `pipelines/azure-pipelines.yml` runs them as stages. i2's recommendation is to build and push the images with ADT locally, then deploy from Azure.

## Prerequisites
- i2 licence + distribution. In the dev container (from WSL 2), run `scripts/05-install-adt.sh` (ADT bootstrap, pulls `i2eng-analyze-containers-client:<version>`). Obtain the i2 base images and the shared config.
- Azure: subscription, region uksouth, existing VNet with the i2 /24 added, ACR, Key Vault, a self-hosted agent on the VNet.
- Naming module `br/core:naming:latest` available to Bicep.

## Steps

1. Infrastructure (`scripts/10-deploy-infra.sh`): `az deployment sub create` of `bicep/main.bicep` - network subnets (incl. the delegated SQL MI subnet), Key Vault, ACR, AKS, monitoring, workload identity, and the SQL Managed Instance. MI first creation takes hours; run it early.

2. Secrets + PKI (`scripts/20-seed-secrets-pki.sh`): generate the i2 password set and the CA + leaf certs, store in Key Vault. Idempotent - existing secrets are reused, never overwritten (no re-passwording a live system).

3. Build + push images with ADT locally (`scripts/30-build-images.sh`), i2-recommended:
   - `az acr import` the i2 base images (Liberty base, Solr, i2 ZooKeeper, tools/client) into ACR, or docker pull/tag/push.
   - Link the ADT environment to the `base-demo` shared config (`manage-environment -t link`).
   - Build the configured Liberty image: ADT `deploy -c base-demo -t package` (produces `liberty_configured_redhat:base-demo-<version>`).
   - `az acr login` and `docker push` the configured image and the base images to ACR.
   This runs on a build box with Docker and the distribution; it is not run in-cluster.

4. Workload (`scripts/40-deploy-workload.sh`): `kubectl apply` the manifests - namespace, SecretProviderClass, ZooKeeper, Solr, Liberty, connectors, services, ingress. Order: ZooKeeper -> Solr -> Liberty.

5. Bootstrap data (`scripts/50-bootstrap-data.sh`): run the Jobs - `db-init` (ADT DB scripts against the SQL MI, MSSQL path: create ISTORE, roles, app users, static then dynamic scripts) and `solr-collections` (generate schemas via the tools image, upload configsets, create the 8 collections).

6. Sanity (`scripts/60-sanity.sh`): ZK ruok/srvr, Solr mode=solrcloud and 8 collections present, MI reachable, Liberty health and context root.

## Notes
- MI collation is immutable at creation - confirm the i2-required value first.
- The build box needs outbound to i2's image source once to seed ACR; AKS nodes pull only from the private ACR.

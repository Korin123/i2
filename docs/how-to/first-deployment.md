# Deploy an environment for the first time

Run from the dev container, or tick the same stages in the pipeline ([deploy-with-the-pipeline.md](deploy-with-the-pipeline.md)). Check each step worked before moving on.

0. **Before the Managed Instance exists**, set the collation. It cannot change afterwards. Read `Collation` from `InfoStoreNamesSQLServer.properties` in your i2 config (in the dev container after `deploy -c base-demo -t package`: `grep -r Collation adt/.tmp/.configuration --include=InfoStoreNamesSQLServer.properties`) and set `sqlMiCollation` in `bicep/parameters/alpha.bicepparam` to the same value. Also check with the VNet owner that the VNet's DNS resolves `*.database.windows.net` and nothing blocks the AKS subnet reaching the MI subnet on 1433.
1. **Preview the infrastructure**, then deploy it. SQL Managed Instance takes hours the first time.
   ```bash
   WHAT_IF=true scripts/10-deploy-infra.sh
   scripts/10-deploy-infra.sh
   ```
   Bicep names and creates everything. The script prints the names at the end; the other scripts read them from the deployment (`i2-infra-alpha`), so nothing needs copying into `scripts/env.sh`.
2. **Seed secrets and certificates** into Key Vault:
   ```bash
   scripts/20-seed-secrets-pki.sh
   ```
3. **Build and push the images**: [build-and-push-images.md](build-and-push-images.md).
4. **Deploy the workload**: ZooKeeper, Solr setup, Solr, collections, the Information Store database, Liberty, then the system match rules, in the order ADT uses.
   ```bash
   DRY_RUN=true scripts/40-deploy-workload.sh     # optional preview
   scripts/40-deploy-workload.sh
   ```
   The database step can take a while the first time. If it fails, fix the cause and run `scripts/50-bootstrap-data.sh` to resume it, then `scripts/40-deploy-workload.sh liberty match-rules ingress`.
5. **Verify**:
   ```bash
   scripts/60-sanity.sh
   ```
   Every line should say `PASS`. If not, see [troubleshoot-sanity-failures.md](troubleshoot-sanity-failures.md).

If a step fails, fix the cause and re-run that step. Every script is safe to re-run.

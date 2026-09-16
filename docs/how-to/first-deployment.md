# Deploy an environment for the first time

Run from the dev container, or tick the same stages in the pipeline ([deploy-with-the-pipeline.md](deploy-with-the-pipeline.md)). Check each step worked before moving on.

1. **Preview the infrastructure**, then deploy it. SQL Managed Instance takes hours the first time.
   ```bash
   WHAT_IF=true scripts/10-deploy-infra.sh
   scripts/10-deploy-infra.sh
   ```
   Copy the outputs `workloadIdentityClientId` and `sqlManagedInstanceFqdn` into `scripts/env.sh` as `WI_CLIENT_ID` and `MI_FQDN`.
2. **Seed secrets and certificates** into Key Vault:
   ```bash
   scripts/20-seed-secrets-pki.sh
   ```
3. **Build and push the images**: [build-and-push-images.md](build-and-push-images.md).
4. **Deploy the workload** (ZooKeeper, Solr setup, Solr, collections, Liberty):
   ```bash
   DRY_RUN=true scripts/40-deploy-workload.sh     # optional preview
   scripts/40-deploy-workload.sh
   ```
5. **Create the Information Store**:
   ```bash
   scripts/50-bootstrap-data.sh
   ```
6. **Verify**:
   ```bash
   scripts/60-sanity.sh
   ```
   Every line should say `PASS`. If not, see [troubleshoot-sanity-failures.md](troubleshoot-sanity-failures.md).

If a step fails, fix the cause and re-run that step. Every script is safe to re-run.

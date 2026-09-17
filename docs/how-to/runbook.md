# Runbook: i2 Analyze on Azure, start to finish

Every step says **where** to do it, **what to do**, and **what you should see**. Do the steps in order; each one is safe to repeat if it fails.

The two places you work:

| | What it is | Used for |
|---|---|---|
| **Dev container** | VS Code "i2 - ADT + Azure" container, opened from a clone inside WSL ([set up](set-up-the-dev-container.md)) | Building the i2 images with ADT and pushing them to ACR |
| **Pipeline** | The Azure DevOps pipeline `pipelines/azure-pipelines.yml` ([set up](set-up-azure-devops.md)) | Creating Azure, secrets, deploying i2, checking it |

Throughout, `<env>` is your environment name, for example `dev`.

---

## Part 1: one-time setup

### 1. Dev container
**Where:** your PC.
**Do:** follow [set-up-the-dev-container.md](set-up-the-dev-container.md) (WSL clone, "i2 - ADT + Azure"). Then in its terminal:
```bash
az login
cp scripts/env.example scripts/env.sh
```
Edit `scripts/env.sh`: `SUBSCRIPTION_ID`, `LOCATION`, `I2_ENV=<env>`.
**You should see:** the terminal prompt `vscode ➜ /home/<you>/i2`.

### 2. Parameter file
**Where:** the repo (dev container or any editor).
**Do:** copy `bicep/parameters/example.bicepparam` to `bicep/parameters/<env>.bicepparam` and set:
- `environment = '<env>'`, `location`
- `networkMode`: `'new'` (nothing exists yet) or `'existing'` (attach to your VNet: set the three `existing*` values)
- `aksAdminGroupObjectId`: Entra group that administers AKS
- the public IP of the PC that will push images (find it with `curl -s ifconfig.me`): **not** in the file if the repo is public. Put it in the variable group as `ALLOWED_TEST_IPS` (step 3)
- `sqlMiCollation`: the value i2 gives you, or leave the default for a throwaway environment you will recreate

Commit and push it.
**You should see:** the Validate stage passes on the next pipeline run.

### 3. Azure DevOps
**Where:** Azure DevOps.
**Do:** follow [set-up-azure-devops.md](set-up-azure-devops.md): service connection, variable group `i2-<env>`, environment `i2-<env>`, create the pipeline, set its four Setup defaults.
**You should see:** a manual run with nothing ticked finishes with only Validate green.

---

## Part 2: create Azure

### 4. Preview the infrastructure
**Where:** Pipeline → Run pipeline.
**Do:** tick **Infra: deploy Bicep**, leave **Infra: preview only** ticked, untick everything else. Run.
**You should see:** the DeployInfra log lists what would be created (resource group, VNet, Key Vault, ACR, AKS, SQL MI, ...). Nothing is changed.

### 5. Create the infrastructure
> The collation cannot change after the SQL Managed Instance exists. For a real environment, confirm it first. For a throwaway one (like `alpha`: purge protection off, small SQL MI), go ahead and destroy and recreate it later if the collation changes ([destroy-an-environment.md](destroy-an-environment.md)).

**Where:** Pipeline → Run pipeline.
**Do:** tick **Infra: deploy Bicep**, **untick** Infra: preview only. Run.
**You should see:** DeployInfra succeeds after a few hours (the SQL Managed Instance is slow the first time) and prints the names it created (RG, KV, ACR, AKS, ...). Nothing needs copying: later steps read them.

### 6. Agent on the VNet
**Where:** Azure portal / Azure CLI and Azure DevOps.
**Do:** create a self-hosted agent in the `snet-i2-agents` subnet and add it to your VNet agent pool ([set-up-azure-devops.md, step 5](set-up-azure-devops.md#5-self-hosted-agent-on-the-i2-vnet)).
**You should see:** the agent shows **Online** in the pool.

### 7. Secrets and certificates
**Where:** Pipeline → Run pipeline.
**Do:** tick **Secrets: seed missing secrets + certs**, untick everything else. Run.
**You should see:** SeedSecrets succeeds with lines like `seeded db-dba-password`, `seeded solr cert/key`, `PKI + secret set seeded into kv-...`.

---

## Part 3: build and push the i2 images

Needs the **i2 Analyze minimal toolkit** from i2 support ([how to request it](https://i2group.github.io/analyze-deployment-tooling/versions/3.2.2/content/getting_started.html)).

### 8. Install ADT
**Where:** Dev container.
**Do:** copy the toolkit to `adt/pre-reqs/i2analyzeMinimal.tar.gz`, then:
```bash
./scripts/05-install-adt.sh
```
**You should see:** `ADT 3.2.2 installed in adt/`.

### 9. Build with ADT
**Where:** Dev container.
**Do:** create the configuration from ADT's template, then set `DEPLOYMENT_PATTERN="istore"` and `DB_DIALECT="sqlserver"` in `adt/configs/base-demo/utils/variables.conf` ([simple guide](build-and-push-images.md)):
```bash
cp -r adt/templates/config-development adt/configs/base-demo
deploy -c base-demo -t package
deploy -c base-demo -t generate-db-scripts -y
./scripts/30-build-images.sh build
```
**You should see:** `Images built locally: ...` and a line `Information Store collation from the i2 config: <value>`. If it warns that the collation differs from `sqlMiCollation`, fix the parameter file, then destroy and recreate the environment if it already exists.

### 10. Push the images to ACR
**Where:** Dev container (your IP must be in `ALLOWED_TEST_IPS` in the variable group when the infrastructure was deployed, or run this from a machine on the VNet).
**Do:**
```bash
./scripts/30-build-images.sh push
```
**You should see:** `Images in ACR.`

---

## Part 4: deploy and check i2

### 11. Preview the workload
**Where:** Pipeline → Run pipeline.
**Do:** tick **Workload: deploy to AKS** and **Workload: preview only**. Components `all`. Run.
**You should see:** the DeployWorkload log shows what would be created in AKS.

### 12. Deploy the workload
**Where:** Pipeline → Run pipeline.
**Do:** tick **Workload: deploy to AKS**, untick preview, components `all`. Run.
**You should see:** in order: ZooKeeper, Solr setup, Solr, collections, Information Store, Liberty, system match rules, then `Done.`

### 13. Check it works
**Where:** Pipeline → Run pipeline.
**Do:** tick only **Verify: run sanity checks**. Run.
**You should see:** every line `PASS` and `All checks passed.` If not: [troubleshoot-sanity-failures.md](troubleshoot-sanity-failures.md).

---

## Later

| I want to | Do |
|---|---|
| Change infrastructure | Edit `bicep/` or `<env>.bicepparam`, then steps 4 and 5 |
| Change the i2 configuration | Steps 9 and 10, then step 12 with components for what changed ([fix-and-redeploy.md](fix-and-redeploy.md)) |
| Redeploy one part | Step 12 with components set, e.g. `liberty` |
| Reissue certificates | Step 7 with **Secrets: reissue these certs** set, e.g. `solr zookeeper` ([certificates-and-secrets.md](certificates-and-secrets.md)) |
| Resume a failed database setup | Step 12 with components `database` |
| Delete everything and start again | [destroy-an-environment.md](destroy-an-environment.md), then from step 5 |

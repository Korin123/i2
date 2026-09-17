# Build the i2 images: the simple guide

You build the i2 images on your PC with i2's tooling (ADT), then send them to Azure. Two halves:

- **Part A: build.** Needs the toolkit from i2. Does **not** need Azure.
- **Part B: push.** Needs the Azure infrastructure to exist (runbook step 5).

Every command below goes in **one place**: the terminal inside the dev container.

---

## Before you start: open the right terminal

New PC? Do [set-up-the-dev-container.md](set-up-the-dev-container.md) first.

1. Start **Docker Desktop** and wait until it says it is running.
2. Open your WSL terminal (Start menu → **Ubuntu**) and go to wherever you cloned the repo:
   ```bash
   cd ~/dev/projects/i2 && code .
   ```
3. VS Code opens. If it asks, click **Reopen in Container** (or **F1 → Dev Containers: Reopen in Container**).
4. Wait until the bottom-left corner says **Dev Container: i2 - ADT + Azure**.
5. **Terminal → New Terminal**. Get the latest code:
   ```bash
   git pull
   ```

**You should see:** a prompt like `vscode ➜ /home/<you>/i2 (main) $`. Every command in this guide goes here.

---

## Part A: build (once the toolkit arrives)

### A1. Put the toolkit in place
i2 sends a file named something like `i2analyzeMinimal_446.tar.gz`.

**Do:** in the VS Code **Explorer** (left), right-click the `i2` folder → **New Folder** → `adt`, then inside it `pre-reqs`. Drag the file from Windows onto `adt/pre-reqs`, then rename it to exactly:
```
i2analyzeMinimal.tar.gz
```
**Check:**
```bash
ls -lh adt/pre-reqs/
```
**You should see:** `i2analyzeMinimal.tar.gz` and a size in MB. It is git-ignored; it will never be committed.

### A2. Install ADT
```bash
./scripts/05-install-adt.sh
```
This downloads i2's tooling and builds i2's base images. It takes a while the first time; leave it running.

**You should see at the end:** `>>> ADT 3.2.2 installed in adt/.`
**Check:**
```bash
docker images | grep redhat
```
**You should see:** `solr_redhat`, `solr_client_redhat`, `i2a_tools_redhat`, `sqlserver_client_redhat`, each with tag `4.4.6.1`.
**If some are missing:** run `manage-environment -t update`, then check again.

### A3. Create the i2 configuration
Copy ADT's starter configuration and call it `base-demo` (the name the scripts expect):
```bash
cp -r adt/templates/config-development adt/configs/base-demo
```
Open `adt/configs/base-demo/utils/variables.conf` and set these two lines (Azure uses SQL Server and the Information Store):
```
DEPLOYMENT_PATTERN="istore"
DB_DIALECT="sqlserver"
```
Save.

**Later:** replace this starter configuration with your real i2 schema; the steps below stay the same.

### A4. Build the i2 application image
```bash
deploy -c base-demo -t package
```
**You should see:** it finish without `ERROR`. Check:
```bash
docker images | grep liberty_configured
```
**You should see:** `liberty_configured_redhat` with tag `base-demo-4.4.6.1`.

### A5. Generate the database scripts
```bash
deploy -c base-demo -t generate-db-scripts -y
```
**You should see:** it finish without `ERROR`, and a new folder `adt/configs/base-demo/database-scripts/generated`.

### A6. Build our three helper images
```bash
./scripts/30-build-images.sh build
```
**You should see:**
- a line `Information Store collation from the i2 config: ...`. **Note this value.** It must match `sqlMiCollation` in `bicep/parameters/alpha.bicepparam` **before** the infrastructure is created. A `WARNING` means they differ: fix the parameter file.
- at the end: `Images built locally: ...`

**Part A is done.** You can repeat it any time; nothing leaves your PC.

---

## Part B: push to Azure (after the infrastructure exists)

### B1. Sign in and check your settings
```bash
az login
az account show --query name -o tsv
cat scripts/env.sh
```
**You should see:** your subscription name, and `env.sh` with `I2_ENV="alpha"`.

### B2. Push
```bash
./scripts/30-build-images.sh push
```
It finds the registry name from the Azure deployment by itself. You type no names.

**You should see at the end:** `Images in ACR.`

**If it fails:**

| Message | Fix |
|---|---|
| `No infra deployment 'i2-infra-alpha' found` | The infrastructure isn't created yet (runbook step 5), or `I2_ENV` in `scripts/env.sh` is wrong |
| `missing local image ...` | Redo Part A |
| `denied` / `unauthorized` / timeout on push | Your public IP isn't allowed. Run `curl -s ifconfig.me`, add it to `allowedTestIps` in `alpha.bicepparam`, rerun the infra pipeline, try again |

**Part B is done.** Next: runbook step 11 (deploy the workload with the pipeline).

---

## Changed the i2 configuration later?

Edit `adt/configs/base-demo`, then run A4, A5, A6 and B2 again, and redeploy with the pipeline ([fix-and-redeploy.md](fix-and-redeploy.md)).

## What gets pushed

| Image | What it is |
|---|---|
| `liberty_configured_redhat:base-demo-4.4.6.1` | i2 Analyze with your configuration built in |
| `solr_redhat:4.4.6.1` | Solr with i2's plugins |
| `i2-solr-init:4.4.6.1` | sets up the Solr cluster and collections |
| `i2-db-init:4.4.6.1` | sets up the Information Store database |
| `i2-tools:4.4.6.1` | loads the system match rules |
| `i2eng-zookeeper:3.9` | ZooKeeper, copied from Docker Hub |

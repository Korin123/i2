# Set up Azure DevOps

One-time setup so `pipelines/azure-pipelines.yml` can create and deploy an i2 environment. `<env>` is your environment name (for example `dev`), matching `bicep/parameters/<env>.bicepparam`.

## 1. Service connection

**Where:** Project settings → Service connections → New service connection → **Azure Resource Manager**.
**Do:**
- Identity type: **App registration (automatic)**, credential **Workload identity federation**.
- Scope level: **Subscription**, pick the subscription. Leave resource group empty (the pipeline creates it).
- Name it, for example `i2-azure`.
- Give its service principal **Owner** on the subscription (or **Contributor** + **User Access Administrator**). The deployment creates a resource group and role assignments (AKS pulling from ACR, Key Vault access).

**Optional:** allow it to read its own directory entry (for example the **Directory Readers** role). `scripts/10` then looks up its object ID automatically. Otherwise set `deployerObjectId` in the parameter file: Entra ID → Enterprise applications → the service connection's app → Object ID.

## 2. Variable group

**Where:** Pipelines → Library → **+ Variable group**.
**Do:** name it `i2-<env>`, add:

| Variable | Example |
|---|---|
| `SUBSCRIPTION_ID` | your subscription ID |
| `LOCATION` | `uksouth` |
| `I2_VERSION` | `4.4.6.1` |
| `ADT_VERSION` | `3.2.2` |
| `ALLOWED_TEST_IPS` | optional: public IPs (space-separated) allowed through the Key Vault and ACR firewalls, e.g. the PC that pushes images. Kept here, not in the repo |
| `AKS_ADMIN_GROUP_OBJECT_ID` | Object ID of the Entra group that administers the environment (AKS cluster admin, Grafana admin, ACR push). Kept here, not in the repo |
| `VNET_AGENT_POOL` | name of the in-VNet agent pool (step 5), e.g. `mdp-i2-alpha`. The secrets, workload and sanity stages run on it |
| `CREATE_VNET_AGENT_POOL` | optional, `true` to have the Infra run create the pool (step 5, "Automate it instead") |

Resource names are not needed: the pipeline reads them from the infrastructure deployment.

## 3. Environment (approvals)

**Where:** Pipelines → Environments → **New environment**.
**Do:** name it `i2-<env>`, resource **None**. Optionally: ⋮ → Approvals and checks → **Approvals**, add who must approve infrastructure and workload deployments.

## 4. Pipeline

**Where:** Pipelines → **New pipeline** → your repository → **Existing Azure Pipelines YAML file** → `/pipelines/azure-pipelines.yml`.
**Do:** before saving, edit the defaults of the three **Setup** parameters at the top of the file (or commit the change):

| Parameter | Set default to |
|---|---|
| `environment` | `<env>` |
| `serviceConnection` | the name from step 1 |
| `infraOnMicrosoftHosted` | `true` (Infra must be able to run before the VNet and its agents exist) |

Save. On the first run, approve the prompts to let the pipeline use the service connection, variable group, environment and pool.

**You should see:** a manual run with nothing ticked: Validate green, every other stage skipped.

## 5. Agents inside the i2 VNet (Managed DevOps Pool)

Key Vault, ACR and AKS are private, so the secrets, workload and sanity stages need agents inside the i2 VNet. Use a **Managed DevOps Pool** in the subnet the infrastructure creates for it, **`snet-i2-agents`** (already delegated to `Microsoft.DevOpsInfrastructure/pools`). Microsoft manages the VMs, image and agent software; there is no VM, SSH key or PAT, and it scales to zero when idle.

Create it **once, after the first Infra run** (runbook step 5), in the portal. It registers in Azure DevOps as you, so it only needs the Azure DevOps rights you already use to create pools.

1. **Resource providers** (once per subscription), in Cloud Shell:
   ```bash
   az provider register --subscription <subscription id> -n Microsoft.DevOpsInfrastructure
   az provider register --subscription <subscription id> -n Microsoft.DevCenter
   ```
2. **Portal → Managed DevOps Pools → Create:**
   - **Resource group:** `rg-i2-<env>-001`; **Dev Center project:** create new (for example `dcp-i2-<env>-001`)
   - **Name:** the same as `VNET_AGENT_POOL` in the variable group (step 2), for example `mdp-i2-<env>`
   - **Azure DevOps organisation and project:** this pipeline's
   - **Image:** Azure Pipelines `ubuntu-22.04`; **Maximum agents:** 1; **Agent state:** stateless
   - **Networking:** bring your own subnet → `vnet-i2-<env>-001` / `snet-i2-agents`
3. **Azure DevOps → Project settings → Agent pools → the new pool → Security:** allow this pipeline to use it (or approve the prompt on the first run).

**You should see:** Project settings → Agent pools lists the pool. Its agents appear only while a job is running.

**Automate it instead (optional):** set `CREATE_VNET_AGENT_POOL` = `true` in the variable group and the Infra run creates the pool itself. That needs the service connection's identity added as a user in the Azure DevOps **organisation** with **Administrator** on agent pools, which requires organisation admin rights.

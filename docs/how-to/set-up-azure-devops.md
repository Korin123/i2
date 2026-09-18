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
| `VNET_AGENT_POOL` | agent pool of the self-hosted agent in the i2 VNet (step 5). The secrets, workload and sanity stages run on it |
| `ADO_AGENT_PAT` | **secret** (lock icon): PAT with Agent Pools (Read & manage), registers the agent VM (step 5) |

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

## 5. Self-hosted agent inside the i2 VNet

Key Vault, ACR and AKS are private, so the secrets, workload and sanity stages run on a self-hosted agent VM in `snet-i2-agents`. The pipeline's **Agent** option deploys it (`bicep/agent.bicep`).

1. **Agent pool:** Project settings → Agent pools → **Add pool** → Self-hosted, name it as `VNET_AGENT_POOL` (step 2), grant access to all pipelines.
2. **PAT:** User settings → Personal access tokens → New token, scope **Agent Pools (Read & manage)**. Add it to the variable group as `ADO_AGENT_PAT` and click the **lock** to make it secret.
3. **Run the pipeline** with **Agent** ticked (after Infra has run once).

**You should see:** the agent `vm-i2-agent-<env>-001` **Online** in the pool within a few minutes.

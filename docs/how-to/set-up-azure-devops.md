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
| `VNET_AGENT_POOL` | name of the in-VNet agent pool the Infra run creates (step 5), e.g. `mdp-i2-alpha`. The secrets, workload and sanity stages run on it |
| `DEVOPS_INFRA_SP_OBJECT_ID` | only if step 5 says so |

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

Key Vault, ACR and AKS are private, so the secrets, workload and sanity stages need agents inside the i2 VNet. The **Infra** stage creates them: a **Managed DevOps Pool** in `snet-i2-agents`. Microsoft manages the VMs, image and agent software; there is no VM, SSH key or PAT to look after, and it scales to zero when idle.

It is named by `VNET_AGENT_POOL` in the variable group (step 2). The Azure DevOps organisation and project come from the pipeline run itself. Leave `VNET_AGENT_POOL` unset to skip it and use an agent pool you manage yourself.

**Once per organisation, before the first Infra run with `VNET_AGENT_POOL` set:** the pipeline's identity creates the agent pool in Azure DevOps, so it needs permission to.
1. **Organization settings → Users → Add users:** search for the service connection's app registration (step 1; **Manage App registration** on the service connection shows its name). Access level **Basic**, add to this project.
2. **Organization settings → Agent pools → Security:** add that same identity with role **Administrator**.

**Automatic, the first time:** the Infra run registers the `Microsoft.DevOpsInfrastructure` and `Microsoft.DevCenter` resource providers if needed, and looks up Microsoft's `DevOpsInfrastructure` service principal to let it place agents in the VNet. If that lookup fails (the service connection cannot read Entra ID), find it yourself and add it to the variable group as `DEVOPS_INFRA_SP_OBJECT_ID`:
```bash
az ad sp show --id 31687f79-5e43-4c1e-8c63-d9f4bff5cf8b --query id -o tsv
```

**You should see:** after an Infra run, **Project settings → Agent pools** lists `VNET_AGENT_POOL`; its agents appear only while a job is running.

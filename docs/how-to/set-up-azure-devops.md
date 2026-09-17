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

Resource names are not needed: the pipeline reads them from the infrastructure deployment.

## 3. Environment (approvals)

**Where:** Pipelines → Environments → **New environment**.
**Do:** name it `i2-<env>`, resource **None**. Optionally: ⋮ → Approvals and checks → **Approvals**, add who must approve infrastructure and workload deployments.

## 4. Pipeline

**Where:** Pipelines → **New pipeline** → your repository → **Existing Azure Pipelines YAML file** → `/pipelines/azure-pipelines.yml`.
**Do:** before saving, edit the defaults of the four **Setup** parameters at the top of the file (or commit the change):

| Parameter | Set default to |
|---|---|
| `environment` | `<env>` |
| `serviceConnection` | the name from step 1 |
| `vnetAgentPool` | the pool you create in step 5 |
| `infraOnMicrosoftHosted` | `true` until the step 5 agent exists, then `false` if you prefer |

Save. On the first run, approve the prompts to let the pipeline use the service connection, variable group, environment and pool.

**You should see:** a manual run with nothing ticked: Validate green, every other stage skipped.

## 5. Self-hosted agent on the i2 VNet

Key Vault, ACR and AKS are private, so the secrets, workload and sanity stages need an agent that can reach the i2 VNet. The infrastructure deployment creates the subnet **`snet-i2-agents`** for it (output `agentsSubnetId`). Create the agent **after** the infrastructure exists (runbook step 5).

**5a. Agent pool.** Project settings → Agent pools → **Add pool** → Self-hosted, name it (for example `i2-vnet-agents`), grant access to all pipelines.

**5b. Personal access token for registration.** User settings → Personal access tokens → New token, scope **Agent Pools (read, manage)**, short expiry. Keep it for 5c; it is only used to register the agent.

**5c. Agent VM** (Azure CLI, in the dev container). Replace the values in `<>`:
```bash
RG=<resource group from the infra run>
SUBNET_ID=$(az deployment sub show -n i2-infra-<env> --query properties.outputs.agentsSubnetId.value -o tsv)
az vm create -g "$RG" -n vm-i2-agent-<env>-001 --image Ubuntu2204 --size Standard_D2s_v5 \
  --subnet "$SUBNET_ID" --public-ip-address "" --nsg "" \
  --admin-username azureuser --generate-ssh-keys --assign-identity
```
The VM has no public IP and no inbound access. With `networkMode = 'new'` it reaches the internet through the NAT gateway on `snet-i2-agents`; with an existing VNet it needs your normal outbound route. Install the agent without logging in to the VM (Run Command):
```bash
az vm run-command invoke -g "$RG" -n vm-i2-agent-<env>-001 --command-id RunShellScript --scripts '
  set -e
  apt-get update -y && apt-get install -y curl jq git unzip docker.io
  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  useradd -m -s /bin/bash azagent && usermod -aG docker azagent
  cd /home/azagent && mkdir agent && cd agent
  curl -fsSL -o agent.tgz https://download.agent.dev.azure.com/agent/4.255.0/vsts-agent-linux-x64-4.255.0.tar.gz
  tar -xzf agent.tgz && chown -R azagent: /home/azagent
  sudo -u azagent ./config.sh --unattended --url https://dev.azure.com/<organisation> \
    --auth pat --token <PAT from 5b> --pool <pool from 5a> --agent vm-i2-agent-<env>-001 --acceptTeeEula
  ./svc.sh install azagent && ./svc.sh start'
```
Check the current agent version on the [Azure Pipelines agent releases page](https://github.com/microsoft/azure-pipelines-agent/releases) and adjust the download URL if needed.

**You should see:** the agent **Online** in the pool. Then revoke the token from 5b.

**Alternatives:** an existing self-hosted agent that already has network access to the i2 VNet (peering or VPN), or [Managed DevOps Pools](https://learn.microsoft.com/azure/devops/managed-devops-pools/) with VNet injection into `snet-i2-agents`.

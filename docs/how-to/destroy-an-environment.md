# Destroy an environment

Deletes everything the infrastructure deployment created for one environment, so you can deploy it again from scratch (for example after the SQL MI collation changes).

**Safe to recreate with the same names only if** the parameter file has `keyVaultPurgeProtection = false` (as `alpha` does). With purge protection on, a deleted Key Vault keeps its name for 90 days and the redeploy fails.

## What it deletes

The resource group `rg-i2-<env>-001` and everything in it: VNet, NAT gateway, private DNS zones, Key Vault (then purged), ACR and its images, AKS (and its `MC_` node group), SQL Managed Instance and its databases, storage, monitoring, and the Managed DevOps Pool (the in-VNet agents). It also removes the subscription deployment record `i2-infra-<env>`.

It does **not** touch Azure DevOps (service connection, variable group, pipeline) or your dev container.

## Steps

**Where:** the dev container terminal. Your `az login` account needs permission to delete the resource group (Contributor or Owner).

1. Check you are pointed at the right environment:
   ```bash
   cat scripts/env.sh
   ```
   **You should see:** the subscription and `I2_ENV` you mean to destroy.
2. Destroy it:
   ```bash
   ./scripts/90-destroy-infra.sh
   ```
   It shows the subscription and resource group, then asks you to **type the environment name** (for example `alpha`). Anything else cancels.
   **You should see:** `Deleting resource group ...`, then after a while (the SQL Managed Instance can take an hour or more) `Purging deleted Key Vault ...` and `Environment 'alpha' destroyed.`
3. In Azure DevOps: Project settings → Agent pools: if the Managed DevOps Pool (`VNET_AGENT_POOL`) is still listed, delete it. The next Infra run recreates it.

If it stops part-way (for example a timeout while the SQL MI is deleting), run it again: it carries on from where it got to.

## Recreate

Runbook [step 5](runbook.md#5-create-the-infrastructure) (infra, including the in-VNet agent pool), [7](runbook.md#7-secrets-and-certificates) (secrets), then [push the images](build-and-push-images.md#part-b-push-to-azure-after-the-infrastructure-exists) again (the registry is new and empty) and deploy the workload (steps 11-13).

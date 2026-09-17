# How-to guides

Short, task-focused guides. For the full deployment order and what each step does, see [`../deployment.md`](../deployment.md).

| I want to... | Guide |
|---|---|
| Set up my machine to build and deploy | [set-up-the-dev-container.md](set-up-the-dev-container.md) |
| Build the images and push them to ACR | [build-and-push-images.md](build-and-push-images.md) |
| **Deploy an environment start to finish (start here)** | [runbook.md](runbook.md) |
| Set up Azure DevOps (service connection, variable group, agent) | [set-up-azure-devops.md](set-up-azure-devops.md) |
| Deploy an environment for the first time (scripts only, no pipeline) | [first-deployment.md](first-deployment.md) |
| Deploy from Azure DevOps, safely | [deploy-with-the-pipeline.md](deploy-with-the-pipeline.md) |
| Fix something and redeploy just that part | [fix-and-redeploy.md](fix-and-redeploy.md) |
| Re-run a Solr or database init Job | [rerun-init-jobs.md](rerun-init-jobs.md) |
| Reissue certificates or change secrets | [certificates-and-secrets.md](certificates-and-secrets.md) |
| Work out why a sanity check failed | [troubleshoot-sanity-failures.md](troubleshoot-sanity-failures.md) |

All scripts read a few settings from `scripts/env.sh` (copy `scripts/env.example`: subscription, region, versions). Azure resource names are never typed: Bicep creates them and the scripts read them from the infra deployment. Run scripts from the repo root.

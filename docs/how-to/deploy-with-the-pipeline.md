# Deploy with the Azure DevOps pipeline

The pipeline is built for controlled deployment:

- **Nothing runs automatically.** Pushes and pull requests start no runs.
- **Deploys run only when you click Run pipeline**, and only the stages you tick.
- **A failed stage stops everything after it.** Unticked stages are skipped without blocking later ones.
- Deploy stages use the `i2-<environment>` Azure DevOps environment, so any approvals set on it apply.
- One-time setup (service connection, variable group, agent pool, the Setup parameters): [set-up-azure-devops.md](set-up-azure-devops.md). Order of runs: [runbook.md](runbook.md).

## Run it

Pipelines → i2 → **Run pipeline**, set the options, then **Run**.

| Option | Default | Use it to |
|---|---|---|
| Infra (Bicep, incl. SQL MI) | `skip` | `preview`: show what would change (what-if), change nothing. `deploy`: create or update the infrastructure |
| Secrets: seed missing secrets + certs | off | first deployment, or after adding a secret |
| Secrets: reissue these certs | empty | e.g. `solr zookeeper` after a certificate change |
| Workload (Kubernetes on AKS) | `skip` | `preview`: show what would change (kubectl diff). `deploy`: apply it |
| Workload: components | `all` | redeploy only what you fixed, e.g. `liberty`, `solr collections`, or `database` to resume a failed db-init |
| Verify: run sanity checks | off | confirm the result |

## Common runs

- **Preview everything:** Infra `preview`, Workload `preview`, Sanity off.
- **Redeploy Liberty after a new image:** Workload `deploy`, components `liberty`.
- **Just check health:** Infra and Workload `skip`, tick only Sanity.

The deploy stages first check that the images they need are in ACR. If one is missing, build and push it ([build-and-push-images.md](build-and-push-images.md)) and run again.

Set approvals on the `i2-alpha` environment (Pipelines → Environments → i2-alpha → Approvals and checks) if a second person should confirm each deploy.

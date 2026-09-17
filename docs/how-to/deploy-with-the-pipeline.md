# Deploy with the Azure DevOps pipeline

The pipeline is built for controlled deployment:

- **A push to `main` deploys nothing.** It only validates (Bicep build, script syntax).
- **Deploys run only when you click Run pipeline**, and only the stages you tick.
- **A failed stage stops everything after it.** Unticked stages are skipped without blocking later ones.
- Deploy stages use the `i2-alpha` environment, so any approvals set on that environment apply.

## Run it

Pipelines → i2 → **Run pipeline**, set the options, then **Run**.

| Option | Default | Use it to |
|---|---|---|
| Infra: deploy Bicep | off | apply infrastructure changes |
| Infra: preview only (what-if) | **on** | see what would change; untick to actually deploy |
| Secrets: seed missing secrets + certs | off | first deployment, or after adding a secret |
| Secrets: reissue these certs | empty | e.g. `solr zookeeper` after a certificate change |
| Workload: deploy to AKS | on | apply Kubernetes changes |
| Workload: components | `all` | redeploy only what you fixed, e.g. `liberty`, `solr collections`, or `database` to resume a failed db-init |
| Workload: preview only (kubectl diff) | off | see what would change without applying it |
| Verify: run sanity checks | on | confirm the result |

## Common runs

- **Preview everything:** Infra on with preview on, Workload on with preview on, Sanity off.
- **Redeploy Liberty after a new image:** Workload on, components `liberty`.
- **Just check health:** untick everything except Sanity.

The deploy stages first check that the images they need are in ACR. If one is missing, build and push it ([build-and-push-images.md](build-and-push-images.md)) and run again.

Set approvals on the `i2-alpha` environment (Pipelines → Environments → i2-alpha → Approvals and checks) if a second person should confirm each deploy.

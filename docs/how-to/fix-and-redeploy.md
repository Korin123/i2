# Fix something and redeploy just that part

1. **Make the fix** on a branch and open a pull request (see `CONTRIBUTING.md`).
2. **If the fix changes an image** (i2 config, schema, or anything under `images/`), rebuild and push: [build-and-push-images.md](build-and-push-images.md).
3. **Preview** the change:
   ```bash
   DRY_RUN=true scripts/40-deploy-workload.sh <component>
   ```
4. **Apply** it:
   ```bash
   scripts/40-deploy-workload.sh <component>
   ```
5. **Verify**: `scripts/60-sanity.sh`

In the pipeline, set **Workload: components** to the same names.

## Which component?

| You changed | Redeploy |
|---|---|
| `k8s/liberty-statefulset.yaml` or the Liberty image | `liberty` |
| `k8s/solr-statefulset.yaml` or the Solr image | `solr` |
| `k8s/zookeeper-statefulset.yaml` | `zookeeper` |
| `security.json`, Solr configsets, `images/solr-init` | `solr-init collections` |
| `k8s/secretproviderclass.yaml`, `k8s/services.yaml`, `k8s/namespace.yaml` | `base`, then restart the pods that use it |
| `k8s/connectors-deployment.yaml` / `k8s/ingress.yaml` | `connectors` / `ingress` |
| `images/db-init` or the Information Store scripts | `database` (see [rerun-init-jobs.md](rerun-init-jobs.md)) |
| System match rules in the i2 config, `images/i2-tools` | `match-rules` |
| `bicep/` | `WHAT_IF=true scripts/10-deploy-infra.sh`, then run it without `WHAT_IF` |

Components always run in the safe order (ZooKeeper, Solr setup, Solr, collections, Liberty), whatever order you type them in.

**Restart pods without changing anything**, for example to pick up a new secret:
```bash
kubectl rollout restart statefulset/solr -n i2analyze
```
Use `statefulset/zookeeper` or `statefulset/liberty` for the others.

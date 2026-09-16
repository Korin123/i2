# Troubleshoot a sanity check failure

Run `scripts/60-sanity.sh`. It runs every check and lists all failures at the end.

**Fix failures from the top down.** Later checks often fail only because an earlier one did.

| Failing check | Look at | Usual fix |
|---|---|---|
| `statefulset/... ready` | `kubectl get pods -n i2analyze`, then `kubectl describe pod <pod> -n i2analyze` | Image missing in ACR, secret not mounted, or not enough nodes. Fix, then redeploy that component |
| `job ... succeeded` | `kubectl logs job/<job> -n i2analyze` | See [rerun-init-jobs.md](rerun-init-jobs.md) |
| `solr pods on the i2solr node pool` | `kubectl get nodes -L workload` | Deploy the infra so the `i2solr` pool exists |
| `zookeeper-N serving`, `one leader` | `kubectl logs zookeeper-N -n i2analyze` | Usually certificates or DNS: check the zookeeper cert covers `*.zookeeper-headless` |
| `solr CLUSTERSTATUS over TLS with BasicAuth` | `kubectl logs solr-0 -n i2analyze` | HTTP 401: re-run Solr setup (`solr-init`). TLS error: reissue the `solr` cert |
| `solr nodes registered by pod FQDN` | the `live_nodes` in the message | `SOLR_HOST` not set: redeploy `solr` |
| `collection ... exists`, `replicas active` | Solr pod logs | Missing: redeploy `collections`. Not active: check the Solr logs |
| `solr accepts the liberty application user` | Liberty and Solr logs | The Liberty password in Key Vault does not match `security.json`. See [certificates-and-secrets.md](certificates-and-secrets.md) |
| `liberty reaches <MI>:1433` | `kubectl exec liberty-0 -n i2analyze -- getent hosts <MI FQDN>`, NSGs, hub firewall/UDRs | DNS: the VNet's DNS must resolve `*.database.windows.net`. Network: allow the AKS subnet to reach the MI subnet on 1433 |
| `ISTORE initialised` | `kubectl logs job/i2-db-init -n i2analyze` | Fix the error, then re-run `scripts/50-bootstrap-data.sh`; it resumes |
| `/opal/api/v1/health/live` | `kubectl logs <liberty pod> -n i2analyze` | Liberty cannot reach Solr, ZooKeeper or the database: fix those checks first. TLS/PKIX errors to the database: the `ssl-additional-trust-certificates` secret is missing or lacks the MI's root CA (`REFRESH_TRUST_CERTS=true scripts/20-seed-secrets-pki.sh`, restart Liberty) |

After fixing, redeploy only what changed ([fix-and-redeploy.md](fix-and-redeploy.md)) and run the sanity checks again.

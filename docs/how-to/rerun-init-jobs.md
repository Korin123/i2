# Re-run a Solr, database or match rules Job

All four Jobs are safe to re-run.

## Solr setup (`i2-solr-zk-init`)

Creates the ZooKeeper root, switches Solr to HTTPS, and uploads `security.json` and the configsets. Re-run it after changing Solr passwords, `security.json` or the schema:
```bash
scripts/40-deploy-workload.sh solr-init
kubectl rollout restart statefulset/solr -n i2analyze
```

## Solr collections (`i2-solr-collections`)

Adds Solr's affinity placement plugin if missing, then creates any of the 8 collections that are missing, each with 1 shard and 2 replicas on different Solr nodes (ADT's pre-prod layout). Existing collections are left alone, so a collection created with a different layout keeps it until you delete and recreate it.
```bash
scripts/40-deploy-workload.sh collections
```
Changing the schema of an existing collection needs a new configset upload (`solr-init`) and then a collection reload or rebuild. Plan that with i2.

## Information Store (`i2-db-init`)

Each step is recorded on the ISTORE database when it succeeds. A re-run skips completed steps and starts from the one that failed.
```bash
scripts/50-bootstrap-data.sh
```

See which steps are done:
```sql
SELECT name FROM ISTORE.sys.extended_properties WHERE class = 0 AND name LIKE 'i2aks.%';
```

**Force one step to run again** (only when you know it is safe to repeat), for example the dynamic scripts:
```sql
USE ISTORE; EXEC sp_dropextendedproperty @name = N'i2aks.dynamic_scripts';
```

## System match rules (`i2-match-rules`)

Uploads the system match rules from the i2 config, waits until the standby match index is rebuilt, then makes it live (ADT's `update_match_rules`). Run it after Liberty is up, and again after changing the match rules. Changed rules need a new `i2-tools` image first ([build-and-push-images.md](build-and-push-images.md)).
```bash
scripts/40-deploy-workload.sh match-rules
```
The rebuild reindexes the standby match index, so it takes longer as data grows (the Job waits up to 30 minutes).

## Read a Job's output
```bash
kubectl logs job/i2-db-init -n i2analyze          # or i2-solr-zk-init, i2-solr-collections, i2-match-rules
kubectl describe job/i2-db-init -n i2analyze      # if the pod never started (image, secrets)
```

# Build and push the images

Images are built locally with ADT (i2's recommendation), then pushed to ACR. The pipeline never builds them; it only checks they exist.

**Run in:** the dev container ([set up](set-up-the-dev-container.md)), signed in with `az login`.

1. Link the shared config and build the configured Liberty image:
   ```bash
   manage-environment -t link -y
   deploy -c base-demo -t package
   ```
2. Generate the Information Store scripts. The config must set `DB_DIALECT=sqlserver` in `adt/configs/base-demo/utils/variables.conf`.
   ```bash
   deploy -c base-demo -t generate-db-scripts -y
   ```
3. Build the init images and push everything to ACR:
   ```bash
   scripts/30-build-images.sh
   ```

This pushes, tagged with `I2_VERSION`:

| Image | What it is |
|---|---|
| `liberty_configured_redhat:base-demo-<ver>` | i2 Analyze with the config baked in |
| `solr_redhat:<ver>` | Solr with i2's plugin jars |
| `i2-solr-init:<ver>` | Solr cluster setup and collection configsets |
| `i2-db-init:<ver>` | Information Store setup scripts |

**Changed the i2 config or schema?** Repeat all three steps, then redeploy the affected parts ([fix-and-redeploy.md](fix-and-redeploy.md)).

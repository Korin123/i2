# config

The i2 Analyze shared configuration (schema, security schema, fragments) lives here.
For the first pass use i2's `base-demo` example configuration to prove the pipeline
end to end, then replace it with the DFN schema.

The i2 distribution and images are obtained separately under the i2 licence and are
NOT committed (see `.gitignore`). On the build box:

1. Open this repo in the **i2 - ADT + Azure** dev container (from a WSL 2 clone), run
   `scripts/05-install-adt.sh` (ADT pinned to ADT_VERSION, into git-ignored `adt/`), then put
   the minimal toolkit at `adt/pre-reqs/i2analyzeMinimal.tar.gz`.
   ADT docs: https://i2group.github.io/analyze-deployment-tooling/
2. Place / link the `base-demo` shared config, then `manage-environment -t link -y`.
3. `deploy -c base-demo -t package` builds the configured Liberty image; `scripts/30-build-images.sh`
   then generates the Solr configsets from it and pushes Liberty, `solr_redhat` and `i2-solr-init`.

`adt/` (including `adt/pre-reqs/`) and `config/distribution/` are git-ignored.

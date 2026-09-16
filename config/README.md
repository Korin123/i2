# config

The i2 Analyze shared configuration (schema, security schema, fragments) lives here.
For the first pass use i2's `base-demo` example configuration to prove the pipeline
end to end, then replace it with the DFN schema.

The i2 distribution and images are obtained separately under the i2 licence and are
NOT committed (see `.gitignore`). On the build box:

1. In WSL 2, get https://github.com/i2group/analyze-deployment-tooling, put the minimal
   toolkit in `pre-reqs/i2analyzeMinimal.tar.gz`, run `./bootstrap -o <ADT version>`, then
   "Dev Containers: Open Folder in Container" on that directory (ADT's own dev container,
   host Docker socket). Docs: https://i2group.github.io/analyze-deployment-tooling/
2. Place / link the `base-demo` shared config, then `manage-environment -t link -y`.
3. `deploy -c base-demo -t package` builds the configured Liberty image (scripts/30).

`config/distribution/` is git-ignored - put the distribution tarball there locally.

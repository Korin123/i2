# config

The i2 Analyze shared configuration (schema, security schema, fragments) lives here.
For the first pass use i2's `base-demo` example configuration to prove the pipeline
end to end, then replace it with the DFN schema.

The i2 distribution and images are obtained separately under the i2 licence and are
NOT committed (see `.gitignore`). On the build box:

1. Clone https://github.com/i2group/analyze-deployment-tooling and run `bootstrap`
   (pulls `i2eng-analyze-containers-client:<version>`).
2. Place / link the `base-demo` shared config, then `manage-environment -t link -y`.
3. `deploy -c base-demo -t package` builds the configured Liberty image (scripts/30).

`config/distribution/` is git-ignored - put the distribution tarball there locally.

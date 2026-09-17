# Extra root certificates

Only needed on a network that inspects secure traffic (a corporate proxy), which shows up in the dev container as errors like `self-signed certificate in certificate chain` or `CERTIFICATE_VERIFY_FAILED`.

Put your organisation's root certificate here as a `.crt`, `.cer` or `.pem` file (Base-64/PEM format). Files in this folder are git-ignored. The dev container trusts them when it is created; to apply one to a running container, run `bash .devcontainer/trust-certs.sh`.

Step-by-step: [docs/how-to/set-up-the-dev-container.md](../../docs/how-to/set-up-the-dev-container.md#certificate-errors-corporate-network).

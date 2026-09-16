# Notice

This repository contains infrastructure-as-code, Kubernetes manifests, pipelines and
documentation for deploying i2 Analyze on Microsoft Azure. It is shared with i2 Group
for technical collaboration.

It contains NO i2-licensed software. The i2 Analyze distribution, the i2 container
images, and the analyze-deployment-tooling client image are obtained separately under
the customer's i2 licence and are never committed here (see `.gitignore`). Acceptance of
the i2 licence agreement is by configuration (`LIC_AGREEMENT=ACCEPT` / `LICENSE=ACCEPT`),
not a key file.

No secrets, credentials, or environment-specific identifiers are committed. Subscription,
tenant and object IDs are supplied at deploy time via pipeline variables and parameter
files kept outside version control.

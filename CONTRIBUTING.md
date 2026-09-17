# Contributing

This repository deploys i2 Analyze on Azure. It is the Azure counterpart to i2's `ansible-i2a`
(AWS CDK + Ansible) reference, and is developed in collaboration with i2 Group so that any
organisation can reuse it.

## How we work

- Work on a branch, open a pull request, get one review.
- Platform owners review the Azure layer: `bicep/`, `pipelines/`, `scripts/`.
- i2 review is most valuable on the application contract: `k8s/`, `images/`, `config/`, the
  secret and PKI set, the Solr collections, and the init Jobs. These must match the i2
  container contract (ADT) exactly.
- Keep the mapping to `ansible-i2a` and ADT current: if a behaviour changes upstream, note the
  Azure equivalent in `docs/aws-to-azure-mapping.md` and `docs/adt-familiarisation.md`.

## Ground rules

- Never commit secrets, certificates, kubeconfigs, or the i2 distribution/toolkit.
- Keep it generic: no organisation-specific names, IDs or tags in committed defaults. Put an
  organisation's values in its own `bicep/parameters/<env>.bicepparam`, its Azure DevOps
  variable group, and the pipeline's Setup parameters.
- Deploy logic lives in `scripts/` so it runs locally and from any CI. Keep CI files thin.

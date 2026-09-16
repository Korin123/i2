# Contributing

This repo is a collaboration between the DFN platform team and i2 Group to stand up
i2 Analyze on Azure. It is the Azure counterpart to i2's `ansible-i2a` (AWS CDK + Ansible)
reference.

## How we work

- `main` is protected. Work on a branch, open a pull request, get one review.
- The DFN team owns the Azure platform layer (`bicep/`, `pipelines/`, `scripts/`).
- i2 review is most valuable on the application contract: `k8s/`, `config/`, the secret
  and PKI set, the Solr collections, and the db_init / solr_collections Jobs. These must
  match the i2 container contract exactly.
- Keep the mapping to `ansible-i2a` current: if a role behaviour changes upstream, note the
  Azure equivalent in `docs/aws-to-azure-mapping.md`.

## Ground rules

- Never commit secrets, certificates, kubeconfigs, or the i2 distribution.
- No environment-specific IDs in committed files. Use parameters and pipeline variables.
- Deploy logic lives in `scripts/` so it runs locally and from any CI. Keep CI files thin.

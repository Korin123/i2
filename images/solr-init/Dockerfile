# i2-solr-init: ADT's solr_client_redhat image + the Solr configsets generated from our
# i2 config (scripts/30-build-images.sh) + the cluster init script run by the AKS Jobs.
# Entrypoint is inherited (certs/digest -> SOLR_ZK_CREDS_AND_ACLS, then runs the command).
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY --chown=0:0 generated_config /opt/configuration/solr/generated_config
COPY --chown=0:0 --chmod=755 solr-init.sh /opt/solr-init.sh

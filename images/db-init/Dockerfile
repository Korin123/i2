# i2-db-init: ADT's sqlserver_client_redhat image (sqlcmd + ADT db-scripts + i2 tools) with
# the Information Store scripts generated from our config (`deploy -t generate-db-scripts`,
# copied in by scripts/30-build-images.sh) and the init script run by the AKS Job.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY --chown=mssql:0 generated /opt/databaseScripts/generated
COPY --chown=mssql:0 --chmod=755 db-init.sh /opt/db-init.sh

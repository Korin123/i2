#!/usr/bin/env bash
# Build and push images with ADT locally (i2-recommended). Runs in the dev container
# with ADT installed (scripts/05-install-adt.sh) and the licensed toolkit in
# adt/pre-reqs, which makes ADT build its core images (solr_redhat, solr_client_redhat,
# i2a_tools_redhat, sqlserver_client_redhat, ...). Builds the configured Liberty image and the
# Solr and database init images, then pushes to ACR.
# Reference: https://github.com/i2group/analyze-deployment-tooling
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${I2_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"
root="$(cd "$(dirname "$0")/.." && pwd)"
ADT_DIR="${ANALYZE_CONTAINERS_ROOT_DIR:-$root/adt}"
CONFIG_NAME="${CONFIG_NAME:-base-demo}"

log "1) Mirror the i2 base images used as-is into ACR (server-side copy, no local Docker)"
for img in \
  i2group/i2eng-zookeeper:3.9 ; do
  az acr import --name "$ACR" --source "docker.io/${img}" --image "${img}" --force || \
    log "import ${img} failed - if DockerHub rate-limits, add --username/--password or pull/tag/push locally"
done

log "2) Build the configured Liberty image with ADT (local Docker + distribution)"
cat <<NOTE
   In the dev container, with ADT installed and the toolkit in adt/pre-reqs:
     manage-environment -t link -y                 # link the ${CONFIG_NAME} shared config
     deploy -c ${CONFIG_NAME} -t package           # builds liberty_configured_redhat:${CONFIG_NAME}-<ver>
     deploy -c ${CONFIG_NAME} -t generate-db-scripts -y   # generates the ISTORE SQL (used by db_init)
   Core images missing (solr_redhat etc.)? run: manage-environment -t update
NOTE
for img in "liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}" "solr_redhat:${I2_VERSION}" \
           "solr_client_redhat:${I2_VERSION}" "i2a_tools_redhat:${I2_VERSION}" \
           "sqlserver_client_redhat:${I2_VERSION}"; do
  docker image inspect "$img" >/dev/null 2>&1 || { echo "missing local image $img - see above" >&2; exit 1; }
done

log "3) Generate the Solr configsets from the assembled config (ADT configure_solr_collections)"
# deploy -t package assembles the full configuration in adt/.tmp/.configuration
cfg="${ADT_DIR}/.tmp/.configuration"
[ -d "$cfg/solr" ] || { echo "no assembled config at $cfg - run deploy -c ${CONFIG_NAME} -t package first" >&2; exit 1; }
rm -rf "$cfg/solr/generated_config"
docker run --rm \
  -e LIC_AGREEMENT=ACCEPT -e CONFIG_DIR=/opt/configuration \
  -e "USER_ID=$(id -u)" -e "GROUP_ID=$(id -g)" \
  -v "$cfg:/opt/configuration" \
  "i2a_tools_redhat:${I2_VERSION}" /opt/i2-tools/scripts/generateSolrSchemas.sh
rm -rf "$root/images/solr-init/generated_config"
cp -r "$cfg/solr/generated_config" "$root/images/solr-init/generated_config"

log "4) Build the Solr init image (solr_client_redhat + configsets + init script)"
docker build --build-arg "BASE_IMAGE=solr_client_redhat:${I2_VERSION}" \
  -t "${ACR_LS}/i2group/i2-solr-init:${I2_VERSION}" "$root/images/solr-init"

log "5) Build the database init image (sqlserver_client_redhat + generated Information Store scripts)"
# deploy -t generate-db-scripts writes to adt/configs/<config>/database-scripts/generated;
# the config must set DB_DIALECT=sqlserver (configs/<config>/utils/variables.conf)
gen="${ADT_DIR}/configs/${CONFIG_NAME}/database-scripts/generated"
[ -d "$gen/static" ] || { echo "no generated DB scripts at $gen - run deploy -c ${CONFIG_NAME} -t generate-db-scripts first" >&2; exit 1; }
rm -rf "$root/images/db-init/generated"
cp -r "$gen" "$root/images/db-init/generated"
docker build --build-arg "BASE_IMAGE=sqlserver_client_redhat:${I2_VERSION}" \
  -t "${ACR_LS}/i2group/i2-db-init:${I2_VERSION}" "$root/images/db-init"

log "6) Tag + push to ACR"
az acr login --name "$ACR"
push() { # local-image  acr-repo:tag
  docker tag "$1" "${ACR_LS}/i2group/$2"
  docker push "${ACR_LS}/i2group/$2"
}
push "liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}" "liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}"
push "solr_redhat:${I2_VERSION}" "solr_redhat:${I2_VERSION}"
docker push "${ACR_LS}/i2group/i2-solr-init:${I2_VERSION}"
docker push "${ACR_LS}/i2group/i2-db-init:${I2_VERSION}"
log "Images in ACR. AKS pulls only from ${ACR_LS} over its private endpoint."

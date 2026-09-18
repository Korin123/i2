#!/usr/bin/env bash
# Build and push images with ADT locally (i2-recommended). Runs in the dev container
# with ADT installed (scripts/05-install-adt.sh) and the licensed toolkit in
# adt/pre-reqs, which makes ADT build its core images (solr_redhat, solr_client_redhat,
# i2a_tools_redhat, sqlserver_client_redhat, ...). Builds the Solr, database and tools init
# images from the ADT build, then pushes everything to ACR.
#   scripts/30-build-images.sh build    build only - no Azure needed
#   scripts/30-build-images.sh push     push to ACR - needs the infra deployed (scripts/10)
#   scripts/30-build-images.sh          both
# Reference: https://github.com/i2group/analyze-deployment-tooling
source "$(dirname "$0")/00-common.sh"
: "${I2_VERSION:?}"
root="$(cd "$(dirname "$0")/.." && pwd)"
ADT_DIR="${ANALYZE_CONTAINERS_ROOT_DIR:-$root/adt}"
CONFIG_NAME="${CONFIG_NAME:-base-demo}"
MODE="${1:-all}"
[[ "$MODE" =~ ^(build|push|all)$ ]] || { echo "usage: $0 [build|push]" >&2; exit 2; }

# local image -> repository in ACR (under i2group/)
IMAGES=(
  "liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}"
  "solr_redhat:${I2_VERSION}"
  "i2group/i2-solr-init:${I2_VERSION}"
  "i2group/i2-db-init:${I2_VERSION}"
  "i2group/i2-tools:${I2_VERSION}"
)

if [[ "$MODE" != push ]]; then
  log "1) Check the ADT build"
  cat <<NOTE
   In the dev container, with ADT installed and the toolkit in adt/pre-reqs:
     cp -r adt/templates/config-development adt/configs/${CONFIG_NAME}   # once, then in its utils/variables.conf:
                                                          #   DEPLOYMENT_PATTERN="istore" DB_DIALECT="sqlserver"
     deploy -c ${CONFIG_NAME} -t package                  # builds liberty_configured_redhat:${CONFIG_NAME}-<ver>
     deploy -c ${CONFIG_NAME} -t generate-db-scripts -y   # generates the ISTORE SQL (used by db-init)
   Core images missing (solr_redhat etc.)? run: manage-environment -t update
NOTE
  for img in "liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}" "solr_redhat:${I2_VERSION}" \
             "solr_client_redhat:${I2_VERSION}" "i2a_tools_redhat:${I2_VERSION}" \
             "sqlserver_client_redhat:${I2_VERSION}"; do
    docker image inspect "$img" >/dev/null 2>&1 || { echo "missing local image $img - see above" >&2; exit 1; }
  done

  log "2) Generate the Solr configsets from the assembled config (ADT configure_solr_collections)"
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

  log "3) Build the Solr init image (solr_client_redhat + configsets + init script)"
  docker build --build-arg "BASE_IMAGE=solr_client_redhat:${I2_VERSION}" \
    -t "i2group/i2-solr-init:${I2_VERSION}" "$root/images/solr-init"

  log "4) Build the database init image (sqlserver_client_redhat + generated Information Store scripts)"
  # deploy -t generate-db-scripts writes to adt/configs/<config>/database-scripts/generated;
  # the config must set DB_DIALECT=sqlserver (configs/<config>/utils/variables.conf)
  gen="${ADT_DIR}/configs/${CONFIG_NAME}/database-scripts/generated"
  [ -d "$gen/static" ] || { echo "no generated DB scripts at $gen - run deploy -c ${CONFIG_NAME} -t generate-db-scripts first" >&2; exit 1; }
  rm -rf "$root/images/db-init/generated"
  cp -r "$gen" "$root/images/db-init/generated"
  # The Information Store collation is an i2 config setting (Collation in
  # InfoStoreNamesSQLServer.properties). Bake it in for the Managed Instance fallback,
  # and compare it with the instance collation, which is fixed when the MI is created.
  props="$(find "$cfg" -name InfoStoreNamesSQLServer.properties | head -1)"
  collation="$( [ -n "$props" ] && sed -n 's/^[[:space:]]*Collation[[:space:]]*=[[:space:]]*//p' "$props" | tr -d '[:space:]' | tail -1)"
  printf '%s' "$collation" > "$root/images/db-init/generated/istore-collation"
  mi_collation="$(sed -n "s/^param sqlMiCollation *= *'\([^']*\)'.*/\1/p" "$root/${BICEP_PARAM:-bicep/parameters/alpha.bicepparam}" 2>/dev/null)"
  log "Information Store collation from the i2 config: ${collation:-<not set: instance default>}; MI (bicepparam): ${mi_collation:-<unknown>}"
  if [[ -n "$collation" && -n "$mi_collation" && "$collation" != "$mi_collation" ]]; then
    echo "WARNING: config Collation '$collation' differs from sqlMiCollation '$mi_collation'." >&2
    echo "         Set sqlMiCollation to match BEFORE the Managed Instance is created (it cannot change later)." >&2
  fi
  docker build --build-arg "BASE_IMAGE=sqlserver_client_redhat:${I2_VERSION}" \
    -t "i2group/i2-db-init:${I2_VERSION}" "$root/images/db-init"

  log "5) Build the i2 tools image (i2a_tools_redhat + the assembled config, for the match-rules Job)"
  rm -rf "$root/images/i2-tools/configuration"
  cp -r "$cfg" "$root/images/i2-tools/configuration"
  docker build --build-arg "BASE_IMAGE=i2a_tools_redhat:${I2_VERSION}" \
    -t "i2group/i2-tools:${I2_VERSION}" "$root/images/i2-tools"
  log "Images built locally: ${IMAGES[*]}"
fi

if [[ "$MODE" != build ]]; then
  azure_outputs
  ACR_LS="${ACR}.azurecr.io"

  log "6) Mirror the i2 base images used as-is into ACR (server-side copy, no local Docker)"
  for img in i2group/i2eng-zookeeper:3.9; do
    az acr import --name "$ACR" --source "docker.io/${img}" --image "${img}" --force || \
      log "import ${img} failed - if DockerHub rate-limits, add --username/--password or pull/tag/push locally"
  done

  log "7) Tag + push to ${ACR_LS}"
  az acr login --name "$ACR"
  for img in "${IMAGES[@]}"; do
    docker image inspect "$img" >/dev/null 2>&1 || { echo "missing local image $img - run: $0 build" >&2; exit 1; }
    target="${ACR_LS}/i2group/${img#i2group/}"
    docker tag "$img" "$target"
    docker push "$target"
  done
  log "Images in ACR. AKS pulls only from ${ACR_LS} over its private endpoint."
fi

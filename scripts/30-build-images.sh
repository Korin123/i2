#!/usr/bin/env bash
# Build and push images with ADT locally (i2-recommended). Runs on a build box
# with Docker and the licensed i2 distribution. Mirrors the base images into ACR
# and builds the configured Liberty image with ADT, then pushes to ACR.
# Reference: https://github.com/i2group/analyze-deployment-tooling
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${I2_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"

log "1) Mirror the i2 base images into ACR (server-side copy, no local Docker)"
for img in \
  i2group/i2eng-liberty:ubi-jdk17 \
  i2group/i2eng-solr:9.9 \
  i2group/i2eng-zookeeper:3.9 \
  i2group/i2eng-analyze-containers-client:${ADT_VERSION} ; do
  az acr import --name "$ACR" --source "docker.io/${img}" --image "${img}" --force || \
    log "import ${img} failed - if DockerHub rate-limits, add --username/--password or pull/tag/push locally"
done

log "2) Build the configured Liberty image with ADT (local Docker + distribution)"
cat <<'NOTE'
   On the build box, with the ADT bootstrap run and the base-demo config linked:
     scripts/05-install-adt.sh                     # ADT bootstrap, pulls i2eng-analyze-containers-client
     manage-environment -t link -y                 # link the base-demo shared config
     deploy -c base-demo -t package                # builds liberty_configured_redhat:base-demo-<ver>
     deploy -t generate-db-scripts -y              # generates the ISTORE SQL (used by db_init)
NOTE

log "3) Tag + push the configured Liberty image to ACR"
az acr login --name "$ACR"
docker tag "liberty_configured_redhat:base-demo-${I2_VERSION}" \
           "${ACR_LS}/i2group/liberty_configured_redhat:base-demo-${I2_VERSION}"
docker push "${ACR_LS}/i2group/liberty_configured_redhat:base-demo-${I2_VERSION}"
log "Images in ACR. AKS pulls only from ${ACR_LS} over its private endpoint."

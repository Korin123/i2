#!/usr/bin/env bash
# Bootstrap the application data: Information Store schema (db_init) on the MI.
# Run once the MI is reachable. The Solr cluster and collections are initialised by
# scripts/40-deploy-workload.sh (they must exist before Solr/Liberty start).
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${MI_FQDN:?}"; : "${ADT_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"
render() { sed -e "s#__ACR__#${ACR_LS}#g" -e "s#__MI_FQDN__#${MI_FQDN}#g" -e "s#__ADT_VERSION__#${ADT_VERSION}#g" "$1"; }

render k8s/jobs/db-init-job.yaml | kubectl apply -f -
kubectl wait --for=condition=complete job/i2-db-init -n i2analyze --timeout=1800s
log "Data bootstrap complete."

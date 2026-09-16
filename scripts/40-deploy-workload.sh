#!/usr/bin/env bash
# Substitute placeholders and apply the Kubernetes manifests. Order:
# ZooKeeper -> Solr -> Liberty. The DB is SQL MI (external), so no DB manifest.
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${WI_CLIENT_ID:?}"; : "${KV:?}"; : "${TENANT_ID:?}"; : "${MI_FQDN:?}"; : "${I2_VERSION:?}"; : "${ADT_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"

az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

render() { sed -e "s#__ACR__#${ACR_LS}#g" -e "s#__WI_CLIENT_ID__#${WI_CLIENT_ID}#g" \
              -e "s#__KV_NAME__#${KV}#g" -e "s#__TENANT_ID__#${TENANT_ID}#g" \
              -e "s#__MI_FQDN__#${MI_FQDN}#g" -e "s#__I2_VERSION__#${I2_VERSION}#g" \
              -e "s#__ADT_VERSION__#${ADT_VERSION}#g" "$1"; }

for f in namespace secretproviderclass zookeeper-statefulset solr-statefulset liberty-deployment connectors-deployment services ingress; do
  render "k8s/${f}.yaml" | kubectl apply -f -
done
log "Workload applied. Watch: kubectl get pods -n i2analyze -w"

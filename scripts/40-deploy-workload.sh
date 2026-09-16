#!/usr/bin/env bash
# Substitute placeholders and apply the Kubernetes manifests, in ADT's order:
# ZooKeeper -> Solr cluster init (chroot, urlScheme, security.json, configsets)
# -> Solr -> collections -> Liberty. The DB is SQL MI (external), so no DB manifest.
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${WI_CLIENT_ID:?}"; : "${KV:?}"; : "${TENANT_ID:?}"; : "${MI_FQDN:?}"; : "${I2_VERSION:?}"; : "${ADT_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"
ns=i2analyze

az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

render() { sed -e "s#__ACR__#${ACR_LS}#g" -e "s#__WI_CLIENT_ID__#${WI_CLIENT_ID}#g" \
              -e "s#__KV_NAME__#${KV}#g" -e "s#__TENANT_ID__#${TENANT_ID}#g" \
              -e "s#__MI_FQDN__#${MI_FQDN}#g" -e "s#__I2_VERSION__#${I2_VERSION}#g" \
              -e "s#__ADT_VERSION__#${ADT_VERSION}#g" "$1"; }
apply() { for f in "$@"; do render "k8s/${f}.yaml" | kubectl apply -f -; done; }
run_job() { # job file under k8s/jobs, job name
  kubectl delete job "$2" -n "$ns" --ignore-not-found
  render "k8s/jobs/$1.yaml" | kubectl apply -f -
  kubectl wait --for=condition=complete "job/$2" -n "$ns" --timeout=900s
}

apply namespace secretproviderclass services
apply zookeeper-statefulset
kubectl rollout status statefulset/zookeeper -n "$ns" --timeout=900s
log "Solr cluster init in ZooKeeper"
run_job solr-zk-init-job i2-solr-zk-init
apply solr-statefulset
kubectl rollout status statefulset/solr -n "$ns" --timeout=900s
log "Solr collections"
run_job solr-collections-job i2-solr-collections
apply liberty-deployment connectors-deployment ingress
log "Workload applied. Watch: kubectl get pods -n $ns -w"

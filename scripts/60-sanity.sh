#!/usr/bin/env bash
# Sanity checks (Azure equivalent of the i2 sanity_tests role).
source "$(dirname "$0")/00-common.sh"
az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing >/dev/null
kubelogin convert-kubeconfig -l azurecli >/dev/null
echo "=== pods ==="; kubectl get pods -n i2analyze -o wide
echo "=== workloads ==="; kubectl get statefulset,deploy,svc -n i2analyze
echo "=== expected: zookeeper 3/3, solr 2/2, liberty 2/2; 8 Solr collections; MI reachable on 1433 ==="

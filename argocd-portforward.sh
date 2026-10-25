#!/usr/bin/env bash
# A helper script to setup ArgoCD portforward
set -eu

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
export KUBECONFIG="$SCRIPT_DIR/kubeconfig-argocd"

if [ ! -f "$KUBECONFIG" ]; then
  gcloud container clusters get-credentials "${CLUSTER_NAME:-k8tre-dev-argocd}" \
    --location "${GCP_LOCATION:-europe-west2-a}" \
    --project "${GCP_PROJECT_ID:-k8tre-dev-project}"
fi

kubectl -nargocd get secret argocd-initial-admin-secret -ojsonpath='{.data.password}' | base64 -d
echo

kubectl port-forward svc/argocd-server -n argocd 8080:80

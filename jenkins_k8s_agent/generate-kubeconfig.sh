#!/usr/bin/env bash
# Fills the kube_config.yml template with the Jenkins SA's server URL, CA and token.
# Usage: ./generate-kubeconfig.sh [output-file]   (default: jenkins-kubeconfig.yml)
set -euo pipefail

NS=k8s
SECRET=jenkins-token
DIR=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$DIR/jenkins-kubeconfig.yml}

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl get secret "$SECRET" -n "$NS" -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl get secret "$SECRET" -n "$NS" -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$SERVER" ] || [ -z "$CA" ] || [ -z "$TOKEN" ]; then
  echo "Missing server URL, CA or token. Is sa.yml applied and the right context selected?" >&2
  exit 1
fi

sed -e '/^#/d' \
    -e "s|<SERVER_URL>|$SERVER|" \
    -e "s|<CA_DATA>|$CA|" \
    -e "s|<TOKEN>|$TOKEN|" \
    "$DIR/kube_config.yml" > "$OUT"
chmod 600 "$OUT"

echo "Wrote $OUT (server: $SERVER)"

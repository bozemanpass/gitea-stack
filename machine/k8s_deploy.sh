#!/bin/bash

BPI_SCRIPT_DEBUG="${BPI_SCRIPT_DEBUG}"

IMAGE_REGISTRY=""
IMAGE_REGISTRY_USERNAME=""
IMAGE_REGISTRY_PASSWORD=""
HTTP_PROXY_FQDN="${BPI_MACHINE_FQDN}"
HTTP_PROXY_CLUSTER_ISSUER=""

while (( "$#" )); do
   case $1 in
      --debug)
         BPI_SCRIPT_DEBUG="true"
         ;;
      --image-registry)
         shift&&IMAGE_REGISTRY="$1"||die
         ;;
      --image-registry-username)
         shift&&IMAGE_REGISTRY_USERNAME="$1"||die
         ;;
      --image-registry-password)
         shift&&IMAGE_REGISTRY_PASSWORD="$1"||die
         ;;
      --http-proxy-fqdn)
         shift&&HTTP_PROXY_FQDN="$1"||die
         ;;
      --http-proxy-cluster-issuer)
         shift&&HTTP_PROXY_CLUSTER_ISSUER="$1"||die
         ;;
         *)
         echo "Unrecognized argument: $1" 1>&2
         ;;
   esac
   shift
done

STACK_CMD="stack"
if [[ -n "${BPI_SCRIPT_DEBUG}" ]]; then
  set -x
  STACK_CMD="${STACK_CMD} --debug --verbose"
fi

if [[ -z "$IMAGE_REGISTRY" ]]; then
  if [[ -f "/etc/rancher/k3s/registries.yaml" ]]; then
    IMAGE_REGISTRY=$(cat /etc/rancher/k3s/registries.yaml | grep -A1 'configs:$' | tail -1 | awk '{ print $1 }' | cut -d':' -f1)
    IMAGE_REGISTRY_USERNAME=$(cat /etc/rancher/k3s/registries.yaml | grep 'username:' | awk '{ print $2 }' | sed "s/[\"']//g")
    IMAGE_REGISTRY_PASSWORD=$(cat /etc/rancher/k3s/registries.yaml | grep 'password:' | awk '{ print $2 }' | sed "s/[\"']//g")
  fi
fi

$STACK_CMD fetch-stack telackey/gitea-stack

$STACK_CMD --stack ~/bpi/gitea-stack/stacks/gitea setup-repositories
$STACK_CMD --stack ~/bpi/gitea-stack/stacks/gitea build-containers

sudo chmod a+r /etc/rancher/k3s/k3s.yaml

HTTP_PROXY_ARG=""
if [[ -n "${HTTP_PROXY_FQDN}" ]]; then
  if [[ -n "${HTTP_PROXY_CLUSTER_ISSUER}" ]]; then
    HTTP_PROXY_ARG="--http-proxy ${HTTP_PROXY_CLUSTER_ISSUER}~${HTTP_PROXY_FQDN}:gitea:3000"
  else
    HTTP_PROXY_ARG="--http-proxy ${HTTP_PROXY_FQDN}:gitea:3000"
  fi
fi

$STACK_CMD \
  --stack ~/bpi/gitea-stack/stacks/gitea \
  deploy \
    --deploy-to k8s \
    init \
      --output gitea.yml \
      --kube-config /etc/rancher/k3s/k3s.yaml \
      --image-registry $IMAGE_REGISTRY/bozemanpass ${HTTP_PROXY_ARG}

mkdir $HOME/deployments

$STACK_CMD \
  --stack ~/bpi/gitea-stack/stacks/gitea \
  deploy \
    create \
     --spec-file gitea.yml \
     --deployment-dir $HOME/deployments/gitea

docker login --username "$IMAGE_REGISTRY_USERNAME" --password "$IMAGE_REGISTRY_PASSWORD" $IMAGE_REGISTRY

$STACK_CMD deployment --dir $HOME/deployments/gitea push-images
$STACK_CMD deployment --dir $HOME/deployments/gitea start

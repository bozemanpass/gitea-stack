#!/bin/bash

IMAGE_REGISTRY=""
IMAGE_REGISTRY_USERNAME=""
IMAGE_REGISTRY_PASSWORD=""

while (( "$#" )); do
   case $1 in
      --image-registry)
         shift&&IMAGE_REGISTRY="$1"||die
         ;;
      --image-registry-username)
         shift&&IMAGE_REGISTRY_USERNAME="$1"||die
         ;;
      --image-registry-password)
         shift&&IMAGE_REGISTRY_PASSWORD="$1"||die
         ;;
         *)
         echo "Unrecognized argument: $1" 1>&2
         ;;
   esac
   shift
done

if [[ -z "$IMAGE_REGISTRY" ]]; then
  if [[ -f "/etc/rancher/k3s/registries.yaml" ]]; then
    IMAGE_REGISTRY=$(cat /etc/rancher/k3s/registries.yaml | grep -A1 'configs:$' | tail -1 | awk '{ print $1 }' | cut -d':' -f1)
    IMAGE_REGISTRY_USERNAME=$(cat /etc/rancher/k3s/registries.yaml | grep 'username:' | awk '{ print $2 }' | sed "s/[\"']//g")
    IMAGE_REGISTRY_PASSWORD=$(cat /etc/rancher/k3s/registries.yaml | grep 'password:' | awk '{ print $2 }' | sed "s/[\"']//g")
  fi
fi

stack fetch-stack telackey/gitea-stack@telackey/k8s

stack --stack ~/bpi/gitea-stack/stacks/gitea setup-repositories
stack --stack ~/bpi/gitea-stack/stacks/gitea build-containers

sudo chmod a+r /etc/rancher/k3s/k3s.yaml

stack --stack ~/bpi/gitea-stack/stacks/gitea deploy \
 --deploy-to k8s init --output gitea.yml \
 --kube-config /etc/rancher/k3s/k3s.yaml \
 --image-registry registry.digitalocean.com/bozemanpass

mkdir $HOME/deployments

stack --stack ~/bpi/gitea-stack/stacks/gitea deploy \
   create --spec-file gitea.yml --deployment-dir $HOME/deployments/gitea

if [[ -n "$IMAGE_REGISTRY" ]]; then
  docker login --username "$IMAGE_REGISTRY_USERNAME" --password "$IMAGE_REGISTRY_PASSWORD" $IMAGE_REGISTRY
fi

stack deployment --dir $HOME/deployments/gitea push-images
stack deployment --dir $HOME/deployments/gitea up

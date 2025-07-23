#!/bin/bash
set -e

echo "Installing NGINX Ingress Controller..."
kubectl create namespace ingress-nginx || true

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.publishService.enabled=true

echo "Installing Argo CD..."
kubectl create namespace argocd || true

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to become ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "Argo CD and NGINX Ingress installed!"


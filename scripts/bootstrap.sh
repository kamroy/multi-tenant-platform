#!/usr/bin/env bash
set -euo pipefail

# Bootstrap complet de la plateforme multi-tenant sur un cluster k3s local (WSL).
# Prérequis : k3s déjà installé et démarré, kubectl, helm.
#
# Note CNI : contrairement à kind, k3s embarque un contrôleur NetworkPolicy
# natif (basé sur kube-router) même avec Flannel comme CNI par défaut.
# Pas besoin d'installer Calico — les NetworkPolicies de ce repo sont
# effectives dès l'installation par défaut de k3s.
# Si le contrôleur a été désactivé (--disable-network-policy au moment de
# l'install), les NetworkPolicy seront créées mais silencieusement ignorées.
# Vérifier avec : kubectl get pods -n kube-system | grep network-policy

echo "==> 0. Vérification du cluster k3s"
kubectl config current-context
kubectl get nodes

echo "==> 1. Installation d'ArgoCD"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> 2. Installation de Kyverno"
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update
kubectl create namespace kyverno
helm install kyverno kyverno/kyverno -n kyverno

echo "==> 3. Installation stack observabilité (kube-prometheus-stack, config allégée pour WSL)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
kubectl create namespace platform
# --set réduit l'empreinte mémoire par défaut (Alertmanager désactivé,
# rétention courte) : suffisant pour une démo, à ne pas utiliser en prod.
helm install monitoring prometheus-community/kube-prometheus-stack -n platform \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.retention=6h \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set grafana.resources.requests.memory=128Mi

echo "==> 4. Attente qu'ArgoCD soit prêt"
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

echo "==> 5. Application du app-of-apps (déploie les tenants + policies)"
kubectl apply -f gitops/app-of-apps.yaml

echo ""
echo "✅ Plateforme bootstrappée."
echo "   ArgoCD UI     : kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Mot de passe  : kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "   Grafana       : kubectl port-forward svc/monitoring-grafana -n platform 3000:80"

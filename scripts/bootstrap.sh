#!/usr/bin/env bash
set -euo pipefail

# Bootstrap complet de la plateforme multi-tenant sur un cluster k3s local (WSL).
# Prérequis : k3s déjà installé et démarré, kubectl, helm.
#
# Note CNI : ce cluster utilise Cilium (Flannel désactivé au niveau k3s),
# validé empiriquement — un test deny-all/wget confirme que les
# NetworkPolicies sont correctement enforced. Pas d'action CNI nécessaire
# dans ce script.

echo "==> 0. Vérification du cluster k3s"
kubectl config current-context
kubectl get nodes

echo "==> 1. Installation d'ArgoCD"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> 1b. Installation d'ingress-nginx"
# k3s installe Traefik par défaut. On installe ingress-nginx en plus (sans
# désactiver Traefik) pour rester cohérent avec les recording rules SLO qui
# utilisent les métriques nginx_ingress_controller_*. Traefik peut rester
# actif en parallèle, il ne gère juste pas ce namespace.
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
kubectl create namespace ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
  --set controller.metrics.enabled=true \
  --set controller.podLabels.kubernetes\\.io/metadata\\.name=ingress-nginx

echo "==> 1c. Installation de Chaos Mesh"
helm repo add chaos-mesh https://charts.chaos-mesh.org 2>/dev/null || true
helm repo update
kubectl create namespace chaos-mesh
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/k3s/containerd/containerd.sock

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

echo "==> 5b. Application des méta-Applications chaos + SLO"
kubectl apply -f gitops/chaos-and-slo-apps.yaml

echo ""
echo "✅ Plateforme bootstrappée."
echo "   ArgoCD UI     : kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Mot de passe  : kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "   Grafana       : kubectl port-forward svc/monitoring-grafana -n platform 3000:80"

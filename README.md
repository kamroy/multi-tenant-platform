# Multi-Tenant Platform

Plateforme Kubernetes multi-tenant démontrant isolation réseau, gouvernance
des ressources, policy-as-code et déploiement GitOps — conçue comme un
projet portfolio de Platform Engineering.

## Le problème

Plusieurs équipes produit partagent un cluster Kubernetes. Comment garantir
isolation, équité de ressources et conformité de sécurité **sans**
provisionner un cluster dédié par équipe (coût prohibitif à l'échelle) ?

➡️ Voir le [design doc complet](docs/design-doc.md) pour l'analyse des
options envisagées et les trade-offs.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Cluster K8s (kind)               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ team-a   │ │ team-b   │ │ team-c   │          │
│  │ Quota    │ │ Quota    │ │ Quota    │          │
│  │ NetPol   │ │ NetPol   │ │ NetPol   │          │
│  │ RBAC     │ │ RBAC     │ │ RBAC     │          │
│  └──────────┘ └──────────┘ └──────────┘          │
│  ┌───────────────────────────────────────────┐   │
│  │ platform : ArgoCD · Kyverno · Prometheus    │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Stack technique

| Domaine | Outil | Rôle |
|---|---|---|
| Cluster local | k3s (WSL) | Environnement de démo léger |
| CNI | Flannel + contrôleur NetworkPolicy natif de k3s (kube-router) | Application effective des NetworkPolicies sans CNI additionnel |
| GitOps | ArgoCD (ApplicationSet, pattern app-of-apps) | Déploiement déclaratif par tenant |
| Policy-as-code | Kyverno | Blocage des workloads non conformes (root, `:latest`, sans limits) |
| Observabilité | kube-prometheus-stack (config allégée) | Dashboards par tenant |
| IaC | YAML déclaratif | Namespace, ResourceQuota, NetworkPolicy, RBAC |

> **Note CNI** : contrairement à `kind`, k3s embarque par défaut un
> contrôleur NetworkPolicy (basé sur kube-router) même avec Flannel.
> Pas besoin d'installer Calico — vérifier simplement qu'il tourne avec
> `kubectl get pods -n kube-system | grep network-policy`. Il n'est absent
> que si k3s a été installé avec `--disable-network-policy`.

## Démarrage rapide

Prérequis : k3s installé et démarré dans WSL, `kubectl`, `helm`.

```bash
git clone <ce-repo>
cd multi-tenant-platform
./scripts/bootstrap.sh
```

Le script vérifie l'accès au cluster k3s, installe ArgoCD/Kyverno/Prometheus,
et déploie automatiquement les 3 tenants via GitOps.

## Ajouter un nouveau tenant

Grâce au pattern app-of-apps, onboarder une équipe = ajouter un dossier :

```bash
cp -r tenants/team-a tenants/team-d
sed -i 's/team-a/team-d/g' tenants/team-d/*.yaml
# ajuster le ResourceQuota selon les besoins de l'équipe
git add tenants/team-d && git commit -m "onboard team-d" && git push
```

ArgoCD détecte le nouveau dossier et déploie automatiquement. **Aucune
commande kubectl manuelle nécessaire** — c'est tout l'intérêt du pattern.

## Décisions d'architecture

Les choix structurants sont documentés en ADR :

- [ADR-0001](docs/adr/0001-namespace-based-tenancy.md) — Isolation par
  namespace plutôt que par cluster dédié

## Ce que je ferais différemment à l'échelle

- **> 10 tenants ou besoins d'isolation renforcés** → migration vers
  [vCluster](https://www.vcluster.com/) pour donner à chaque équipe
  l'illusion d'un cluster dédié sans le coût
- **Facturation interne** → exposer les métriques d'usage par tenant vers
  un système de chargeback (OpenCost)
- **Résilience** → cluster multi-région avec réplication cross-cluster

## Structure du repo

```
.
├── docs/                # Design doc + ADRs
├── infra/                # Config du cluster kind
├── tenants/               # Un dossier par tenant (namespace, quota, netpol, rbac)
├── gitops/                # ApplicationSet ArgoCD + policies Kyverno
└── scripts/               # Bootstrap automatisé
```

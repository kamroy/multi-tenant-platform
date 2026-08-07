# Design Doc — Multi-Tenant Platform

**Statut** : Draft
**Auteur** : Romeo KAMENI
**Date** : 2026-08

## 1. Contexte et problème

Plusieurs équipes produit partagent aujourd'hui un cluster Kubernetes unique.
Sans mécanismes d'isolation, une équipe peut :
- consommer plus de ressources que prévu et impacter les autres (bruit de voisinage / "noisy neighbor")
- accéder par erreur (ou intentionnellement) aux ressources d'une autre équipe
- déployer des workloads non conformes aux standards de sécurité de la plateforme

**Objectif** : concevoir et implémenter une plateforme Kubernetes multi-tenant
qui garantit isolation réseau, équité de ressources, contrôle d'accès et
observabilité par équipe — sans dupliquer un cluster par équipe (coût prohibitif).

## 2. Contraintes

- Budget : pas de cluster dédié par tenant (trop coûteux à l'échelle)
- Time-to-onboard : une nouvelle équipe doit pouvoir être onboardée en < 15 minutes
- Sécurité : isolation réseau stricte entre tenants par défaut (deny-all puis allow explicite)
- Observabilité : chaque équipe doit voir ses propres métriques/logs, pas ceux des autres
- Auditabilité : toute action de provisioning doit être traçable (GitOps)

## 3. Options envisagées

### Option A — Namespace-based multi-tenancy (isolation logique)
Un namespace par tenant, avec NetworkPolicies, ResourceQuotas, RBAC et
policies (Kyverno/OPA) pour faire respecter les standards.

- ✅ Coût faible, un seul cluster
- ✅ Rapide à mettre en place et à onboarder de nouvelles équipes
- ❌ Isolation plus faible qu'un cluster dédié (kernel partagé, risques CVE)
- ❌ Nécessite une discipline forte sur les policies

### Option B — Cluster dédié par tenant (isolation forte)
Un cluster K8s par équipe, provisionné via Terraform/Crossplane.

- ✅ Isolation maximale (failure domain séparé)
- ❌ Coût très élevé à l'échelle (N clusters à maintenir, patcher, monitorer)
- ❌ Complexité opérationnelle multipliée par N

### Option C — vCluster (clusters virtuels dans un cluster hôte)
Chaque tenant a l'illusion d'un cluster dédié (via vCluster), mais tous
tournent sur la même infra physique.

- ✅ Bon compromis isolation / coût
- ✅ Chaque équipe peut avoir ses propres CRDs, versions d'API
- ❌ Complexité additionnelle (couche de virtualisation à opérer)

## 4. Décision

**Option A (namespace-based)** pour la v1, avec une note explicite que
**Option C (vCluster)** est le chemin d'évolution naturel si le nombre de
tenants ou leurs besoins d'isolation augmentent (voir ADR-0003).

Raisonnement : à ce stade, le ratio coût/bénéfice favorise largement
l'isolation logique. La migration vers vCluster ne nécessite pas de
réécriture complète si les tenants sont déjà bien délimités par namespace.

## 5. Architecture cible

```
┌─────────────────────────────────────────────────┐
│                  Cluster K8s (kind)               │
│                                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │
│  │  team-a       │ │  team-b      │ │  team-c    │ │
│  │  namespace    │ │  namespace   │ │  namespace │ │
│  │              │ │              │ │            │ │
│  │ ResourceQuota│ │ ResourceQuota│ │ResourceQuota│ │
│  │ NetworkPolicy│ │ NetworkPolicy│ │NetworkPolicy│ │
│  │ RBAC         │ │ RBAC         │ │ RBAC       │ │
│  └──────────────┘ └──────────────┘ └────────────┘ │
│                                                     │
│  ┌───────────────────────────────────────────┐   │
│  │  Platform namespace (partagé)               │   │
│  │  - ArgoCD (GitOps)                          │   │
│  │  - Kyverno (policy engine)                  │   │
│  │  - Prometheus + Grafana (par tenant)         │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## 6. Composants

| Composant | Rôle |
|---|---|
| kind/k3d | Cluster local pour développement/démo |
| ArgoCD | Déploiement GitOps déclaratif, app-of-apps pattern |
| Kyverno | Policy-as-code : bloquer les workloads non conformes |
| NetworkPolicy (Calico/Cilium) | Isolation réseau deny-all par défaut |
| ResourceQuota / LimitRange | Équité de ressources par tenant |
| RBAC | Accès limité au namespace de l'équipe |
| Prometheus + Grafana | Dashboards filtrés par tenant (labels) |

## 7. Métriques de succès (même simulées pour la démo)

- Temps d'onboarding d'un nouveau tenant : cible < 15 min
- Zéro communication réseau inter-tenant non autorisée (test avec chaos/pentest simulé)
- 100% des workloads passent les policies Kyverno avant déploiement

## 8. Ce que je ferais différemment à l'échelle

- Passage à vCluster si > 10 tenants ou besoins d'isolation renforcés
- Cluster multi-région avec réplication cross-cluster pour la résilience
- Intégration d'un vrai système de facturation interne (chargeback) basé sur les métriques d'usage

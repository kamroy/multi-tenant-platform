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
| CNI | Cilium (eBPF), Flannel désactivé | Application effective des NetworkPolicies |
| GitOps | ArgoCD (ApplicationSet, pattern app-of-apps) | Déploiement déclaratif par tenant |
| Policy-as-code | Kyverno | Blocage des workloads non conformes (root, `:latest`, sans limits) |
| Observabilité | kube-prometheus-stack (config allégée) | Dashboards par tenant |
| IaC | YAML déclaratif | Namespace, ResourceQuota, NetworkPolicy, RBAC |

> **Note CNI** : ce cluster utilise Cilium (eBPF) avec Flannel désactivé au
> niveau k3s (`--flannel-backend=none`). L'enforcement des NetworkPolicies
> a été validé empiriquement : un pod avec policy `deny-all` bloque
> effectivement le trafic entrant (`wget` timeout attendu).

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
- [ADR-0002](docs/adr/0002-chaos-engineering-proactif.md) — Chaos
  engineering proactif plutôt que réactif
- [ADR-0003](docs/adr/0003-cilium-cni.md) — Cilium comme CNI, en
  remplacement de Flannel, validé empiriquement

## Module résilience : Chaos Engineering & SLOs

Extension qui valide empiriquement que les tenants survivent aux pannes,
et pas seulement qu'ils sont isolés les uns des autres.

➡️ Voir le [design doc dédié](docs/design-doc-resilience.md) pour le détail
des SLO, de la politique d'error budget et des expériences.

| Composant | Rôle |
|---|---|
| Chaos Mesh | Injection de pannes (pod-kill, network-delay, network-loss) |
| Prometheus recording rules | Calcul des SLI (disponibilité, latence) et de l'error budget par tenant |
| CronJob error-budget-policy | Ferme la boucle : suspend automatiquement les expériences à fort impact quand le budget descend sous 50%, toutes sous 10% |
| Dashboard Grafana | Disponibilité, error budget restant, burn rate, latence p95 — par tenant |

Ce module réutilise l'infra existante : les expériences ciblent le
`demo-api` de team-a (avec label opt-in `chaos-target: "true"`, jamais tout
le namespace par défaut), et sont déployées en GitOps comme le reste.

**Prérequis additionnel** : ingress-nginx et Chaos Mesh, tous deux installés
par `scripts/bootstrap.sh`.

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
├── docs/                # Design docs + ADRs
├── tenants/               # Un dossier par tenant (namespace, quota, netpol, rbac, workload)
├── gitops/                # ApplicationSet ArgoCD + policies Kyverno + apps chaos/SLO
├── chaos/experiments/      # Expériences Chaos Mesh (pod-kill, network-delay, network-loss)
├── slo/                   # Recording rules Prometheus, dashboard Grafana, error budget policy
└── scripts/               # Bootstrap automatisé
```

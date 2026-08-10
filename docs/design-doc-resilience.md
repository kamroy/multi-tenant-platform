# Design Doc — Résilience : Chaos Engineering & SLOs par tenant

**Statut** : Draft
**Extension de** : multi-tenant-platform (voir design-doc.md principal)

## 1. Contexte et problème

La plateforme multi-tenant garantit aujourd'hui l'isolation (réseau, quotas,
policies) mais ne répond pas à une question centrale pour une plateforme de
production : **le système se comporte-t-il correctement quand quelque chose
casse ?**

Deux angles morts identifiés :
1. **Pas de définition formelle de "correct"** : aucun SLO n'existe. Sans
   objectif chiffré, impossible de dire si un incident est acceptable ou non.
2. **Pas de validation de la résilience** : rien ne prouve que les
   applications survivent à un pod tué, une latence réseau injectée, ou un
   nœud qui tombe. On le découvre en général... en production.

## 2. Objectif

Ajouter à la plateforme existante :
- Des **SLO par tenant** (disponibilité, latence) avec error budget calculé
- Des **expériences de chaos engineering** régulières et automatisées
  (via GitOps, comme le reste de la plateforme) qui valident empiriquement
  que les SLO tiennent sous perturbation
- Un **dashboard de fiabilité par tenant**, visible par chaque équipe,
  cohérent avec le principe d'isolation déjà en place (chaque équipe voit
  ses propres métriques, pas celles des autres)

## 3. Pourquoi le chaos engineering AVANT que ce soit demandé

Deux approches possibles :
- **Réactive** : attendre un incident réel, puis faire un post-mortem
- **Proactive** : injecter des pannes contrôlées en continu pour découvrir
  les faiblesses avant qu'elles ne deviennent des incidents

On choisit l'approche proactive, cohérente avec la philosophie déjà présente
dans le reste du projet (Kyverno bloque les mauvaises pratiques *avant*
déploiement plutôt que de les détecter après coup).

## 4. Composants

| Composant | Rôle |
|---|---|
| Chaos Mesh | Injection de pannes (pod-kill, network-delay, network-loss) via CRDs Kubernetes |
| Prometheus recording rules | Calcul des SLI (availability, latency) à partir des métriques déjà collectées |
| Error budget policy | Règle définissant l'action à prendre quand le budget est épuisé |
| Grafana dashboards | Visualisation SLO + burn rate, un dashboard par tenant |
| ArgoCD | Les expériences de chaos sont déployées en GitOps, comme le reste |

## 5. Définition des SLO (exemple pour team-a)

| SLI | SLO | Fenêtre |
|---|---|---|
| Disponibilité | 99.5% des requêtes réussissent (non-5xx) | 30 jours glissants |
| Latence | 95% des requêtes < 300ms | 30 jours glissants |

Error budget résultant : 0.5% de requêtes en erreur tolérées sur 30 jours
(~3h36 de downtime total équivalent).

## 6. Politique d'error budget

- **Budget > 50% restant** : les expériences de chaos peuvent s'exécuter normalement
- **Budget entre 10% et 50%** : les expériences à fort impact (node-kill) sont suspendues, seules les expériences légères (latence) continuent
- **Budget < 10%** : toutes les expériences de chaos sont automatiquement suspendues (annotation sur le CronJob), gel des déploiements non critiques

Cette politique est ce qu'on appelle un **error budget policy** — elle
transforme un SLO abstrait en décision opérationnelle concrète.

## 7. Expériences de chaos prévues

1. **Pod-kill aléatoire** : tue un pod toutes les X minutes dans un
   namespace tenant, vérifie que le service reste disponible (réplication
   suffisante, readiness probes correctes)
2. **Network delay** : injecte 200ms de latence sur le trafic sortant d'un
   tenant, vérifie que les SLO de latence des dépendances sont respectés
3. **Network loss** : simule 20% de perte de paquets, vérifie les retries/circuit breakers côté client

## 8. Ce que ça démontre (angle recrutement)

- Compréhension du lien entre fiabilité mesurée (SLI/SLO) et décision
  opérationnelle (error budget policy), pas juste "on a mis un dashboard"
- Capacité à intégrer une pratique SRE dans une plateforme existante sans
  tout casser (réutilisation de Prometheus, du pattern GitOps déjà en place)
- Approche proactive de la fiabilité plutôt que réactive

## 9. Limites connues de cette v1

- Les expériences ciblent des workloads de démo (nginx), pas des services
  avec une vraie logique métier — donc les résultats sont illustratifs
- Pas de intégration avec un outil d'incident management (PagerDuty, etc.) —
  volontairement hors scope pour rester focalisé sur la boucle
  chaos → mesure → décision

# ADR-0002 : Chaos engineering proactif plutôt que réactif

## Statut
Accepté

## Contexte
La plateforme garantit l'isolation entre tenants mais ne valide pas
empiriquement leur résilience aux pannes. Deux approches possibles pour
combler ce manque : attendre les incidents réels (post-mortems) ou injecter
des pannes contrôlées en continu.

## Décision
Adopter le chaos engineering proactif via Chaos Mesh, avec des expériences
déployées en GitOps et gouvernées par une politique d'error budget basée sur
des SLO explicites.

## Conséquences

**Positives**
- Les faiblesses de résilience sont découvertes en environnement contrôlé,
  pas en production sous incident réel
- Les SLO donnent un langage commun objectif entre plateforme et équipes
  produit pour arbitrer entre vitesse de livraison et fiabilité
- Cohérent avec la philosophie "shift-left" déjà présente (Kyverno)

**Négatives**
- Complexité opérationnelle additionnelle (CRDs Chaos Mesh à maintenir,
  RBAC spécifique pour limiter le blast radius)
- Nécessite une culture d'équipe mature : le chaos engineering mal
  communiqué peut être perçu comme punitif plutôt que protecteur
- Risque réel si mal scopé (d'où la politique d'error budget qui suspend
  automatiquement les expériences à fort impact quand le budget est bas)

## Alternatives rejetées
- Post-mortems réactifs uniquement : insuffisant pour une plateforme qui se
  positionne comme garante de fiabilité multi-équipe
- Load testing classique seul : valide la capacité mais pas la résilience
  aux pannes partielles (ce que le chaos engineering couvre spécifiquement)

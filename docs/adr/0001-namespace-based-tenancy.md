# ADR-0001 : Isolation par namespace plutôt que par cluster

## Statut
Accepté

## Contexte
Voir design-doc.md section 3. Besoin de choisir un modèle d'isolation
multi-tenant pour la plateforme.

## Décision
Isolation logique par namespace, avec NetworkPolicy + ResourceQuota + RBAC
+ Kyverno, plutôt qu'un cluster dédié par équipe.

## Conséquences

**Positives**
- Coût d'infrastructure maîtrisé (un seul control plane)
- Onboarding rapide de nouvelles équipes (création de namespace vs provisioning de cluster)
- Opérations simplifiées (un seul cluster à patcher/monitorer)

**Négatives**
- Isolation kernel-level plus faible qu'un cluster dédié
- Une CVE au niveau du kernel/container runtime impacte potentiellement tous les tenants
- Nécessite une gouvernance stricte des policies pour éviter la dérive

## Alternatives rejetées
- Cluster dédié par tenant : coût et charge opérationnelle jugés disproportionnés pour le volume actuel de tenants
- vCluster : complexité additionnelle non justifiée à ce stade, mais retenu comme option d'évolution (voir ADR-0003, à rédiger si le besoin se confirme)

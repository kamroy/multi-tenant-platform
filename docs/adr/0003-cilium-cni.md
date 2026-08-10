# ADR-0003 : Cilium comme CNI, en remplacement de Flannel

## Statut
Accepté

## Contexte
L'installation par défaut de k3s (v1.36.2) utilise Flannel comme CNI.
En vérifiant l'enforcement des NetworkPolicies (prérequis pour ADR-0001,
l'isolation par namespace), aucun contrôleur NetworkPolicy actif n'a été
détecté sur ce cluster.

## Décision
Désactiver Flannel (`--flannel-backend=none`) et installer Cilium comme CNI
de remplacement, plutôt que de dépendre du contrôleur natif de k3s
(kube-router) ou d'installer Calico en overlay.

## Validation empirique
Plutôt que de se fier à la documentation seule, l'enforcement a été
vérifié directement : création d'un pod nginx, application d'une
NetworkPolicy `deny-all`, puis tentative de connexion depuis un pod tiers.
Le `wget` a correctement timeout, confirmant que Cilium bloque bien le
trafic non autorisé.

## Conséquences

**Positives**
- Data plane eBPF : meilleures performances et observabilité (Hubble) que
  kube-router (iptables) ou Flannel+Canal
- Support de policies plus riches si besoin futur (L7, DNS-aware policies)
- Écosystème plus large (service mesh natif possible via Cilium si besoin)

**Négatives**
- Remplacement du CNI par défaut = étape d'installation supplémentaire non
  automatisée dans `scripts/bootstrap.sh` (prérequis du cluster, pas de la
  plateforme applicative)
- Complexité légèrement supérieure à Flannel pour le débogage réseau bas niveau

## Alternatives rejetées
- Contrôleur natif k3s (kube-router) : absent/non actif sur cette
  installation, cause exacte non investiguée plus avant une fois Cilium
  choisi comme solution
- Calico en overlay de Flannel (pattern Canal) : fonctionnel mais Cilium
  offre un meilleur rapport performance/observabilité pour l'usage prévu

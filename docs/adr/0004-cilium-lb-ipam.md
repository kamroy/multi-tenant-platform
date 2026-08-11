# ADR-0004 : CiliumLoadBalancerIPPool pour les Services de type LoadBalancer

## Statut
Accepté

## Contexte
Après le passage à Cilium (ADR-0003), le Service `ingress-nginx-controller`
de type `LoadBalancer` restait indéfiniment en `EXTERNAL-IP: <pending>`.

Diagnostic : Cilium, en mode `kube-proxy-replacement: true`, active aussi
son propre mécanisme d'attribution d'IP pour les Services LoadBalancer
(LB-IPAM, `enable-lb-ipam: true`). Ce mécanisme **remplace** le ServiceLB
natif de k3s (aucun daemonset `svclb-*` n'est jamais créé une fois Cilium
en place) — mais sans pool d'IP configuré, LB-IPAM ne peut rien attribuer.

Conséquence en cascade observée : sans IP externe, `status.loadBalancer`
de l'Ingress restait vide, et le contrôle de santé intégré d'ArgoCD pour
les objets `Ingress` (qui vérifie `status.loadBalancer.ingress`) gardait
l'Application `tenant-team-a` en statut `Progressing` indéfiniment, malgré
un Deployment parfaitement sain (3/3 pods Running).

## Décision
Définir une `CiliumLoadBalancerIPPool` avec une plage restreinte sur le
sous-réseau du node WSL (`172.24.60.200/29`, 6 IP utilisables).

## Conséquences

**Positives**
- Résout le blocage à la source plutôt que de contourner en changeant le
  type de Service en NodePort (qui aurait évité le symptôme sans expliquer
  la cause)
- Documente une interaction non évidente entre deux couches (Cilium
  kube-proxy-replacement vs ServiceLB de k3s) — utile pour toute future
  installation de la plateforme sur un cluster Cilium

**Négatives**
- Une dépendance de plus à documenter/maintenir (le pool doit être
  dimensionné si de nouveaux Services LoadBalancer sont ajoutés)
- Spécifique à un environnement local (WSL) ; en cloud, l'IP viendrait du
  load balancer du provider et cette ressource ne serait pas nécessaire

## Alternative rejetée
- Service `NodePort`/`ClusterIP` pour ingress-nginx : aurait évité le
  symptôme sans nécessiter LB-IPAM, mais masque la cause racine et perd la
  cohérence avec un vrai comportement de LoadBalancer, utile pour la démo
  du pattern Ingress → status.loadBalancer → health check ArgoCD.

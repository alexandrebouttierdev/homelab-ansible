# Audit complet Ansible --- Homelab

## Mission

Tu es un ingénieur DevOps / administrateur systèmes Linux senior,
spécialisé dans Ansible, Debian, la sécurité des infrastructures
domestiques, Docker, la supervision et l'optimisation de ressources
limitées.

Ta mission est de réaliser un audit approfondi de mon projet Ansible,
`homelab-ansible` (anciennement nommé `provision-serveur`).

L'objectif est d'obtenir une configuration **sécurisée, performante,
fiable, simple, maintenable, correctement architecturée et entièrement
documentée**.

Tu dois être critique et factuel. Ne valide pas automatiquement mes
choix : identifie clairement les erreurs, les risques et les
améliorations réellement utiles.

**Priorités absolues :** 1. Sécurité réelle de l'infrastructure. 2.
Préservation des performances et des ressources du Dell OptiPlex. 3.
Fiabilité et absence d'interruption inutile des services. 4. Simplicité
de compréhension et de maintenance. 5. Documentation claire et complète.

Il ne s'agit pas de construire une infrastructure d'entreprise complexe.
Toute complexité, dépendance ou service supplémentaire doit être
justifié par un bénéfice concret.

------------------------------------------------------------------------

# 1. Contexte de l'infrastructure

## 1.1 Serveur physique

-   Modèle : Dell OptiPlex 3060 SFF.
-   Processeur : Intel Core i5-8500, 6 cœurs.
-   Mémoire vive : 16 Go DDR4.
-   Stockage système : SSD NVMe 256 Go.
-   Stockage complémentaire : HDD 1 To.
-   Système d'exploitation : Debian 13 minimal, installé directement sur
    le matériel.
-   Hébergement : domicile, derrière une connexion fibre Sosh.
-   Poste d'administration : Mac Studio.

Il n'y a pas de Proxmox ni de couche de virtualisation sur ce serveur.

Le serveur est une machine physique personnelle dont les ressources sont
limitées. Les recommandations doivent tenir compte de cette réalité.

## 1.2 Services installés directement sur Debian

-   Docker Engine.
-   Homelab Manager.
-   Ansible.
-   Cloudflare Tunnel (`cloudflared`), géré par systemd.

## 1.3 Services applicatifs

-   Coolify.
-   PostgreSQL.
-   Deux API développées avec NestJS.

Coolify gère les déploiements applicatifs, les conteneurs applicatifs
qu'il administre et les sauvegardes PostgreSQL.

**Ansible ne doit pas dupliquer les responsabilités de Coolify
concernant les déploiements applicatifs et les sauvegardes PostgreSQL.**

## 1.4 Stockage

Le HDD de 1 To est destiné aux données du homelab, avec le chemin prévu
:

`/srv/homelab-data`

Les données doivent être organisées proprement, en séparant autant que
nécessaire : - données applicatives ; - données persistantes ; -
configurations ; - données de supervision ; - journaux et fichiers
temporaires.

Ne modifie pas arbitrairement les chemins existants. Vérifie d'abord
leur utilisation réelle et les dépendances.

## 1.5 Projet Ansible existant

Nom actuel : `homelab-ansible` (anciennement `provision-serveur`).

Le projet comporte environ 36 fichiers. L'architecture connue comprend
notamment :

-   `ansible.cfg`
-   `requirements.yml`
-   `inventory/hosts.yml`
-   `inventory/group_vars/all.yml`
-   `playbooks/preflight.yml`
-   `playbooks/site.yml`
-   `playbooks/security.yml`
-   `playbooks/docker.yml`
-   `playbooks/monitoring.yml`
-   `playbooks/cloudflare-tunnel.yml`

Les rôles connus couvrent notamment : - `base` - `admin_user` -
`apparmor` - `ssh` - `firewall` - `fail2ban` - `sysctl` - `swap` -
`docker` - `homelab_manager`

Cette liste est indicative. Vérifie les fichiers réellement présents et
ne présume jamais de leur contenu.

------------------------------------------------------------------------

# 2. Objectifs de l'audit

Vérifie que le projet est :

1.  Sécurisé de manière adaptée à un serveur domestique exposé
    indirectement à Internet.
2.  Compatible avec Debian 13.
3.  Optimisé pour un i5-8500 et 16 Go de RAM.
4.  Idempotent et reproductible.
5.  Facile à comprendre pour un administrateur système junior.
6.  Facile à maintenir et à faire évoluer.
7.  Correctement documenté.
8.  Cohérent dans la séparation des responsabilités.
9.  Dépourvu de dépendances et de services inutiles.
10. Capable d'être exécuté sans mettre inutilement en danger l'accès au
    serveur ou les services existants.

Ne cherche pas à maximiser le nombre de contrôles ou d'outils. Recherche
le meilleur équilibre entre sécurité, fiabilité, performances et
simplicité.

------------------------------------------------------------------------

# 3. Audit de sécurité

## 3.1 Debian et système

Analyse notamment : - configuration générale de Debian 13 ; - mises à
jour de sécurité ; - dépôts APT et dépôts tiers ; - paquets installés et
versions ; - services systemd actifs ; - services inutiles ou exposés
; - comptes utilisateurs et comptes système ; - groupes et privilèges
; - configuration sudo ; - permissions des fichiers et répertoires
sensibles ; - mécanismes de protection disponibles ; - journaux système
et leur conservation.

Identifie les écarts de configuration et les risques concrets. Ne
recommande pas de durcissement arbitraire sans expliquer son utilité et
ses conséquences.

## 3.2 SSH

Vérifie : - authentification par clés ; - désactivation éventuelle de
l'authentification par mot de passe ; - interdiction de connexion
directe de root ; - algorithmes et paramètres cryptographiques ; -
permissions de `.ssh` et des clés ; - configuration effective de `sshd`
; - limitation des tentatives de connexion ; - exposition réseau.

**Ne désactive jamais l'authentification par mot de passe avant d'avoir
vérifié qu'une connexion par clé fonctionne réellement.**

Toute modification SSH doit prévoir une validation indépendante et une
procédure de récupération pour éviter de perdre l'accès distant.

## 3.3 Firewall et réseau

Analyse : - UFW ou nftables réellement utilisé ; - règles entrantes et
sortantes ; - interfaces réseau ; - ports en écoute ; - services
accessibles depuis le LAN ; - services accessibles depuis Internet ; -
règles Docker ; - réseaux et ports publiés par les conteneurs ; -
interactions entre Docker et le firewall ; - filtrage entre conteneurs
et vers l'hôte.

Une attention particulière doit être portée à Docker : ses règles
peuvent modifier le comportement attendu d'UFW.

Vérifie notamment : - chaînes et règles `DOCKER-USER` lorsqu'elles
existent ; - ports publiés ; - interfaces d'écoute ; - communications
entre réseaux Docker ; - accès aux services de l'hôte ; - exposition
involontaire sur toutes les interfaces.

Ne considère pas UFW comme une protection suffisante sans examiner les
règles effectives. Ne bloque pas les communications nécessaires à
Coolify, PostgreSQL, aux API ou aux services d'administration.

## 3.4 Fail2ban

Vérifie : - intérêt réel dans cette infrastructure ; - jails activés ; -
protection SSH ; - seuils de bannissement ; - faux positifs possibles
; - intégration avec le firewall ; - cohérence des journaux surveillés.

Évite une configuration inutilement complexe.

## 3.5 AppArmor

Vérifie : - activation et état réel ; - profils chargés ; - profils en
mode enforce ou complain ; - protection des services ; - intégration
avec Docker ; - erreurs et conflits ; - éventuels profils manquants.

Ne désactive jamais AppArmor pour contourner un problème sans
justification technique précise.

## 3.6 Secrets

Analyse la gestion des secrets Ansible et recommande Ansible Vault pour
les données sensibles.

Vérifie : - mots de passe ; - clés API ; - tokens Cloudflare ; -
identifiants ; - variables sensibles ; - fichiers Vault ; - permissions
; - risques de fuite dans les logs, sorties de commandes ou dépôts Git.

Utilise `no_log: true` pour les tâches qui manipulent des secrets
lorsque nécessaire. Ne place jamais de secrets en clair dans les
fichiers versionnés, exemples ou documentation.

Vérifie également que les secrets ne sont pas exposés dans les arguments
de processus, les journaux ou les fichiers temporaires.

------------------------------------------------------------------------

# 4. Audit CVE et vulnérabilités publiées

Cette partie est **obligatoire**. L'audit ne doit pas se limiter à
vérifier la configuration Ansible ou à constater que les paquets
semblent à jour.

Tu dois confronter les versions réellement installées sur le serveur aux
vulnérabilités publiées et aux bulletins de sécurité disponibles **au
moment de l'audit**.

## 4.1 Sources à consulter

Privilégie les sources officielles :

1.  Debian Security Tracker :
    https://security-tracker.debian.org/tracker/
2.  Debian Security Advisories : https://www.debian.org/security/
3.  NVD : https://nvd.nist.gov/
4.  CISA Known Exploited Vulnerabilities :
    https://www.cisa.gov/known-exploited-vulnerabilities-catalog
5.  Avis de sécurité officiels des éditeurs concernés, notamment Docker,
    OpenSSH, Cloudflare, Homelab Manager et PostgreSQL.

Consulte les dates de publication et de dernière mise à jour. Cite les
sources utilisées et fournis des liens directs vers les fiches CVE et
avis pertinents.

Ne prétends jamais avoir vérifié une base ou une source si elle n'a pas
été consultée ou si elle est indisponible.

## 4.2 Composants à examiner

**Système Debian :** - Debian 13 (Trixie) ; - noyau Linux ; - OpenSSL
; - OpenSSH ; - systemd ; - sudo ; - PAM ; - APT ; - bibliothèques
système et paquets installés.

**Sécurité et réseau :** - AppArmor ; - Fail2ban ; - nftables ou UFW ; -
composants réseau effectivement utilisés.

**Conteneurs :** - Docker Engine ; - Docker Compose ; - containerd ; -
runc ; - composants réseau Docker.

**Services :** - Homelab Manager ; - Grype ; - restic ; - cloudflared ; -
PostgreSQL ; - Coolify et ses composants ; - images et dépendances des
applications NestJS, lorsque les informations sont accessibles.

Distingue les composants gérés par Ansible de ceux gérés par Coolify. Ne
modifie pas ces derniers sans validation spécifique.

## 4.3 Inventaire des versions

Pour chaque composant pertinent, récupère ou exploite : - nom du paquet
ou logiciel ; - version installée ; - version disponible ; - origine du
paquet ; - dépôt utilisé ; - version Debian concernée ; - version
contenant le correctif ; - état des mises à jour ; - éventuels dépôts
tiers.

Ne te contente jamais d'une recherche CVE par nom de logiciel. Compare
précisément les versions installées et les versions corrigées.

### Attention aux rétroportages Debian

Debian peut intégrer un correctif de sécurité dans une version de paquet
dont le numéro paraît ancien par rapport à la version amont.

Tu dois impérativement consulter le Debian Security Tracker et les avis
Debian avant de déclarer un paquet vulnérable.

Ne signale pas comme vulnérable un paquet uniquement parce que son
numéro de version est inférieur à celui indiqué dans une fiche amont.

Précise le statut Debian : vulnérable, corrigé, non affecté, en attente
ou indéterminé, selon les informations disponibles.

## 4.4 Période de recherche

Analyse : - les CVE récentes publiées au cours des 30 derniers jours ; -
les CVE publiées au cours des 90 derniers jours ; - toutes les
vulnérabilités plus anciennes qui restent applicables et non corrigées.

Une ancienne CVE toujours exploitable est prioritaire sur une CVE
récente sans impact réel.

Indique la date et l'heure de l'audit ainsi que la période couverte.

## 4.5 Classification et risque réel

Pour chaque vulnérabilité pertinente, indique : - identifiant CVE ; -
composant ; - version installée ; - version corrigée ; - date de
publication ; - date de dernière modification de la fiche ; - score CVSS
et version du score, si disponibles ; - sévérité ; - statut Debian 13
; - présence dans le catalogue CISA KEV ; - conditions d'exploitation
; - exposition réelle dans mon homelab ; - impact potentiel ; - action
corrective recommandée ; - sources officielles.

Classe les résultats : - **CRITIQUE** : risque majeur et exploitable
dans le contexte considéré ; - **ÉLEVÉE** : vulnérabilité importante
avec impact concret ; - **MOYENNE** : exploitation nécessitant des
conditions particulières ; - **FAIBLE** : impact limité dans cet
environnement ; - **NON APPLICABLE** : composant absent, fonctionnalité
non utilisée ou version officiellement non affectée ; - **À VÉRIFIER** :
informations insuffisantes pour conclure.

Ne confonds pas le score CVSS et le risque réel pour mon homelab.

Une CVE critique affectant un logiciel absent ne doit pas être présentée
comme un risque actif. Une vulnérabilité exploitable sur un service
accessible depuis Internet doit être fortement priorisée.

## 4.6 Exploitabilité dans mon contexte

Évalue les scénarios : - attaque depuis Internet ; - attaque depuis le
réseau local ; - compromission préalable d'un conteneur ; - élévation de
privilèges locale ; - accès non autorisé à l'hôte ; - compromission de
Docker ; - accès aux données PostgreSQL ; - fuite de secrets ; -
contournement du filtrage réseau ; - mouvement latéral vers les autres
équipements.

Prends en compte le fait que les services peuvent être exposés via
Cloudflare Tunnel et que le serveur est hébergé à domicile. Ne suppose
pas qu'un service est accessible publiquement : vérifie son exposition
réelle.

## 4.7 Images Docker et dépendances applicatives

Lorsque les informations sont disponibles, analyse les images utilisées
par Coolify : - nom de l'image ; - tag ; - digest ; - date de mise à
jour ; - système de base ; - paquets vulnérables ; - dépendances
présentant des CVE ; - images obsolètes ou abandonnées.

Utilise un scanner adapté, par exemple Trivy ou Grype, si cela est
possible.

Privilégie un scan ponctuel depuis le Mac Studio ou un environnement
d'administration afin de préserver les ressources du Dell. Ne déploie
pas un scanner permanent sur le serveur sans démontrer sa nécessité.

Ne reconstruis, ne redéploie et ne mets à jour aucune image applicative
sans validation.

## 4.8 Corrections CVE

Pour chaque vulnérabilité à corriger, propose une mesure adaptée : -
mise à jour de sécurité Debian ; - mise à jour du paquet concerné ; -
mise à jour d'un composant Docker ; - mise à jour d'une image ; -
modification de configuration ; - restriction d'exposition réseau ; -
désactivation d'une fonctionnalité inutile ; - mesure compensatoire
temporaire.

Précise les dépendances, risques d'interruption, conditions de
redémarrage et procédure de retour arrière.

Ne recommande jamais une mise à jour majeure aveuglément.

## 4.9 Rapport CVE obligatoire

Ajoute un tableau dédié :

  ---------------------------------------------------------------------------------------
  CVE      Composant   Version     Sévérité   Statut   Exposition   Risque   Correction
                       installée              Debian                réel     
  -------- ----------- ----------- ---------- -------- ------------ -------- ------------

  ---------------------------------------------------------------------------------------

Présente également : - nombre de CVE applicables ; - nombre de CVE
critiques ; - nombre de CVE élevées ; - nombre de CVE moyennes et
faibles ; - nombre de CVE corrigées ; - nombre de CVE non corrigées ; -
nombre de CVE non applicables ; - nombre de vulnérabilités à
investiguer.

Si aucune vulnérabilité applicable n'est trouvée, indique-le clairement
sans prétendre que le système est exempt de toute vulnérabilité.

Si tu ne peux pas consulter les versions installées ou les bases en
temps réel, indique précisément les limites et les commandes ou
informations nécessaires pour compléter l'audit. Ne fabrique jamais de
résultat CVE.

## 4.10 Suivi des vulnérabilités

Prévois une documentation `docs/vulnerability-management.md` expliquant
: - les sources consultées ; - les outils de scan ; - la procédure de
vérification ; - la fréquence recommandée ; - la classification des
risques ; - le traitement des alertes ; - la validation des correctifs
; - les limites de la démarche.

L'objectif est de pouvoir reproduire régulièrement cet audit, pas
seulement de réaliser un contrôle ponctuel.

------------------------------------------------------------------------

# 5. Audit des performances matérielles

Le Dell dispose de 16 Go de RAM et d'un processeur Intel i5-8500. Il
héberge plusieurs services simultanément.

La priorité est de préserver les ressources pour Docker, Coolify,
PostgreSQL et les API.

## 5.1 Mémoire

Analyse : - consommation mémoire des services ; - configuration du swap
; - paramètres sysctl ; - risques de saturation ; - mécanismes OOM ; -
allocations excessives ; - services consommant inutilement de la RAM.

Le swap prévu est de 2 Go. Vérifie si cette valeur et sa configuration
sont pertinentes.

Ne considère pas le swap comme un remplacement de la RAM. Ne recommande
pas de l'augmenter arbitrairement.

## 5.2 CPU

Analyse : - services sollicitant le processeur ; - tâches périodiques
; - contrôles de santé ; - traitements inutiles ; - fréquence des tâches
Ansible ; - coûts de la supervision.

Évite les réglages qui augmentent inutilement la charge CPU.

## 5.3 Stockage

Analyse : - utilisation du NVMe et du HDD ; - organisation des données
; - journaux système ; - rotation des logs ; - risques de saturation ; -
écritures excessives ; - fichiers temporaires ; - permissions et
propriétaires.

Évite de multiplier les écritures sur le SSD sans nécessité. Vérifie que
les données persistantes sont correctement organisées.

Ne déplace aucune donnée sans vérifier les chemins et dépendances.

## 5.4 Supervision

Évalue l'impact de : - Homelab Manager ; - services systemd associés
(proxy Docker, sauvegardes restic, scans Grype).

La supervision doit rester légère.

Ne recommande pas Prometheus, Grafana, Elasticsearch ou une autre
plateforme lourde sans démontrer un besoin réel et un intérêt
proportionné aux ressources disponibles.

------------------------------------------------------------------------

# 6. Audit de l'architecture Ansible

Examine l'ensemble du projet et non uniquement les fichiers les plus
visibles.

## 6.1 Organisation

Vérifie : - structure des répertoires ; - séparation des responsabilités
; - cohérence des noms ; - réutilisation des rôles ; - dépendances entre
rôles ; - variables globales et variables de rôles ; - handlers ; -
templates ; - fichiers statiques ; - secrets ; - fichiers inutilisés.

Évite les rôles artificiels qui n'apportent aucune valeur, mais aussi
les rôles trop volumineux regroupant des responsabilités sans rapport.

## 6.2 Playbooks

Analyse notamment : - `preflight.yml` ; - `site.yml` ; - `security.yml`
; - `docker.yml` ; - `monitoring.yml` ; - `cloudflare-tunnel.yml`.

Vérifie que les responsabilités sont explicites.

Identifie : - répétitions de tâches ; - dépendances implicites ; -
configurations contradictoires ; - variables définies à plusieurs
endroits ; - tâches exécutées inutilement ; - modifications non
maîtrisées de services existants.

## 6.3 Idempotence

Chaque rôle et playbook doit être idempotent. Une deuxième exécution ne
doit pas provoquer de modifications inutiles.

Vérifie notamment : - fichiers de configuration ; - utilisateurs et
groupes ; - permissions ; - paquets ; - services systemd ; - règles
firewall ; - montages ; - swap ; - Docker ; - Cloudflare Tunnel.

Analyse les tâches `shell` et `command`. Privilégie les modules Ansible
natifs lorsque possible.

## 6.4 Erreurs et résilience

Vérifie : - conditions `when` ; - assertions ; - préconditions ; -
handlers ; - notifications ; - dépendances ; - gestion des erreurs ; -
cohérence après échec ; - mécanismes de récupération.

Les opérations sensibles doivent avoir des contrôles adaptés. Une erreur
ne doit pas laisser le système dans un état incohérent.

## 6.5 Compatibilité Debian 13

Vérifie : - compatibilité des modules Ansible ; - existence des paquets
dans les dépôts utilisés ; - noms des services systemd ; - chemins ; -
paramètres de configuration ; - dépendances ; - comportements
spécifiques à la distribution.

------------------------------------------------------------------------

# 7. Responsabilités des services

Respecte strictement la répartition suivante.

## Ansible

Ansible gère principalement : - configuration système Debian ; -
sécurité ; - utilisateurs ; - SSH ; - firewall ; - paquets système ; -
services natifs ; - Docker Engine ; - Homelab Manager ; - Cloudflare
Tunnel.

## Coolify

Coolify conserve la gestion : - déploiements applicatifs ; - conteneurs
applicatifs qu'il administre ; - PostgreSQL ; - deux API NestJS ; -
sauvegardes PostgreSQL.

**Ne cherche pas à remplacer Coolify par Ansible.**

Ne crée pas une deuxième gestion des conteneurs applicatifs qui
entrerait en conflit avec Coolify.

## Cloudflare Tunnel

Vérifie : - fonctionnement comme service systemd ; - compte système
dédié si pertinent ; - permissions des fichiers de configuration et
credentials ; - privilèges nécessaires ; - démarrage automatique ; -
gestion des erreurs ; - journaux ; - services internes exposés.

Le tunnel doit exposer uniquement les services explicitement
nécessaires. N'ajoute pas d'ouverture de ports entrants sur la box pour
le remplacer.

------------------------------------------------------------------------

# 8. Maintenabilité et simplicité

La configuration doit être compréhensible et maintenable par un
administrateur système junior.

Vérifie : - lisibilité YAML ; - cohérence des noms ; - taille des
fichiers ; - séparation des responsabilités ; - duplication ; -
variables inutilisées ; - rôles inutilisés ; - dépendances inutiles ; -
commentaires ; - conventions Ansible ; - facilité d'ajout d'un nouveau
service.

Privilégie les solutions simples et natives.

Évite : - abstractions inutiles ; - collections superflues ; -
dépendances externes non justifiées ; - scripts Bash lorsque les modules
Ansible suffisent ; - configurations excessivement génériques ; -
mécanismes difficiles à déboguer.

Chaque choix architectural doit être justifié.

------------------------------------------------------------------------

# 9. Documentation obligatoire

La documentation doit permettre de comprendre le projet plusieurs mois
plus tard sans devoir relire tout le code.

Vérifie la documentation existante et identifie les manques.

## README.md

Doit présenter : - rôle du projet ; - architecture générale ; - matériel
; - services gérés ; - prérequis ; - installation d'Ansible ; -
configuration initiale ; - gestion des secrets ; - commandes principales
; - procédure d'exécution ; - précautions avant déploiement.

## docs/architecture.md

Doit expliquer : - architecture globale ; - responsabilités d'Ansible
; - responsabilités de Coolify ; - services natifs ; - dépendances ; -
organisation du stockage ; - flux réseau importants.

## docs/security.md

Doit documenter : - mécanismes de sécurité ; - SSH ; - firewall ; -
Docker et règles réseau ; - AppArmor ; - Fail2ban ; - Ansible Vault ; -
permissions ; - ports autorisés ; - limites connues.

## docs/maintenance.md

Doit expliquer : - mises à jour du serveur ; - mises à jour des
dépendances Ansible ; - exécution des playbooks ; - vérification des
services ; - consultation des logs ; - ajout d'un rôle ; - modification
d'une variable ; - diagnostic d'erreur ; - vérification de
l'idempotence.

## docs/operations.md

Doit documenter les opérations courantes : - état du serveur ; -
stockage ; - mémoire ; - firewall ; - SSH ; - Docker ; - Cloudflare
Tunnel ; - supervision.

## docs/recovery.md

Doit présenter des procédures concrètes de récupération : - perte de
connexion SSH ; - erreur de configuration firewall ; - échec d'un
playbook ; - service qui ne démarre plus ; - problème de stockage ; -
problème Docker ; - retour à une configuration précédente.

Les procédures doivent inclure les commandes nécessaires et les
précautions associées.

## docs/vulnerability-management.md

Doit documenter la démarche CVE : - sources officielles ; - outils de
scan ; - fréquence des contrôles ; - collecte des versions ; -
interprétation des rétroportages Debian ; - priorisation ; - traitement
et validation des correctifs.

## Commentaires dans le code

Les commentaires doivent expliquer pourquoi une configuration existe,
quel problème elle résout et quels sont ses impacts.

Évite les commentaires qui répètent simplement le nom de la tâche.

La documentation et les commentaires sont en français. Les noms de
fichiers, variables et identifiants techniques restent en anglais.

------------------------------------------------------------------------

# 10. Qualité et bonnes pratiques Ansible

Vérifie : - conventions Ansible ; - utilisation de `become` ; - handlers
; - variables ; - `defaults/main.yml` ; - `tasks/main.yml` ; - templates
Jinja2 ; - modules natifs ; - gestion des erreurs ; - secrets ; -
permissions ; - duplication ; - lisibilité.

Évalue l'intérêt de : - `ansible-lint` ; - validation YAML ; -
validation syntaxique ; - mode check ; - tests d'idempotence ; -
Molecule.

Ne rajoute pas un système de tests complexe uniquement pour respecter
une convention. Le niveau de qualité doit être professionnel et
proportionné à l'infrastructure.

------------------------------------------------------------------------

# 11. Contraintes impératives

1.  Ne réécris pas intégralement le projet avant l'audit.
2.  Ne supprime aucun fichier sans justification.
3.  Ne modifie aucun service applicatif géré par Coolify.
4.  Ne modifie pas les sauvegardes PostgreSQL gérées par Coolify.
5.  Ne change pas arbitrairement les adresses IP, ports ou chemins.
6.  Ne désactive jamais SSH ou le firewall sans mécanisme de validation
    et de récupération.
7.  N'ajoute pas de service sans justification.
8.  Ne multiplie pas les dépendances Ansible.
9.  Ne sacrifie pas les performances pour un gain de sécurité théorique
    négligeable.
10. Ne sacrifie pas la sécurité pour un gain de performance négligeable.
11. Ne considère pas que l'hébergement domestique dispense d'une
    politique de sécurité sérieuse.
12. Ne suppose pas qu'une configuration fonctionne parce qu'elle est
    syntaxiquement correcte.
13. Ne déclare pas une CVE applicable sans vérifier le logiciel, la
    version, le statut Debian et les conditions d'exploitation.
14. Ne présente pas une analyse CVE incomplète comme exhaustive.
15. Ne divulgue jamais les secrets découverts dans le rapport. Masque
    leur valeur et signale uniquement leur emplacement et le risque.
16. Ne lance aucune opération destructive ou susceptible d'interrompre
    un service pendant la phase d'audit.
17. Avant toute modification, analyse les conséquences sur les services
    en fonctionnement.
18. En cas d'information manquante, demande-la au lieu d'inventer.

------------------------------------------------------------------------

# 12. Méthode d'audit obligatoire

Procède par phases. Ne passe pas à la phase suivante sans respecter les
validations demandées.

## Phase 1 --- Inventaire

Examine tous les fichiers du projet.

Identifie : - fichiers présents ; - rôles ; - playbooks ; - variables
; - dépendances ; - templates ; - secrets (sans en afficher le contenu)
; - fichiers inutilisés ; - outils et versions nécessaires.

Comprends l'architecture avant de tirer des conclusions. Ne te limite
pas au README.

## Phase 2 --- Audit technique et CVE

Examine les fichiers individuellement et réalise l'analyse de sécurité,
de performance, d'architecture, de maintenabilité et de documentation.

Pour chaque problème, indique : - fichier ou composant concerné ; -
tâche, variable ou version concernée ; - constat vérifié ; - risque ; -
impact potentiel sur le serveur ; - correction recommandée ; - priorité
; - source ou preuve.

Distingue clairement : - problème avéré ; - risque potentiel ; -
amélioration facultative ; - point impossible à vérifier avec les
éléments fournis.

Pour les CVE, indique les sources, dates de consultation, versions
vérifiées et limites de couverture.

## Phase 3 --- Évaluation

Attribue une note sur 10 et justifie chaque note :

  Domaine                  Note
  ---------------------- ------
  Sécurité Debian           /10
  Sécurité SSH              /10
  Firewall et réseau        /10
  Sécurité Docker           /10
  Gestion des secrets       /10
  Gestion des CVE           /10
  Performances              /10
  Architecture Ansible      /10
  Idempotence               /10
  Maintenabilité            /10
  Documentation             /10
  Fiabilité globale         /10

Ne donne pas de note artificiellement élevée en l'absence de preuves.

## Phase 4 --- Plan de correction

Classe les problèmes : - **CRITIQUE** : vulnérabilité ou risque majeur
; - **ÉLEVÉE** : problème important de sécurité ou stabilité ; -
**MOYENNE** : défaut technique ou architectural ; - **FAIBLE** :
amélioration de lisibilité ou documentation.

Présente un plan progressif, avec dépendances, risques et ordre
recommandé.

## Phase 5 --- Corrections après validation

Après présentation de l'audit, propose les modifications nécessaires.

**Ne modifie aucun fichier sans ma validation préalable du plan de
correction.**

Pour chaque modification : - explique le problème ; - explique la
solution ; - liste les fichiers concernés ; - présente le contenu
complet des fichiers modifiés ; - explique les conséquences ; - indique
les tests ; - prévois une méthode de retour arrière adaptée.

Évite de tout modifier en une seule opération. Traite d'abord les
risques critiques et élevés.

## Phase 6 --- Validation finale

Après les corrections, vérifie : - syntaxe YAML ; - syntaxe Ansible ; -
dépendances ; - idempotence ; - cohérence des variables ; - permissions
; - handlers ; - services systemd ; - règles firewall ; - sécurité
Docker ; - documentation ; - traitement des CVE prioritaires.

Prévois notamment : - `ansible-playbook --syntax-check` ; -
`ansible-lint` ; - `ansible-playbook --check --diff` lorsque pertinent
; - une deuxième exécution pour contrôler l'idempotence ; -
vérifications directement sur Debian 13 ; - contrôles des services et
ports réellement actifs.

Le mode check ne garantit pas que toutes les modifications
fonctionneront réellement. Adapte les tests aux risques de chaque rôle.

------------------------------------------------------------------------

# 13. Format du rapport final

Structure le rapport dans cet ordre :

1.  Résumé exécutif.
2.  Périmètre et limites de l'audit.
3.  Date de l'audit et sources consultées.
4.  Présentation de l'architecture actuelle.
5.  Points forts.
6.  Problèmes de sécurité.
7.  Résultats de l'audit CVE.
8.  Problèmes de performance.
9.  Problèmes architecturaux.
10. Problèmes de maintenabilité.
11. Problèmes de documentation.
12. Tableau des risques et priorités.
13. Notes détaillées sur 10.
14. Architecture cible recommandée.
15. Plan de correction progressif.
16. Fichiers à modifier.
17. Tests et procédures de validation.
18. Documentation à compléter.
19. Conclusion sur la qualité globale.

Le rapport CVE doit inclure un tableau avec les identifiants, versions,
sévérités, statuts Debian, expositions, risques réels, corrections et
liens vers les sources.

------------------------------------------------------------------------

# 14. Principes de décision

Pour chaque recommandation :

**Sécurité :** réduire un risque concret et vérifiable.

**Performance :** préserver les ressources limitées du Dell OptiPlex.

**Simplicité :** privilégier la solution la plus simple qui répond
correctement au besoin.

**Maintenabilité :** permettre à un administrateur de comprendre et
modifier la configuration sans architecture disproportionnée.

**Documentation :** rendre les décisions techniques compréhensibles sans
devoir analyser tout le code.

**Fiabilité :** éviter qu'une erreur de configuration provoque une perte
d'accès ou une interruption inutile.

Privilégie les solutions éprouvées, compatibles avec Debian 13 et
adaptées à un homelab domestique.

------------------------------------------------------------------------

# 15. Consigne de démarrage

Je souhaite un audit réellement approfondi, pas une revue superficielle.

**Commence uniquement par la phase 1 et la phase 2 : inventaire et
audit.**

Ne modifie aucun fichier. Ne lance aucune opération destructive. Ne
déploie aucun correctif. Ne génère pas une nouvelle architecture avant
d'avoir compris l'existant.

Présente-moi le diagnostic détaillé, les preuves, les risques, les
résultats CVE et les informations manquantes.

Si tu as besoin de commandes exécutées sur le serveur pour vérifier les
versions, l'exposition réseau ou l'état réel des services, fournis une
liste claire de commandes en lecture seule à exécuter. Explique à quoi
sert chaque commande et demande-moi les résultats.

Attends ma validation explicite avant de passer aux corrections.

**Résultat attendu : un projet Ansible adapté à mon Dell OptiPlex 3060,
sécurisé face aux vulnérabilités connues, performant, stable, simple à
comprendre, maintenable et entièrement documenté.**

# Sécurité

## Périmètre

Ansible gère SSH, AppArmor, UFW, Fail2ban, Docker, l'installation initiale
de Coolify, Cockpit, PCP, Beszel Agent et Cloudflare Tunnel. Coolify reste
responsable de PostgreSQL,
des applications, des conteneurs applicatifs et des sauvegardes.

## SSH

- utiliser une clé Ed25519 dédiée ;
- conserver une session SSH existante pendant toute modification ;
- valider l’accès depuis une seconde session avant de désactiver
  l’authentification par mot de passe ;
- vérifier les clés hôte avec `sudo sshd -t` ;
- limiter les connexions avec `AllowUsers`.

Ne pas désactiver PasswordAuthentication tant qu’une connexion par clé
n’a pas été validée indépendamment.

## Pare-feu

UFW doit rester la couche hôte. Les ports publiés par Docker peuvent
contourner UFW ; `DOCKER-USER` limite les publications au réseau `admin_cidr`.
Vérifier cette politique avec `docker ps`, `docker network inspect` et
`iptables -S DOCKER-USER`.

Ne pas publier PostgreSQL ou Redis sur Internet ou sur le LAN. Les interfaces
Coolify et Beszel sont accessibles uniquement depuis `admin_cidr`. Le script
officiel Coolify s'exécute en root et modifie Docker ; le mode `--check` ne
simule pas cette installation.

## Docker

- désactiver l’accès du démon en TCP ;
- ne pas ajouter `alex` au groupe docker ;
- considérer le groupe docker comme un accès pratiquement équivalent
  à root ;
- limiter les journaux des conteneurs ;
- conserver `live-restore` uniquement après validation avec Coolify.

## AppArmor et Fail2ban

AppArmor doit rester actif sauf erreur démontrée. Les profils par défaut
doivent être contrôlés en mode enforce ou complain avant toute hypothèse
sur leur efficacité.

Fail2ban est limité au journal SSH avec des seuils raisonnables. Le LAN
d’administration doit être ajouté à `fail2ban_ignoreip`.

## Secrets

Les secrets sont conservés dans `inventory/group_vars/all/vault.yml`,
chiffre avec Ansible Vault et exclu de Git.

Ne jamais afficher les secrets dans les sorties, les journaux, les
captures d’écran ou la documentation.

## Élévation de privilèges

Le compte `alex` appartient au groupe `sudo`. La règle du projet exige une
authentification par mot de passe ; ne pas ajouter de règle `NOPASSWD`.
Ansible demande le mot de passe au lancement avec `--ask-become-pass`.

Au premier provisionnement, `scripts/first-run.sh` lance
`playbooks/bootstrap.yml`, qui se connecte comme `alex`, utilise temporairement
`su` avec le mot de passe root saisi à l’exécution, installe `sudo` et ajoute
`alex` au groupe correspondant. Le script réinitialise la connexion SSH avant
de lancer le préflight, qui demande le mot de passe sudo d’`alex`. Une session
SSH initiale et le mot de passe root restent nécessaires.

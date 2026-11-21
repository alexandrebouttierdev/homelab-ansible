# Instructions pour les assistants IA

## Présentation du projet

Ce dépôt provisionne un serveur Debian 13 avec Ansible. Consultez
`README.md` pour les commandes, `docs/ARCHITECTURE.md` pour les frontières
de responsabilité, et `docs/SECURITY.md` pour les règles de sécurité.

Ansible gère l’hôte Debian, SSH, le firewall, AppArmor, Fail2ban, Docker
Engine, Cockpit/PCP et, lorsqu’ils sont activés, Beszel Agent et
Cloudflare Tunnel. Coolify gère les déploiements applicatifs, PostgreSQL,
les API NestJS et leurs sauvegardes. Ne faites pas gérer ces applications
ou sauvegardes par Ansible.

## Règles impératives

- Répondez en français, sauf demande contraire. Conservez en anglais les
  noms de fichiers, variables et identifiants techniques.
- Examinez l’état réel et les fichiers concernés avant de proposer ou
  modifier une configuration. Ne déduisez pas l’état du serveur à partir
  de la documentation seule.
- Le dépôt décrit un Dell OptiPlex 3060, mais la cible Ansible et ses
  ressources doivent être vérifiées avant toute conclusion matérielle.
- Ne divulguez jamais de secrets. Ne lisez ni n’imprimez le contenu du
  Vault ; utilisez `no_log: true` pour les tâches manipulant des secrets.
- Ne déployez pas de changement sur le serveur, ne redémarrez pas de
  service et ne modifiez pas SSH, UFW ou les règles Docker sans demande
  explicite de l’utilisateur.
- Avant un changement sensible, expliquez son effet, les risques de
  coupure et le retour arrière. Préservez une session SSH de secours ;
  n’activez pas le durcissement SSH sans vérification indépendante de la
  connexion par clé.
- Ne formatez pas de disque, ne déplacez pas de données et ne modifiez
  pas les chemins persistants sans vérification des dépendances et accord.
- Ne publiez pas de ports entrants pour remplacer Cloudflare Tunnel.
- Ne touchez pas aux conteneurs applicatifs, aux services Coolify, à
  PostgreSQL ou à ses sauvegardes.
- Préférez les modules Ansible natifs aux commandes shell. Toute commande
  `command`/`shell` doit être en lecture seule ou clairement idempotente,
  avec `changed_when` adapté.
- Ne videz jamais une chaîne firewall partagée et ne remplacez pas les
  règles Docker/UFW existantes sans analyse de leur effet.
- Gardez la solution proportionnée à un serveur personnel ; n’ajoutez
  pas de services, dépendances ou abstractions sans bénéfice concret.

## Modifications et validation

- Respectez l’organisation existante : `playbooks/`, `roles/`,
  `inventory/`, `docs/`.
- Les valeurs propres à l’hôte vont dans `inventory/group_vars/all/main.yml`;
  les secrets vont dans Ansible Vault, jamais dans un fichier versionné
  en clair.
- Documentez en français les décisions importantes dans `docs/`.
- Après une modification, exécutez au minimum :

  ```bash
  ./scripts/static-checks.sh
  ```

- Pour une modification de privilèges, SSH, firewall ou Docker, ajoutez
  les validations ciblées nécessaires. Le mode `--check` n’est pas une
  preuve suffisante du bon fonctionnement sur l’hôte.
- Le premier bootstrap utilise `playbooks/bootstrap.yml` avec
  `--ask-become-pass` et le mot de passe root ; ensuite, les playbooks
  utilisent sudo avec demande du mot de passe de `alex`.


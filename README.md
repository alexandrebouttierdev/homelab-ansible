<div align="center">
  <img src="docs/images/homelab-banner.svg" alt="Bannière homelab-ansible avec les logos Debian, Ansible, Docker, NestJS et Homelab Manager, et un résumé des composants système, sécurité, conteneurs, supervision, réseau et applications." width="100%">
  <br>
  <a href="https://github.com/alexandrebouttierdev/homelab-ansible/actions/workflows/ansible-checks.yml">
    <img src="https://github.com/alexandrebouttierdev/homelab-ansible/actions/workflows/ansible-checks.yml/badge.svg?branch=dev" alt="Ansible checks">
  </a>
  <img src="https://img.shields.io/badge/Ansible-Core%202.17%2B-111827?logo=ansible&logoColor=white" alt="Ansible Core 2.17+">
  <img src="https://img.shields.io/badge/Debian-13-A81D33?logo=debian&logoColor=white" alt="Debian 13">
  <img src="https://img.shields.io/badge/Deployment-manual-334155" alt="Manual deployment">
  <br><br>
  <strong>Provisionner un serveur domestique sans transformer son administration en usine à gaz.</strong>
  <br>
  Debian · sécurité · Docker Engine · supervision · Cloudflare Tunnel
  <br><br>
  <a href="#-démarrage-rapide">Démarrage rapide</a> ·
  <a href="#-architecture">Architecture</a> ·
  <a href="#-sécurité">Sécurité</a> ·
  <a href="#-documentation">Documentation</a>
</div>

---

## À propos

`homelab-ansible` automatise la configuration système d’un homelab sous
**Debian 13 (Trixie)**. Le projet vise une infrastructure simple à comprendre,
reproductible et adaptée aux ressources limitées d’un serveur personnel.

Ansible prépare l’hôte et installe Coolify ; **Coolify garde la responsabilité
des déploiements applicatifs**, de PostgreSQL et de leurs sauvegardes. Ansible
ne touche pas aux données applicatives.

> **Déploiement manuel uniquement.** GitHub Actions contrôle le dépôt, mais ne
> se connecte jamais au serveur et ne déclenche aucun changement en production.

## ✨ Ce que le projet configure

| Domaine | Composants |
| --- | --- |
| Socle système | Debian, paquets de base, fuseau horaire français (Europe/Paris), Chrony, journald, mises à jour de sécurité |
| Accès et sécurité | compte administrateur, SSH, AppArmor, UFW, Fail2ban, paramètres noyau |
| Conteneurs | Docker Engine, Compose, Buildx, Coolify, rotation des logs, règles réseau |
| Supervision | [Homelab Manager](https://github.com/alexandrebouttierdev/homelab-manager) : métriques, journaux, alertes, sauvegardes restic, scans Grype |
| Optionnels | Cloudflare Tunnel, activé explicitement |

## 🏗️ Architecture

<p align="center">
  <img src="docs/images/homelab-architecture.svg" alt="Schéma du homelab : Internet passe par OPNsense avec CrowdSec et le switch TP-Link vers le poste Fedora et un Dell OptiPlex 3060 sous Debian 13 (Intel Core i5-8500, 16 Go RAM, SSD NVMe 256 Go, HDD 1 To), avec Homelab Manager, Docker, Coolify, PostgreSQL, Cloudflare Tunnel et sauvegardes." width="100%">
</p>

### Frontières de responsabilité

- **Ansible** : Debian, SSH, firewall, Docker Engine, installation initiale de
  Coolify, Homelab Manager et services natifs.
- **Coolify** : déploiements applicatifs, conteneurs gérés par Coolify, PostgreSQL,
  API NestJS et sauvegardes PostgreSQL.
- **Hors périmètre** : configuration d’OPNsense et du switch, VLAN, partitionnement
  du HDD et déploiement des applications.

> **Réseau Docker :** les ports publiés par Docker peuvent contourner les règles
> UFW habituelles. Le rôle Docker filtre ces ports avec `DOCKER-USER` et les
> limite au réseau d’administration et aux réseaux Docker internes. Inspecter
> les ports et les chaînes effectives avant toute exposition. Ne pas publier
> PostgreSQL ou Redis sur Internet.

## 🚀 Démarrage rapide

### 1. Prérequis

**Sur le serveur Debian**

- Debian 13 installé, avec les comptes `root` et `alex` ;
- SSH actif et clé publique du poste de contrôle autorisée pour `alex` ;
- accès réseau stable et adresse IP connue ;
- mot de passe root défini pour le bootstrap initial.

**Sur le poste de contrôle**

- Python 3 et Ansible Core ;
- accès SSH par clé à `alex` ;
- collections Ansible requises par [`requirements.yml`](requirements.yml).

### 2. Préparer Ansible (Fedora)

```bash
sudo dnf install python3 python3-pip
python3 -m venv ~/.venvs/homelab-ansible
source ~/.venvs/homelab-ansible/bin/activate
python -m pip install ansible-core ansible-lint yamllint

cd /chemin/vers/homelab-ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Préparer l’inventaire et la clé

Vérifier l’adresse, l’utilisateur et le chemin de clé dans
[`inventory/hosts.yml`](inventory/hosts.yml). Les valeurs du dépôt sont des
exemples propres à l’environnement ; adaptez-les à la machine ciblée.

La clé publique locale est lue depuis
`~/.ssh/homelab_ed25519.pub`. Pour créer la paire et installer la clé :

```bash
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/homelab_ed25519
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub alex@192.168.1.24
ssh -i ~/.ssh/homelab_ed25519 alex@192.168.1.24
```

### 4. Bootstrap initial et préflight automatiques

Sur une Debian fraîche, Ansible installe `sudo` et ajoute `alex` au groupe
administrateur, réinitialise la connexion SSH, puis lance le préflight.
Lancer le script depuis le dépôt :

```bash
./scripts/first-run.sh
```

Le script demande d’abord le mot de passe root pour le bootstrap, puis le mot
de passe Linux d’`alex` pour le préflight. Ces mots de passe sont demandés à
l’exécution et ne sont pas stockés dans le dépôt. La nouvelle connexion SSH
est ouverte automatiquement entre les deux étapes.

> Ansible ne peut pas installer Debian, activer SSH ou créer le premier accès
> réseau : la cible doit déjà être joignable par SSH.

### 5. Préflight et déploiement

```bash
ansible homelab -m ping

# Prévisualiser les changements
ansible-playbook playbooks/site.yml --check --diff --ask-become-pass

# Appliquer la configuration
ansible-playbook playbooks/site.yml --ask-become-pass

# Vérifier les services après déploiement
ansible-playbook playbooks/verify.yml --ask-become-pass
```

Le playbook exécute le script officiel de Coolify en root lors de sa première
installation. Il configure le pool réseau Docker `172.20.0.0/14` (sous-réseaux
`/24`) pour éviter le chevauchement avec les futurs VLAN `10.0.x.x`, puis
installe Coolify sous `/data/coolify`. Le script n’est pas relancé si
`/data/coolify/source/.env` existe déjà.

Après le déploiement, ouvre `http://IP_LOCALE_SERVEUR:8000` depuis le réseau
d’administration et crée le compte initial Coolify. Les ports `8000`, `6001`,
`6002`, `80` et `443` sont autorisés uniquement depuis `admin_cidr` ; aucune
redirection Internet n’est créée. Le script officiel est téléchargé depuis
`cdn.coollabs.io` et exécuté avec les privilèges root : Ansible ne peut pas
simuler cette installation en mode `--check`.

Homelab Manager est installé par Ansible avec le site (port `9090`, le `8080`
amont étant pris par le proxy Coolify). Dès le déploiement, ouvrez
`http://IP_LOCALE_SERVEUR:9090` depuis le réseau d’administration : le compte
initial est `admin` / `admin` et l’interface impose aussitôt un nouveau mot de
passe. Voir [Déploiement applicatif](docs/DEPLOIEMENT-APPLICATIONS.md).

Lors d’une première prévisualisation, les règles UFW, le démarrage des
services installés par le playbook et la configuration du swap peuvent ne pas
être vérifiés si leurs paquets, services ou fichiers n’existent pas encore :
Ansible simule les créations sans produire les exécutables, unités systemd ou
fichiers. Ces étapes seront effectuées pendant l’application réelle du playbook.
Le rôle Docker installe aussi sa clé APT, écrit son dépôt officiel dans
`/etc/apt/sources.list.d/docker.sources`, actualise l’index puis vérifie que
`docker-ce` est disponible avant l’installation.

Conserver une session SSH de secours. Avant d’activer ou de changer le
durcissement SSH, tester l’authentification par clé dans une deuxième session.
Le mode `--check` ne remplace pas un test réel.

## 🔐 Secrets et configuration

Les paramètres non sensibles sont dans
[`inventory/group_vars/all/main.yml`](inventory/group_vars/all/main.yml).
Ne commitez jamais un token, mot de passe ou secret en clair.

```bash
cp inventory/group_vars/all/vault.yml.example \
  inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml
ansible-vault edit inventory/group_vars/all/vault.yml
```

Le fichier `vault.yml` est exclu de Git. Les variables sensibles sont masquées
par les tâches Ansible concernées. N’ajoutez pas de secrets réels au fichier
d’exemple.

| Variable / option | Valeur initiale | Rôle |
| --- | --- | --- |
| `ssh_hardening_enabled` | `true` | Durcissement SSH, protégé par des assertions |
| `ufw_enabled` | `true` | Pare-feu local |
| `fail2ban_enabled` | `true` | Protection des tentatives SSH |
| `docker_add_admin_user` | `false` | Évite d’accorder à `alex` l’accès root via Docker |
| `coolify_enabled` | `true` | Installation initiale Coolify par Ansible |
| `homelab_manager_enabled` | `true` | Homelab Manager installé depuis une release épinglée (SHA-256) |
| `homelab_manager_*_enabled` | `true` | Modules sauvegardes, vulnérabilités, nettoyage du journal, alimentation |
| `cloudflared_enabled` | `false` | À activer après ajout du token au Vault |

## 🧪 Vérifications automatiques

À chaque push ou pull request vers `dev` ou `main`, GitHub Actions lance les
contrôles statiques du dépôt :

- recherche de secrets évidents ;
- validation YAML et syntaxe des playbooks ;
- validation de l’inventaire ;
- `ansible-lint`.

L’action n’a que les permissions de lecture du dépôt. Elle ne contient pas de
secrets de déploiement et n’accède pas au réseau du homelab.

Pour lancer les mêmes contrôles localement :

```bash
./scripts/static-checks.sh
```

## 📚 Documentation

| Guide | Contenu |
| --- | --- |
| [Architecture](docs/ARCHITECTURE.md) | Composants, réseau et séparation Ansible/Coolify |
| [Sécurité](docs/SECURITY.md) | SSH, firewall, Docker, AppArmor, secrets |
| [Déploiement applicatif](docs/DEPLOIEMENT-APPLICATIONS.md) | Coolify, Homelab Manager et Cloudflare |
| [Sauvegardes](docs/SAUVEGARDES.md) | Sauvegardes PostgreSQL et données Coolify |
| [Maintenance](docs/MAINTENANCE.md) | Mises à jour, commandes et idempotence |
| [Exploitation](docs/OPERATIONS.md) | Vérifications système et services |
| [Récupération](docs/RECOVERY.md) | SSH, firewall, Docker et incidents |
| [Gestion des vulnérabilités](docs/VULNERABILITY-MANAGEMENT.md) | Sources et procédure CVE |
| [Instructions pour les assistants IA](AGENTS.md) | Contexte et règles à respecter dans ce dépôt |

## 🤖 Assistants de développement

Les consignes communes sont dans [`AGENTS.md`](AGENTS.md). Les points d’entrée
pour Claude Code et Cursor sont dans [`CLAUDE.md`](CLAUDE.md) et
[`.cursor/rules/homelab-ansible.mdc`](.cursor/rules/homelab-ansible.mdc).

## ⚠️ Limites et précautions

- Ce dépôt installe Coolify mais **ne gère pas** ses applications ni les
  sauvegardes PostgreSQL.
- Il ne formate aucun disque et ne déplace aucune donnée persistante.
- UFW seul ne suffit pas pour conclure qu’un port Docker est filtré.
- Le groupe `docker` est pratiquement équivalent à root ; seul le proxy
  restreint de Homelab Manager (`homelab-docker-proxy`, routes GET en liste
  blanche) en est membre.
- Toute exposition d’un service via Cloudflare doit être explicitement définie
  et protégée, par exemple avec Cloudflare Access pour une interface d’administration.
- Vérifier l’inventaire, les variables et l’état réel du serveur avant chaque
  exécution sur une machine de production.

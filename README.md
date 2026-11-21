# provision-serveur — Homelab Debian 13 (Ansible)

Provisionnement automatisé, sécurisé et idempotent d'un **Dell OptiPlex 3060** sous **Debian 13 (Trixie)** pour héberger **Coolify**, **PostgreSQL** et des APIs **NestJS** (conteneurisés). Le contrôleur Ansible reste le **Mac Studio**.

---

## 1. Architecture générale

```text
provision-serveur/
├── ansible.cfg
├── AGENTS.md                         # Consignes communes aux assistants IA
├── CLAUDE.md                         # Point d'entrée Claude Code
├── .cursor/rules/provision-serveur.mdc
├── requirements.yml
├── README.md
├── scripts/static-checks.sh          # Contrôles locaux (pas de prod)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOIEMENT-APPLICATIONS.md
│   ├── SAUVEGARDES.md
│   ├── SECURITY.md
│   ├── MAINTENANCE.md
│   ├── OPERATIONS.md
│   ├── RECOVERY.md
│   └── VULNERABILITY-MANAGEMENT.md
├── inventory/
│   ├── hosts.yml
│   └── group_vars/all/
│       ├── main.yml                  # Variables non secrètes
│       └── vault.yml.example         # Modèle → vault.yml (Vault)
├── playbooks/
│   ├── bootstrap.yml
│   ├── preflight.yml
│   ├── site.yml
│   ├── security.yml
│   ├── docker.yml
│   ├── monitoring.yml
│   ├── cloudflare-tunnel.yml
│   └── verify.yml
└── roles/
    ├── base, admin_user, apparmor, ssh, firewall, fail2ban
    ├── sysctl, swap, docker, cockpit, beszel_agent, cloudflared, verify
```

Les assistants IA doivent commencer par lire `AGENTS.md`. Des fichiers
d’intégration Claude Code (`CLAUDE.md`) et Cursor
(`.cursor/rules/provision-serveur.mdc`) renvoient aux mêmes règles de
projet pour garder un contexte cohérent entre outils.

**Natif Debian :** Docker Engine, Cockpit, PCP (+ pmlogger), Beszel Agent, cloudflared, Fail2ban, AppArmor, UFW.  
**Conteneurs (Coolify) :** Coolify, PostgreSQL, NestJS (+ Redis/MariaDB éventuels).  
**Hors scope Ansible :** OPNsense, switch, partitionnement HDD, sauvegardes PostgreSQL (Coolify).

Détails : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 2. Prérequis

### Matériel / OS serveur

- Debian 13 minimale (sans GUI)
- Compte admin `alex` avec un mot de passe défini
- IP LAN fixe (DHCP réservé) — réseau actuel `192.168.1.0/24`
- SSH activé et clé publique du Mac Studio installée pour `alex`
- Mot de passe root défini pour le bootstrap initial avec `su`

### Poste de contrôle (macOS)

- Python 3
- Ansible Core ≥ 2.17
- Collections Galaxy (`requirements.yml`)
- Clé SSH Ed25519 dédiée

---

## 3. Installation d'Ansible sur macOS

```bash
# Option recommandée : venv dédié
python3 -m venv ~/.venvs/ansible
source ~/.venvs/ansible/bin/activate
pip install 'ansible-core>=2.17' ansible-lint yamllint

cd /chemin/vers/provision-serveur
ansible-galaxy collection install -r requirements.yml
```

Vérifier :

```bash
ansible --version
ansible-galaxy collection list | grep -E 'posix|general'
```

---

## 4. Configuration de l'inventaire

Éditer `inventory/hosts.yml` :

```yaml
ansible_host: "192.168.1.100"   # IP réelle du Dell
ansible_user: "alex"
ansible_ssh_private_key_file: "~/.ssh/homelab_ed25519"
```

Ne pas laisser `CHANGE_ME` (le preflight échoue sinon).

---

## 5. Configuration des clés SSH

```bash
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/homelab_ed25519
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub alex@IP_SERVEUR
ssh -i ~/.ssh/homelab_ed25519 alex@IP_SERVEUR
```

La variable `admin_public_key_path` pointe par défaut vers `~/.ssh/homelab_ed25519.pub`.

---

## 6. Gestion des secrets (Ansible Vault)

Les secrets vivent dans `inventory/group_vars/all/vault.yml` (gitignoré).  
**Important :** le fichier doit être sous `group_vars/all/` pour s'appliquer au groupe `all` (un `group_vars/vault.yml` à la racine viserait un groupe nommé `vault` et ne serait pas chargé).

```bash
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml
ansible-vault edit inventory/group_vars/all/vault.yml
```

Variables secrètes :

| Variable | Usage |
| --- | --- |
| `cloudflared_tunnel_token` | Token Cloudflare Tunnel |
| `beszel_agent_key` | Clé publique Hub Beszel |
| `beszel_agent_token` / `beszel_hub_url` | Optionnels (mode sortant) |

Mot de passe Vault : ne jamais le committer (fichier `.vault_password` gitignoré).

---

## 7. Préparation initiale de Debian 13

Ansible automatise l’installation de `sudo` et l’ajout de `alex` au groupe
administrateur. Debian doit toutefois être accessible une première fois :

1. installer Debian 13 et créer le compte `alex` ;
2. définir un mot de passe root et un mot de passe pour `alex` ;
3. activer SSH et installer la clé publique de contrôle pour `alex` ;
4. réserver l’adresse IP du serveur ;
5. lancer le bootstrap ci-dessous depuis le Mac Studio. Le mot de passe root est
   demandé interactivement, jamais enregistré dans le dépôt ;
6. ouvrir une nouvelle session SSH pour que l’appartenance au groupe sudo soit
   prise en compte.

```bash
ansible-playbook playbooks/bootstrap.yml --ask-become-pass
```

Le compte `alex` doit déjà pouvoir se connecter par SSH. Ansible ne peut pas
installer Debian, activer SSH ou créer son premier accès réseau depuis une
machine qui n’est pas encore joignable.

Ce dépôt ne formate aucun disque et ne touche pas à OPNsense / au switch.

---

## 8. Preflight

```bash
cd /chemin/vers/provision-serveur
ansible homelab -m ping
ansible-playbook playbooks/preflight.yml --ask-become-pass
```

Contrôle : Debian 13, espace disque, IP renseignée, Python 3, résumé matériel.
Après le bootstrap, `--ask-become-pass` demande le mot de passe Linux d’`alex`
pour les tâches privilégiées.

---

## 9. Provisionnement

```bash
# Prévisualisation avant toute modification sensible
ansible-playbook playbooks/site.yml --check --diff --ask-become-pass

# Passage 1 — socle (SSH hardening / Beszel / Cloudflare encore off)
ansible-playbook playbooks/site.yml --ask-become-pass
```

Ordre des rôles dans `site.yml` : base → admin_user → apparmor → ssh → firewall → fail2ban → sysctl → swap → docker → cockpit → beszel_agent → cloudflared → verify.

---

## 10. Lancement par tags / playbooks ciblés

```bash
ansible-playbook playbooks/security.yml --ask-become-pass
ansible-playbook playbooks/docker.yml --ask-become-pass
ansible-playbook playbooks/monitoring.yml --ask-become-pass --ask-vault-pass
ansible-playbook playbooks/cloudflare-tunnel.yml --ask-become-pass --ask-vault-pass
ansible-playbook playbooks/verify.yml --ask-become-pass

ansible-playbook playbooks/site.yml --tags "sysctl,docker" --ask-become-pass
ansible-playbook playbooks/site.yml --tags "security" --ask-become-pass
ansible-playbook playbooks/site.yml --tags "monitoring,cloudflared" --ask-become-pass --ask-vault-pass
```

---

## 11. Variables personnalisables

Fichier : `inventory/group_vars/all/main.yml`

| Variable | Défaut | Notes |
| --- | --- | --- |
| `admin_cidr` | `192.168.1.0/24` | LAN autorisé SSH/Cockpit |
| `ssh_hardening_enabled` | `true` | Actif après prérequis clé valide |
| `ufw_enabled` / `fail2ban_enabled` / `apparmor_enabled` | `true` | |
| `swap_file_size_mb` | `2048` | |
| `vm_swappiness` | `10` | |
| `docker_add_admin_user` | `false` | docker ≈ root |
| `docker_userland_proxy` | `false` | |
| `cockpit_install` / `pcp_pmlogger_enabled` | `true` | Historique PCP |
| `beszel_agent_enabled` | `false` | Nécessite Vault |
| `beszel_hub_cidr` | `""` | CIDR Docker du Hub si UFW |
| `cloudflared_enabled` | `false` | Nécessite Vault |

---

## 12. Procédure de vérification

```bash
ansible-playbook playbooks/verify.yml --ask-become-pass
```

Contrôles manuels utiles :

```bash
ssh -i ~/.ssh/homelab_ed25519 alex@IP_SERVEUR
sudo systemctl status docker ssh fail2ban cockpit.socket pmlogger
sudo ufw status verbose
sudo docker info
# Si activés :
sudo systemctl status beszel-agent cloudflared-homelab
sudo ls -l /etc/cloudflared/tunnel.token   # doit être 0640 root:cloudflared
```

Contrôles **locaux** (sans toucher le serveur) :

```bash
./scripts/static-checks.sh
```

---

## 13. Procédure de retour arrière

| Action | Retour arrière |
| --- | --- |
| Hardening SSH | `ssh_hardening_enabled: false` puis `ansible-playbook playbooks/security.yml --ask-become-pass` (supprime le drop-in) |
| UFW | `sudo ufw disable` en session console/SSH déjà ouverte |
| cloudflared | `cloudflared_enabled: false` + playbook tunnel, ou `systemctl disable --now cloudflared-homelab` |
| Beszel | `beszel_agent_enabled: false` + `playbooks/monitoring.yml` |
| Docker daemon.json | Restaurer une copie / retirer les options puis `systemctl restart docker` |
| Swap | Ne pas supprimer `/swapfile` à chaud sans `swapoff` manuel |

En cas de lock-out SSH : accès physique / IPMI absent sur ce SFF → **toujours** valider une 2ᵉ session avant `ssh_hardening_enabled: true`.

---

## 14. Points de sécurité importants

- Groupe `docker` ≈ root → non accordé à `alex` par défaut ; Beszel l'utilise pour les métriques conteneurs.
- UFW ≠ filtre fiable des ports publiés Docker ; ne pas exposer Postgres/Redis ; s'appuyer sur OPNsense + Tunnel.
- Token Cloudflare via fichier `--token-file` (pas dans la ligne de commande `ps`).
- Secrets uniquement dans Vault ; jamais dans Git.
- Pas de port entrant pour Cloudflare Tunnel.
- Cockpit limité à `admin_cidr` ; UI Coolify derrière Cloudflare Access si publiée.
- IPv6 **non** désactivé.
- HDD 1 To : hors automatisation (pas de `fstab`/formatage automatique hors swapfile).

---

## 15. Fonctionnalités non gérées par Ansible

- Installation / mises à jour Coolify et apps
- Sauvegardes PostgreSQL (Coolify) — voir [`docs/SAUVEGARDES.md`](docs/SAUVEGARDES.md)
- OPNsense, VLANs switch, Livebox
- Partitionnement / montage du HDD 1 To
- Certificats applicatifs (gérés via Cloudflare / Coolify)
- Ansible installé en permanence sur le serveur (contrôleur = Mac Studio)

---

## Checklist de mise en service progressive

1. Inventaire + clé SSH + preflight  
2. `site.yml` avec `ssh_hardening_enabled/beszel/cloudflared = false`  
3. Tester SSH par clé dans une **nouvelle** session  
4. `ssh_hardening_enabled: true` → `security.yml`  
5. Installer Coolify ([`docs/DEPLOIEMENT-APPLICATIONS.md`](docs/DEPLOIEMENT-APPLICATIONS.md))  
6. Renseigner Vault → activer Beszel / cloudflared → relancer les playbooks concernés  

Ces playbooks ne doivent **pas** être exécutés depuis un agent non contrôlé sur la machine de production sans validation humaine.

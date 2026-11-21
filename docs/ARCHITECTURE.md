# Architecture technique & choix de conception

Serveur cible : **Dell OptiPlex 3060** (Intel Core i5-8500, 16 Go RAM, SSD NVMe 256 Go + HDD 1 To prévu pour données/sauvegardes), avec **Debian 13 (Trixie) installé directement sur le matériel**.

Le contrôleur Ansible est le poste d’administration Fedora. **OPNsense assure le rôle de routeur et de firewall entre Internet et le LAN** ; le switch LAN relie les équipements du réseau. Leur configuration reste hors scope de ce dépôt.

---

## 1. Séparation des couches (natif vs conteneurs)

| Composant | Exécution | Justification |
| :--- | :--- | :--- |
| Debian 13 | Installé directement sur le Dell OptiPlex 3060 | I/O et RAM maximales pour les conteneurs |
| Docker Engine | `systemd` | Coolify, PostgreSQL, APIs NestJS |
| cloudflared | `systemd` natif | Tunnel indépendant de Docker |
| Beszel Agent | Binaire `systemd` | Métriques hôte + socket Docker |
| Cockpit + PCP (+ pmlogger) | `systemd` | Admin web à la demande + historique (sans paquet `cockpit-pcp`, absent de Debian 13) |
| Coolify / PostgreSQL / NestJS | Conteneurs | Isolation et déploiements applicatifs |

Ansible n'installe **pas** Coolify, PostgreSQL, Redis ni NestJS en paquets Debian.

---

## 2. Réseau

État actuel : le Dell OptiPlex et le poste d’administration sont sur le LAN derrière OPNsense. Le LAN utilise le préfixe `192.168.1.0/24` ; les variables `admin_cidr` restent sur ce préfixe tant que la migration VLAN n'est pas faite.

Architecture future envisagée (documentation seule) :

- VLAN 10 serveurs : `10.0.10.0/24`
- VLAN 20 personnel : `10.0.20.0/24`
- VLAN 1 management : `10.0.1.0/24`

Le Dell n'est **pas** configuré comme routeur/firewall : cette fonction est assurée par OPNsense.

Publication Internet : **Cloudflare Tunnel uniquement** (pas de redirection de ports sur OPNsense pour les applications).

---

## 3. Mémoire & stockage

- Swap fichier `/swapfile` **2 Gio**, `vm.swappiness=10`, `vm.vfs_cache_pressure=50`.
- `vm.overcommit_memory` laissé à `0` (défaut).
- Journald plafonné (`SystemMaxUse=500M`) pour protéger le SSD.
- Docker reste sur le SSD système. Le HDD 1 To n'est ni partitionné ni formaté par Ansible.

---

## 4. Sécurité en profondeur

1. **Pas d'exposition Internet directe** : cloudflared en sortie uniquement ; token via `--token-file` (absent de `ps`).
2. **UFW** : `deny` entrant ; SSH `22` et Cockpit `9090` limités à `admin_cidr`.
3. **Docker vs UFW** : les ports publiés par Docker peuvent contourner UFW. Ne pas publier `5432`/`6379`. Compléter avec OPNsense.
4. **SSH** : hardening optionnel (`ssh_hardening_enabled`), clés only, `AllowUsers`, validation `sshd -t` avant restart.
5. **Fail2ban** (backend systemd) + `ignoreip` pour le LAN d'admin.
6. **AppArmor** actif ; comptes système `cloudflared` et `beszel`.
7. **Groupe `docker`** : non accordé à `alex` par défaut. Beszel y est ajouté pour les métriques conteneurs (**compromis ≈ root**).

---

## 5. Hygiène Docker

`/etc/docker/daemon.json` :

- rotation des logs (`10m` × 3) ;
- `live-restore: true` ;
- `userland-proxy: false` ;
- **aucune** écoute TCP du démon (`hosts` / `tcp://` interdits).

Compatible Coolify : pas de politique qui casse le moteur ou Compose.

## 6. Premier provisionnement

Une installation Debian vierge doit d’abord avoir SSH activé, un compte
`alex` joignable par clé et un mot de passe root défini. Le playbook
`playbooks/bootstrap.yml` utilise `su` et demande ce mot de passe à
l’exécution pour installer `sudo` et ajouter `alex` au groupe
administrateur. Les playbooks de provisionnement utilisent ensuite sudo
avec demande du mot de passe d’`alex` via `--ask-become-pass`.

Ansible ne peut pas configurer le réseau, activer SSH ou créer son premier
compte de connexion si Debian n’est pas encore accessible.

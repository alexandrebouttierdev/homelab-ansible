# Architecture technique & choix de conception

Serveur cible : **Dell OptiPlex 3060** (Intel Core i5-8500, 16 Go RAM, SSD NVMe 256 Go + HDD 1 To prévu pour données/sauvegardes), avec **Debian 13 (Trixie) installé directement sur le matériel**.

Le contrôleur Ansible est le poste d’administration Fedora. **OPNsense assure le rôle de routeur et de firewall entre Internet et le LAN, avec CrowdSec pour l’analyse des journaux et la remédiation** ; le switch TP-Link relie les équipements du réseau. Leur configuration reste hors scope de ce dépôt.

---

## 1. Séparation des couches (natif vs conteneurs)

| Composant | Exécution | Justification |
| :--- | :--- | :--- |
| Debian 13 | Installé directement sur le Dell OptiPlex 3060 | I/O et RAM maximales pour les conteneurs |
| Docker Engine | `systemd` | Coolify, PostgreSQL, APIs NestJS |
| Coolify | Services Docker installés initialement par Ansible | Interface locale sur `8000`, déploiement des applications ; données dans `/data/coolify` |
| cloudflared | `systemd` natif | Tunnel indépendant de Docker |
| Homelab Manager | Binaires Go natifs `systemd`, compte `homelab-manager` non root | Supervision et administration de l'hôte indépendantes de Docker et de Coolify ; base SQLite dans `/var/lib/homelab-manager` |
| homelab-docker-proxy | Unité `systemd` activée par socket | Seul accès au socket Docker, en lecture (routes GET en liste blanche) |
| restic / Grype | Unités `systemd` lancées à la demande via polkit | Sauvegardes hôte et scans de vulnérabilités des paquets, hors du Manager |
| PostgreSQL / NestJS | Conteneurs Coolify | Isolation et déploiements applicatifs |

Ansible installe Coolify via son script officiel, mais n'installe pas PostgreSQL,
Redis ni NestJS en paquets Debian et ne gère pas leurs conteneurs applicatifs.

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
2. **UFW** : `deny` entrant ; SSH `22`, Homelab Manager `9090` et les
   ports Coolify limités à `admin_cidr`.
3. **Docker vs UFW** : les ports publiés par Docker peuvent contourner UFW ;
   `DOCKER-USER` limite l'accès externe au réseau `admin_cidr`. Ne pas publier
   `5432`/`6379`. Compléter avec OPNsense.
4. **CrowdSec sur OPNsense** : analyse des journaux et composant de remédiation pour appliquer les décisions de blocage.
5. **SSH** : hardening optionnel (`ssh_hardening_enabled`), clés only, `AllowUsers`, validation `sshd -t` avant restart.
6. **Fail2ban** (backend systemd) + `ignoreip` pour le LAN d'admin.
7. **AppArmor** actif ; comptes système `cloudflared`, `homelab-manager`,
   `homelab-docker-proxy` et `homelab-vulnscan`.
8. **Groupe `docker`** : non accordé à `alex` par défaut. Seul `homelab-docker-proxy` y est ajouté (**compromis ≈ root**, limité par la liste blanche de routes du proxy).
9. **polkit** : chaque module de Homelab Manager installe une règle qui n'autorise que le compte `homelab-manager`, sur ses seules unités ou actions.

---

## 5. Hygiène Docker

`/etc/docker/daemon.json` :

- rotation des logs (`10m` × 3) ;
- `live-restore: true` ;
- `userland-proxy: false` ;
- pool réseau Docker `172.20.0.0/14` en `/24`, sans chevauchement avec les
  VLAN futurs `10.0.x.x` ;
- **aucune** écoute TCP du démon (`hosts` / `tcp://` interdits).

Compatible avec le Coolify installé par Ansible.

## 6. Premier provisionnement

Une installation Debian vierge doit d’abord avoir SSH activé, un compte
`alex` joignable par clé et un mot de passe root défini. Le script
`scripts/first-run.sh` lance `playbooks/bootstrap.yml`, qui utilise `su` et
demande ce mot de passe à l’exécution pour installer `sudo` et ajouter `alex`
au groupe administrateur. Il réinitialise ensuite la connexion SSH et lance
le préflight, qui demande le mot de passe sudo d’`alex`.

Ansible ne peut pas configurer le réseau, activer SSH ou créer son premier
compte de connexion si Debian n’est pas encore accessible.

## 7. Supervision : Homelab Manager

Décision : la supervision de l'hôte est confiée à
[Homelab Manager](https://github.com/alexandrebouttierdev/homelab-manager),
qui regroupe métriques hôte et Docker, journaux systemd, alertes, sauvegardes
restic et scans Grype dans un seul service natif, sans conteneur ni terminal web.

- Installation par le rôle `homelab_manager` depuis une release GitHub dont la
  version et le SHA-256 sont épinglés dans `inventory/group_vars/all/main.yml`.
  Les fichiers de la release sont gardés sous `/opt/homelab-manager/releases/` ;
  l'interface est servie depuis le répertoire de la version active.
- Écoute sur `9090` (le `8080` amont est le tableau de bord Traefik de Coolify),
  ouvert dans UFW pour `admin_cidr` seulement, en HTTP.
- Clé du coffre de secrets générée sur le serveur et chiffrée par
  `systemd-creds` (`/etc/credstore.encrypted/homelab-manager-secrets-key`),
  jamais régénérée par Ansible.
- Modules activés : sauvegardes restic, vulnérabilités (Grype `.deb` épinglé),
  nettoyage du journal, redémarrage/extinction. Les actions sur les conteneurs,
  services et préférences système restent désactivées.
- Les sauvegardes restic du Manager couvrent l'hôte ; les sauvegardes
  PostgreSQL restent gérées par Coolify.

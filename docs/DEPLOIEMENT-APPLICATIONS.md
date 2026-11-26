# Guide post-provisionnement : Coolify, MonoOps, PostgreSQL & NestJS

Après `playbooks/site.yml`, le serveur Debian 13 dispose de Coolify et de
MonoOps ; l'installation initiale des deux est gérée par Ansible.

---

## 1. Première connexion Coolify

Le rôle Ansible télécharge et exécute le script officiel de Coolify en root.
L'installation est sautée si `/data/coolify/source/.env` existe déjà.

- Accès initial LAN : `http://IP_LOCALE_SERVEUR:8000`
- Les ports `8000`, `6001`, `6002`, `80` et `443` sont limités à `admin_cidr`.
- Créer le compte administrateur initial dès le premier accès.
- Pour l'exposition distante, configurer ensuite un sous-domaine Cloudflare
  Tunnel vers `http://127.0.0.1:8000` et le protéger avec **Cloudflare Access**.
- Les APIs NestJS gardent leur propre authentification applicative.

---

## 2. MonoOps

1. Ouvrir `http://IP_LOCALE_SERVEUR:9090` depuis `admin_cidr` **juste après le
   déploiement** : le compte initial est `admin` / `admin` et l'interface
   impose aussitôt un nouveau mot de passe.
2. Dans « Configuration », activer la double authentification (TOTP) et
   conserver les codes de secours.
3. « Sauvegardes » › « Configuration » : choisir le dépôt restic, les sources
   et l'horaire, puis « Initialiser le dépôt ». Conserver hors ligne le mot de
   passe affiché une seule fois.
4. Le premier scan Grype démarre 2 minutes après le premier lancement ; il
   télécharge une base d'environ 3,4 Go dans `/var/cache/monoops-vulnscan`.

Pour réappliquer seulement ce rôle (et sa règle UFW) :

```bash
ansible-playbook playbooks/monitoring.yml --ask-become-pass
```

### Mise à jour de version

1. Sauvegarder la base :
   `sudo -u monoops sqlite3 /var/lib/monoops/monoops.db ".backup '/var/lib/monoops/backup-$(date +%F).db'"`
   (paquet `sqlite3`).
2. Lire les notes de la release : elles signalent les unités ou règles
   polkit modifiées.
3. Mettre à jour `monoops_version` et `monoops_sha256`
   (fichier `SHA256SUMS` de la release) dans `inventory/group_vars/all/main.yml`,
   puis relancer `playbooks/monitoring.yml`. Les migrations SQLite
   s'appliquent au démarrage.
4. Retour arrière : remettre l'ancienne version et son empreinte, relancer le
   playbook, et restaurer la base sauvegardée si une migration l'a modifiée.
   Les anciennes releases restent dans `/opt/monoops/releases/` et
   peuvent être supprimées à la main.

### Passage de Homelab Manager à MonoOps

Homelab Manager a été renommé MonoOps à la version 3.0.0 (comptes, unités,
chemins, binaires et archives `monoops_*`), **sans migration** : MonoOps
repart d'une base vide (compte `admin` / `admin`, double authentification et
dépôts restic à reconfigurer ; un dépôt restic existant se rattache avec son
mot de passe).

Le rôle `monoops` arrête puis retire l'ancienne installation (unités,
binaires, règles polkit et tmpfiles, comptes `homelab-*`) avant d'installer
MonoOps sur le même port. Ses données restent en place ; une fois MonoOps
vérifié, elles se suppriment à la main :

```bash
sudo rm -rf /var/lib/homelab-manager /opt/homelab-manager /etc/homelab-manager \
  /var/lib/homelab-backup /var/lib/homelab-vulnscan /var/cache/homelab-vulnscan \
  /etc/credstore.encrypted/homelab-manager-secrets-key
```

Les fichiers restaurés en quarantaine dans `/var/lib/homelab-backup/restore` sont à
récupérer avant si besoin.

---

## 3. PostgreSQL & NestJS

- PostgreSQL et les APIs restent **conteneurisés** (Coolify), jamais en paquets Debian.
- Ne pas rendre PostgreSQL/Redis « publicly available ».
- Limites mémoire Coolify recommandées : Postgres 1–2G, API ~512M + `NODE_OPTIONS=--max-old-space-size=384`.
- Sauvegardes PostgreSQL : **Coolify uniquement** — voir [`SAUVEGARDES.md`](SAUVEGARDES.md).

---

## 4. Cloudflare Tunnel

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
# cloudflared_tunnel_token: "..."
```

`cloudflared_enabled: true`, puis :

```bash
ansible-playbook playbooks/cloudflare-tunnel.yml --ask-become-pass --ask-vault-pass
```

Aucun port entrant firewall pour le tunnel.

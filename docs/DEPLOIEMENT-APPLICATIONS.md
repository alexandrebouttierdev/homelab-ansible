# Guide post-provisionnement : Coolify, Beszel, PostgreSQL & NestJS

Après `playbooks/site.yml`, le serveur Debian 13 dispose de Coolify et du Hub
Beszel ; l'installation initiale des deux est gérée par Ansible.

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

## 2. Beszel (Hub Ansible + Agent)

1. Ouvrir `http://IP_LOCALE_SERVEUR:8090` et créer le compte administrateur du Hub.
2. Dans **Add System**, ajouter le serveur avec son IP et le port `45876`, puis copier la clé publique.
3. Enregistrer `beszel_agent_key` dans Ansible Vault :

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
# beszel_agent_key: "..."
```

4. Renseigner une version et son SHA-256 vérifié dans `main.yml`, puis activer `beszel_agent_enabled: true`. Le pare-feu autorise déjà le sous-réseau Docker par défaut (`172.17.0.0/16`) vers le port agent ; adapter `beszel_hub_cidr` si le bridge Docker utilise un autre sous-réseau.
5. Appliquer le rôle :

```bash
ansible-playbook playbooks/monitoring.yml --ask-become-pass --ask-vault-pass
```

Ce playbook applique aussi les règles UFW nécessaires pour que le Hub
Beszel puisse joindre l'agent sur le port `45876`.

Compromis : l'utilisateur `beszel` est dans le groupe `docker` (équivalent root via le socket).
Le Hub est limité au réseau d'administration par UFW et le filtrage DOCKER-USER. Ne pas le publier sur Internet sans tunnel et protection d'accès adaptés.

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

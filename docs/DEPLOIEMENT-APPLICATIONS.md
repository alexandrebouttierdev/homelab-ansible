# Guide post-provisionnement : Coolify, Beszel, PostgreSQL & NestJS

Après `playbooks/site.yml`, le serveur Debian 13 est prêt pour la stack applicative.

---

## 1. Installation de Coolify

Coolify s'appuie sur Docker déjà installé par Ansible :

```bash
curl -fL https://cdn.coollabs.io/coolify/install.sh \
  -o /tmp/coolify-install.sh
sha256sum /tmp/coolify-install.sh
```

- Vérifier l'empreinte affichée avec le SHA-256 officiel publié par Coolify.
- Relire le script avec `less /tmp/coolify-install.sh`, puis l'exécuter uniquement
  si son contenu est attendu : `sudo bash /tmp/coolify-install.sh`.
- Utiliser une version épinglée ou un checksum officiel dès que la procédure
  Coolify le propose.

- Accès initial LAN : `http://IP_LOCALE_SERVEUR:8000`
- Exposition : sous-domaine Cloudflare Tunnel → `http://127.0.0.1:8000`
- Protéger l'UI avec **Cloudflare Access**
- Les APIs NestJS gardent leur propre authentification applicative

---

## 2. Beszel (Hub + Agent)

1. Déployer le Hub (`henrygd/beszel`) dans Coolify (port `8090`, volume persistant).
2. Exposer via Tunnel si besoin (`status.example.fr` → `http://127.0.0.1:8090`).
3. **Add System** : nom, IP/`127.0.0.1`, port `45876` ; copier la clé publique.
4. Si UFW est actif et que le Hub est dans Docker, renseigner `beszel_hub_cidr` avec le sous-réseau Docker réel (`docker network inspect …`).
5. Vault :

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
# beszel_agent_key: "..."
```

6. `beszel_agent_enabled: true` dans `inventory/group_vars/all/main.yml`, puis :

```bash
ansible-playbook playbooks/monitoring.yml --ask-become-pass --ask-vault-pass
```

Compromis : l'utilisateur `beszel` est dans le groupe `docker` (équivalent root via le socket).

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

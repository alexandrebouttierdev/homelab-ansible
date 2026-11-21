# Bonnes pratiques de sauvegarde (hors Ansible)

Ansible provisionne le système. **Il ne planifie pas de sauvegardes PostgreSQL** :
Coolify reste le seul outil de dump applicatif pour éviter les doublons.

---

## 1. PostgreSQL (via Coolify)

1. Dans Coolify, ouvrir la ressource PostgreSQL.
2. Activer les sauvegardes automatiques (`pg_dump` / schedule Coolify).
3. Cible recommandée : stockage **externe** (ex. Cloudflare R2, bucket S3, NAS).
4. Conserver au moins :
   - 7 copies quotidiennes ;
   - 4 copies hebdomadaires.
5. Ne jamais publier le port `5432` sur Internet ni sur le LAN non administrateur.

### Vérification de restauration

```bash
# Sur une machine de test (jamais en écrasant la prod sans consentement)
pg_restore --list sauvegarde.dump | head
# Puis restaurer vers une instance vide et valider les schémas / une requête métier
```

Documenter la dernière date de restauration testée.

---

## 2. Configuration Coolify

À sauvegarder régulièrement (manuel ou script hors de ce dépôt) :

- Export / volume de données Coolify (souvent `/data/coolify` selon l'install).
- Variables d'environnement des applications (hors secrets en clair dans Git).
- Définitions Compose / Dockerfiles versionnés dans Git.

Copie hors serveur : NAS, autre machine, ou objet cloud chiffré.

---

## 3. Fichiers système importants

Sur le Dell, hors volumes Docker applicatifs :

| Chemin | Intérêt |
| --- | --- |
| `/etc/cloudflared/tunnel.token` | Secret tunnel (permissions 0640) — **ne pas committer** |
| `/etc/beszel/agent.env` | Clé agent Beszel — **ne pas committer** |
| `/etc/ssh/sshd_config.d/` | Durcissement SSH |
| `/etc/docker/daemon.json` | Config démon Docker |
| `/etc/ufw/` | Règles pare-feu locales |

Les secrets restent dans **Ansible Vault** sur le Mac Studio (`inventory/group_vars/all/vault.yml`).

Le HDD 1 To est prévu pour données et sauvegardes : le monter et le formater **manuellement**, puis y pointer les destinations Coolify / rsync. Ce dépôt ne partitionne ni ne formate aucun disque.

---

## 4. Copie hors du serveur

Principes :

1. Une copie locale sur le HDD du serveur n'est pas une stratégie complète (incendie, vol, ransomware).
2. Une copie hors site (cloud objet ou machine distante) est obligatoire pour les bases.
3. Chiffrer les archives contenant des dumps ou des tokens.

Exemple de principe (à adapter, non automatisé par Ansible) :

```bash
# Depuis le Mac Studio — illustration uniquement
rsync -aH --delete alex@IP_SERVEUR:/chemin/sauvegardes/ ~/Backups/homelab/
```

---

## 5. Checklist périodique

- [ ] Dumps PostgreSQL Coolify OK (logs Coolify)
- [ ] Restauration testée au moins une fois par trimestre
- [ ] Vault Ansible sauvegardé (copie chiffrée hors machine)
- [ ] Token Cloudflare et clé Beszel récupérables si le SSD tombe
- [ ] Aucun port DB/Redis publié (`docker ps`)

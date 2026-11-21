# Maintenance

## Avant toute exécution

1. ouvrir une session SSH déjà authentifiée ;
2. exécuter `playbooks/preflight.yml --ask-become-pass` ;
3. vérifier les changements avec `--check --diff` ;
4. effectuer une sauvegarde de la configuration et des secrets nécessaires ;
5. exécuter seulement le playbook concerné.

## Mise à jour du serveur

Les mises à jour sont gérées par APT et `unattended-upgrades`. Effectuer
d’abord une mise à jour manuelle contrôlée :

```bash
sudo apt update
sudo apt full-upgrade
sudo needrestart
```

Redémarrer uniquement après confirmation de l’interruption possible.

## Mise à jour Ansible

- mettre à jour Ansible Core dans le venv du Mac Studio ;
- réinstaller les collections avec `ansible-galaxy collection install -r requirements.yml`;
- exécuter `ansible-lint` et le script de contrôles statiques ;
- tester avec `--check --diff`.

## Diagnostic

```bash
ansible homelab -m ping
ansible-playbook playbooks/preflight.yml --ask-become-pass
ansible-playbook playbooks/verify.yml --ask-become-pass
sudo systemctl --failed
sudo journalctl -p warning --since "1 hour ago"
```

## Idempotence

Une deuxième exécution doit produire peu ou aucune modification réelle.
Le mode check ne remplace pas les validations sur le serveur.

```bash
ansible-playbook playbooks/site.yml --check --diff --ask-become-pass
ansible-playbook playbooks/site.yml --ask-become-pass
ansible-playbook playbooks/site.yml --ask-become-pass
```

## Retour arrière

Sauvegarder les fichiers `/etc/ssh`, `/etc/ufw`, `/etc/docker`,
`/etc/cloudflared` et les unités systemd avant une modification sensible.

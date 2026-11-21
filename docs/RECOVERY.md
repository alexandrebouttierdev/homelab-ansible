# Récupération

## Perte d’accès SSH

1. conserver une seconde session SSH ouverte pendant les modifications ;
2. utiliser l’accès physique ou console disponible ;
3. vérifier `/etc/ssh/sshd_config.d/00-provision-serveur.conf` ;
4. restaurer l’ancien fichier ou retirer le drop-in ;
5. valider avec `sudo sshd -t` ;
6. redémarrer SSH uniquement après validation :

```bash
sudo systemctl restart ssh
```

Ne pas désactiver SSH jusqu’au rétablissement d’un accès confirmé.

## Erreur firewall

1. conserver une session déjà ouverte ;
2. afficher `sudo ufw status verbose` ;
3. vérifier les règles Docker ;
4. désactiver UFW temporairement seulement depuis une console disponible :

```bash
sudo ufw disable
```

Puis restaurer les règles locales depuis une sauvegarde.

## Échec Ansible

1. ne pas relancer immédiatement `site.yml` ;
2. vérifier l’erreur et le dernier handler exécuté ;
3. exécuter le playbook ciblé concerné ;
4. contrôler les fichiers `/etc` modifiés ;
5. restaurer uniquement les fichiers dont l’état a été sauvegardé.

## Service arrêté

```bash
sudo systemctl status <service>
sudo journalctl -u <service> --since "1 hour ago"
sudo systemctl restart <service>
```

Le rôle Ansible gère uniquement l'installation initiale de Coolify ; ne pas
modifier les services Coolify ni PostgreSQL avec ce dépôt.

## Problème Docker

```bash
sudo systemctl status docker
sudo journalctl -u docker --since "1 hour ago"
sudo docker info
```

Restaurer `/etc/docker/daemon.json` depuis une sauvegarde, puis redémarrer
Docker. Vérifier séparément les conteneurs Coolify après le retour.

## Problème de stockage

1. vérifier les espaces disponibles et les montages ;
2. identifier l’origine de la croissance ;
3. ne pas supprimer les données applicatives ;
4. restaurer les journaux ou déplacer les données uniquement après
   vérification des chemins réels ;
5. tester Coolify avant et après tout déplacement.

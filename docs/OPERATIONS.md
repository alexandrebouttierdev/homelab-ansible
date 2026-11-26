# Exploitation courante

## État général

```bash
uptime
free -h
df -h
df -i
sudo systemctl --failed
sudo journalctl -p warning --since "24 hours ago"
```

## SSH

```bash
sudo sshd -t
sudo systemctl status ssh
sudo ss -ltnp | grep ':22 '
```

## Pare-feu

```bash
sudo ufw status verbose
sudo iptables -S DOCKER-USER
sudo ss -ltnp
```

Ne pas conclure que le serveur est fermé sans vérifier les règles
Docker et les filtres extérieurs à Debian.

## Docker

```bash
sudo docker info
sudo docker ps
sudo docker network ls
sudo docker stats --no-stream
```

Le rôle Ansible gère uniquement l'installation initiale de Coolify. Ne pas
modifier ses services ou conteneurs applicatifs depuis ce dépôt.

## Stockage

Vérifier le NVMe et le HDD séparément :

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
df -hT
sudo du -xh --max-depth=1 /var/lib/docker 2>/dev/null
sudo du -xh --max-depth=1 /srv/homelab-data 2>/dev/null
```

Ne pas monter, partitionner ou déplacer `/srv/homelab-data` avec
Ansible tant que les dépendances réelles n’ont pas été vérifiées.

## Supervision

```bash
sudo systemctl status monoops.service monoops-docker-proxy.socket
journalctl -u monoops -n 20     # version démarrée, clé du coffre chargée
journalctl -u monoops-vulnscan -n 20    # dernier scan Grype
sudo systemctl status cloudflared-homelab.service
```

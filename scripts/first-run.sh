#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export ANSIBLE_CONFIG="$ROOT/ansible.cfg"

echo "==> Bootstrap initial (saisir le mot de passe root)"
ansible-playbook playbooks/bootstrap.yml --ask-become-pass

echo "==> Préflight (saisir le mot de passe sudo de l'administrateur)"
ansible-playbook playbooks/preflight.yml --ask-become-pass

echo "==> Bootstrap et préflight terminés"

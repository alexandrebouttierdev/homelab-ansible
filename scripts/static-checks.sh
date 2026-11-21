#!/usr/bin/env bash
# Contrôles statiques locaux — n'exécute rien sur le serveur distant.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -x "$ROOT/.venv/bin/ansible-playbook" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/.venv/bin/activate"
fi

export ANSIBLE_CONFIG="$ROOT/ansible.cfg"

echo "==> Recherche de secrets potentiels"
if grep -RInE --exclude-dir=.venv --exclude-dir=.git --exclude='*.zip' \
  --exclude='vault.yml.example' --exclude='static-checks.sh' \
  --exclude-dir=agent-tools \
  'BEGIN (RSA |OPENSSH )?PRIVATE KEY|cloudflared_tunnel_token:[[:space:]]*"[^"]{40,}"' \
  . ; then
  echo "FAIL: secret potentiel détecté" >&2
  exit 1
fi
echo "OK: aucun secret évident"

echo "==> Vérification YAML (yamllint)"
if command -v yamllint >/dev/null 2>&1; then
  yamllint inventory playbooks roles requirements.yml
else
  echo "SKIP: yamllint non installé"
fi

echo "==> ansible-playbook --syntax-check"
for pb in playbooks/*.yml; do
  echo "  - $pb"
  ansible-playbook "$pb" --syntax-check
done

echo "==> Vérification de la syntaxe des scripts shell"
bash -n scripts/first-run.sh scripts/static-checks.sh

echo "==> ansible-inventory --graph"
ansible-inventory --graph

echo "==> ansible-playbook --list-tasks (site.yml)"
ansible-playbook playbooks/site.yml --list-tasks | tee /tmp/homelab-ansible-tasks.txt >/dev/null
wc -l /tmp/homelab-ansible-tasks.txt

echo "==> ansible-playbook --check --diff --syntax-check (site.yml)"
ansible-playbook playbooks/site.yml --check --diff --syntax-check

if command -v ansible-lint >/dev/null 2>&1; then
  echo "==> ansible-lint"
  ansible-lint playbooks/*.yml roles/*/tasks/*.yml roles/*/handlers/*.yml
else
  echo "SKIP: ansible-lint non installé"
fi

echo "==> OK — contrôles statiques terminés"

#!/bin/bash
set -e

echo "=== CIA Infrastructure Deploy ==="

# Récupérer la clé SSH depuis Doppler
doppler secrets get SSH_PRIVATE_KEY --plain > /tmp/cia_infra
chmod 600 /tmp/cia_infra

# Export vars pour Ansible
export NETBOX_SECRET_KEY=$(doppler secrets get NETBOX_SECRET_KEY --plain)
export NETBOX_DB_PASSWORD=$(doppler secrets get NETBOX_DB_PASSWORD --plain)
export NETBOX_ADMIN_USER=$(doppler secrets get NETBOX_ADMIN_USER --plain)
export NETBOX_ADMIN_PASSWORD=$(doppler secrets get NETBOX_ADMIN_PASSWORD --plain)
export ELASTIC_PASSWORD=$(doppler secrets get ELASTIC_PASSWORD --plain)
export KIBANA_PASSWORD=$(doppler secrets get KIBANA_PASSWORD --plain)
export OPENVPN_CA_PASS=$(doppler secrets get OPENVPN_CA_PASS --plain)

case "$1" in
  infra)
    echo "--- Terraform apply ---"
    cd terraform/
    doppler run --command='terraform apply -auto-approve \
      -var="proxmox_api_url=$PROXMOX_API_URL" \
      -var="proxmox_token_id=$PROXMOX_TOKEN_ID" \
      -var="proxmox_token_secret=$PROXMOX_TOKEN_SECRET" \
      -var="ssh_public_key=$SSH_PUBLIC_KEY" \
      -var="vm_password=$VM_PASSWORD"'
    ;;
  config)
    echo "--- Ansible playbooks ---"
    cd ansible/
    ansible-playbook -i inventory/hosts.yml site.yml
    ;;
  all)
    $0 infra && sleep 90 && $0 config
    ;;
  *)
    echo "Usage: ./deploy.sh [infra|config|all]"
    ;;
esac

# Cleanup
rm -f /tmp/cia_infra
echo "=== Done ==="
```

---

## Récapitulatif visuel
```
MAINTENANT (sans droits admin)          QUAND TU AURAS LES DROITS
────────────────────────────────        ──────────────────────────
✅ Structure Git + .gitignore           ⏳ Donner rôle Admin au token
✅ Installer terraform/ansible/doppler  ⏳ Upload ISOs pfSense + Ubuntu
✅ Générer clé SSH cia_infra            ⏳ Créer template cloud-init (qm)
✅ Configurer tous les secrets Doppler  ⏳ terraform apply
✅ Écrire tout le code Terraform        ⏳ Attendre cloud-init (90s)
✅ Écrire tous les rôles Ansible        ⏳ ansible-playbook site.yml
✅ Écrire deploy.sh                     ⏳ Config manuelle pfSense S1+S2
✅ terraform init (valide la syntaxe)   ⏳ Test VPN + connectivité
✅ ansible --syntax-check site.yml      ⏳ Commiter config pfSense XML
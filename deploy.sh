#!/bin/bash
set -e

echo "=== CIA Infrastructure Deploy ==="

# ── Secrets Doppler ───────────────────────────────────────────────────────────
load_secrets() {
  doppler secrets get SSH_PRIVATE_KEY --plain > /tmp/cia_infra
  chmod 600 /tmp/cia_infra

  # Ansible secrets
  export NETBOX_SECRET_KEY=$(doppler secrets get NETBOX_SECRET_KEY --plain)
  export NETBOX_DB_PASSWORD=$(doppler secrets get NETBOX_DB_PASSWORD --plain)
  export NETBOX_ADMIN_USER=$(doppler secrets get NETBOX_ADMIN_USER --plain)
  export NETBOX_ADMIN_PASSWORD=$(doppler secrets get NETBOX_ADMIN_PASSWORD --plain)
  export ELASTIC_PASSWORD=$(doppler secrets get ELASTIC_PASSWORD --plain)
  export KIBANA_PASSWORD=$(doppler secrets get KIBANA_PASSWORD --plain)

  # IPs des deux Proxmox (pour SSH bootstrap + inventaire Ansible)
  export PROXMOX_S1_IP=$(doppler secrets get PROXMOX_S1_IP --plain)
  export PROXMOX_S2_IP=$(doppler secrets get PROXMOX_S2_IP --plain)

  # Mot de passe root Proxmox (pour bootstrap initial via sshpass)
  export PROXMOX_ROOT_PASSWORD=$(doppler secrets get PROXMOX_ROOT_PASSWORD --plain 2>/dev/null || echo "")

  # IP WAN du router-s1 (pour que router-s2 sache où se connecter en VPN)
  export OPENVPN_SERVER_IP=$(doppler secrets get OPENVPN_SERVER_IP --plain 2>/dev/null || echo "")
}

# ── Variables Terraform ───────────────────────────────────────────────────────
build_tf_args() {
  TF_ARGS=(
    -var "proxmox_s1_api_url=$(doppler secrets get PROXMOX_S1_API_URL --plain)"
    -var "proxmox_s1_token_id=$(doppler secrets get PROXMOX_S1_TOKEN_ID --plain)"
    -var "proxmox_s1_token_secret=$(doppler secrets get PROXMOX_S1_TOKEN_SECRET --plain)"
    -var "proxmox_s2_api_url=$(doppler secrets get PROXMOX_S2_API_URL --plain)"
    -var "proxmox_s2_token_id=$(doppler secrets get PROXMOX_S2_TOKEN_ID --plain)"
    -var "proxmox_s2_token_secret=$(doppler secrets get PROXMOX_S2_TOKEN_SECRET --plain)"
    -var "ssh_public_key=$(doppler secrets get SSH_PUBLIC_KEY --plain)"
    -var "vm_password=$(doppler secrets get VM_PASSWORD --plain)"
    -var "s1_template_id=$(doppler secrets get TEMPLATE_ID --plain)"
    -var "s2_template_id=$(doppler secrets get TEMPLATE_ID_S2 --plain 2>/dev/null || doppler secrets get TEMPLATE_ID --plain)"
    -var "proxmox_s1_node=$(doppler secrets get PROXMOX_S1_NODE --plain)"
    -var "proxmox_s2_node=$(doppler secrets get PROXMOX_S2_NODE --plain)"
  )
}

# ── Commandes ─────────────────────────────────────────────────────────────────
case "$1" in

  bootstrap-s1)
    echo "--- Bootstrap Proxmox S1 ---"
    load_secrets
    if [[ -z "$PROXMOX_ROOT_PASSWORD" ]]; then
      echo "ERREUR : PROXMOX_ROOT_PASSWORD non défini dans Doppler" >&2
      exit 1
    fi
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      scp -o StrictHostKeyChecking=no scripts/bootstrap-proxmox.sh root@${PROXMOX_S1_IP}:/tmp/
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      ssh -o StrictHostKeyChecking=no root@${PROXMOX_S1_IP} \
        "chmod +x /tmp/bootstrap-proxmox.sh && /tmp/bootstrap-proxmox.sh --site 1"
    # Injecter la clé SSH Doppler dans pve1 (permet l'accès sans mot de passe ensuite)
    echo "[pve1] Injection clé SSH publique..."
    SSH_PUB_KEY=$(doppler secrets get SSH_PUBLIC_KEY --plain)
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      ssh -o StrictHostKeyChecking=no root@${PROXMOX_S1_IP} \
        "mkdir -p ~/.ssh && grep -qF '${SSH_PUB_KEY}' ~/.ssh/authorized_keys 2>/dev/null || echo '${SSH_PUB_KEY}' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    echo "[pve1] Clé SSH injectée."
    ;;

  bootstrap-s2)
    echo "--- Bootstrap Proxmox S2 ---"
    load_secrets
    if [[ -z "$PROXMOX_ROOT_PASSWORD" ]]; then
      echo "ERREUR : PROXMOX_ROOT_PASSWORD non défini dans Doppler" >&2
      exit 1
    fi
    # Si S2 est nested dans S1 : scp/ssh via ProxyJump
    # Si S2 est un serveur séparé : accès direct
    SCP_OPTS="-o StrictHostKeyChecking=no"
    SSH_OPTS="-o StrictHostKeyChecking=no"
    if [[ "$PROXMOX_S2_NESTED" == "true" ]]; then
      SCP_OPTS="$SCP_OPTS -J root@${PROXMOX_S1_IP}"
      SSH_OPTS="$SSH_OPTS -J root@${PROXMOX_S1_IP}"
    fi
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      scp $SCP_OPTS scripts/bootstrap-proxmox.sh root@${PROXMOX_S2_IP}:/tmp/
    S2_TMPL=$(doppler secrets get TEMPLATE_ID_S2 --plain 2>/dev/null || echo "9001")
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      ssh $SSH_OPTS root@${PROXMOX_S2_IP} \
        "chmod +x /tmp/bootstrap-proxmox.sh && /tmp/bootstrap-proxmox.sh --site 2 --template-id ${S2_TMPL}"
    # Injecter la clé SSH Doppler dans pve2 (permet l'accès sans mot de passe ensuite)
    echo "[pve2] Injection clé SSH publique..."
    SSH_PUB_KEY=$(doppler secrets get SSH_PUBLIC_KEY --plain)
    SSHPASS="$PROXMOX_ROOT_PASSWORD" sshpass -e \
      ssh $SSH_OPTS root@${PROXMOX_S2_IP} \
        "mkdir -p ~/.ssh && grep -qF '${SSH_PUB_KEY}' ~/.ssh/authorized_keys 2>/dev/null || echo '${SSH_PUB_KEY}' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    echo "[pve2] Clé SSH injectée."
    ;;

  init)
    echo "--- Terraform init ---"
    cd terraform/
    terraform init
    ;;

  infra)
    echo "--- Terraform apply ---"
    load_secrets
    build_tf_args
    cd terraform/
    terraform apply -auto-approve "${TF_ARGS[@]}"
    cd ..
    echo "--- Nettoyage SSH known_hosts ---"
    for ip in 10.1.0.1 10.1.0.10 10.1.0.20 10.2.0.1 10.2.0.5 10.2.0.30; do
      ssh-keygen -R "$ip" 2>/dev/null || true
    done
    ;;

  destroy)
    echo "--- Terraform destroy ---"
    load_secrets
    build_tf_args
    cd terraform/
    terraform destroy -auto-approve "${TF_ARGS[@]}"
    ;;

  config)
    echo "--- Ansible playbooks ---"
    load_secrets
    cat > /tmp/cia_ssh_config <<EOF
Host ${PROXMOX_S1_IP}
    User root
    IdentityFile /tmp/cia_infra
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host ${PROXMOX_S2_IP}
    User root
    IdentityFile /tmp/cia_infra
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 10.1.0.*
    ProxyJump root@${PROXMOX_S1_IP}
    User cia
    IdentityFile /tmp/cia_infra
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 10.2.0.*
  ProxyJump root@${PROXMOX_S2_IP}
    User cia
    IdentityFile /tmp/cia_infra
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    export ANSIBLE_SSH_ARGS="-F /tmp/cia_ssh_config"
    cd ansible/
    ansible-galaxy collection install -r requirements.yml -p ./collections
    ansible-playbook -i inventory/hosts.yml site.yml
    rm -f /tmp/cia_ssh_config
    ;;

  set-pve2-ip)
    # Change l'IP de gestion de pve2 pour éviter le conflit avec router_s1 (10.1.0.1)
    # Usage : ./deploy.sh set-pve2-ip [nouvelle_ip]   (défaut : 10.1.0.200)
    echo "--- Changement IP de gestion pve2 ---"
    load_secrets
    NEW_IP="${2:-10.1.0.200}"
    OLD_IP="${PROXMOX_S2_IP}"
    if [[ "$OLD_IP" == "$NEW_IP" ]]; then
      echo "pve2 est déjà à ${NEW_IP}, rien à faire."
      exit 0
    fi
    echo "IP actuelle de pve2 : ${OLD_IP}  →  Nouvelle IP : ${NEW_IP}"
    SSH_JUMP_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [[ "${PROXMOX_S2_NESTED:-false}" == "true" ]]; then
      SSH_JUMP_OPTS="$SSH_JUMP_OPTS -o ProxyJump=root@${PROXMOX_S1_IP}"
    fi
    ssh $SSH_JUMP_OPTS root@${OLD_IP} "
      set -e
      IFACE=\$(ip -br addr show | awk '/${OLD_IP//./\\.}/ {print \$1}' | head -1)
      if [[ -z \"\$IFACE\" ]]; then
        echo 'ERREUR : interface avec ${OLD_IP} non trouvée' >&2
        ip -br addr show >&2
        exit 1
      fi
      echo \"Interface : \$IFACE\"
      # Ajouter la nouvelle IP immédiatement (sans couper la connexion)
      ip addr add ${NEW_IP}/24 dev \$IFACE 2>/dev/null || true
      # Mettre à jour /etc/network/interfaces
      sed -i 's|${OLD_IP}|${NEW_IP}|g' /etc/network/interfaces
      echo 'Config /etc/network/interfaces mise à jour.'
      # Supprimer l'ancienne IP en arrière-plan (laisse le temps au SSH de se terminer)
      (sleep 10 && ip addr del ${OLD_IP}/24 dev \$IFACE 2>/dev/null; echo '[pve2] Ancienne IP supprimée.') &
      echo 'Nouvelle IP ${NEW_IP} active. Ancienne IP ${OLD_IP} sera supprimée dans 10s.'
    "
    echo "--- Mise à jour PROXMOX_S2_IP dans Doppler → ${NEW_IP} ---"
    doppler secrets set PROXMOX_S2_IP="${NEW_IP}"
    echo "=> pve2 désormais accessible via ${NEW_IP} (via ProxyJump pve1 si nested)"
    ;;

  all)
    $0 bootstrap-s1
    $0 bootstrap-s2
    $0 init
    $0 infra
    echo "--- Attente démarrage VMs (120s) ---"
    sleep 120
    $0 config
    ;;

  ssh-key)
    echo "--- Export clé SSH → /tmp/cia_infra ---"
    doppler secrets get SSH_PRIVATE_KEY --plain > /tmp/cia_infra
    chmod 600 /tmp/cia_infra
    echo "Clé disponible dans /tmp/cia_infra"
    trap '' EXIT
    ;;

  *)
    echo "Usage: ./deploy.sh <commande> [args]"
    echo ""
    echo "  bootstrap-s1       Crée vmbr1 + template Ubuntu sur pve1, injecte clé SSH"
    echo "  set-pve2-ip [ip]   Change l'IP de gestion de pve2 (défaut: 10.1.0.200)"
    echo "                     Évite le conflit avec router_s1 (10.1.0.1)"
    echo "                     Met à jour PROXMOX_S2_IP dans Doppler automatiquement"
    echo "  bootstrap-s2       Crée vmbr2 + template Ubuntu sur pve2, injecte clé SSH"
    echo "  init               Terraform init"
    echo "  infra              Terraform apply (crée les 6 VMs)"
    echo "  destroy            Terraform destroy"
    echo "  config             Ansible (configure tous les services)"
    echo "  all                Enchaîne : bootstrap-s1 → bootstrap-s2 → infra → config"
    echo "  ssh-key            Exporte la clé SSH depuis Doppler → /tmp/cia_infra"
    exit 1
    ;;
esac

# Cleanup clé SSH temporaire (sauf ssh-key qui gère lui-même)
[[ "$1" != "ssh-key" ]] && rm -f /tmp/cia_infra

echo "=== Done ==="

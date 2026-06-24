#!/usr/bin/env bash
# setup-secrets.sh - Remplit tous les secrets Doppler du projet, en une fois.
# Pre-requis : doppler login + doppler setup (projet lie au dossier) faits.
set -eu

# ====== VALEURS DES DEUX NOEUDS PROXMOX ======
# pve-s1 = Site 1
PVE_S1_IP="192.168.1.100"
PVE_S1_NODE="pve6"
PVE_S1_TOKEN_SECRET="aefd071e-4969-4cfc-9f74-31dd250eae6e"
# pve-s2 = Site 2
PVE_S2_IP="192.168.1.101"
PVE_S2_NODE="pve7"
PVE_S2_TOKEN_SECRET="de816277-2e9c-4078-97bb-cce43e3ee302"
# commun
PVE_ROOT_PASSWORD="rootroot1234"
PVE_TOKEN_ID="root@pam!terraform"
# =============================================

# --- Verifications ---
command -v doppler >/dev/null || { echo "Doppler CLI absent : brew install dopplerhq/cli/doppler"; exit 1; }
doppler configure get project >/dev/null 2>&1 || { echo "Projet Doppler non lie. Lance d'abord : doppler setup"; exit 1; }

# --- 1) Cle SSH dediee au projet (generee si absente) ---
KEY="$HOME/.ssh/cia"
if [ ! -f "$KEY" ]; then
  echo "Generation de la cle SSH $KEY..."
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "cia-iac" >/dev/null
fi

# --- 2) Generateurs de valeurs aleatoires ---
gen()    { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-24}"; }
genhex() { LC_ALL=C tr -dc 'a-f0-9'    </dev/urandom | head -c "${1:-40}"; }

echo "Envoi des secrets vers Doppler..."

# --- Proxmox / Terraform ---
doppler secrets set \
  PROXMOX_S1_IP="$PVE_S1_IP" \
  PROXMOX_S2_IP="$PVE_S2_IP" \
  PROXMOX_S1_API_URL="https://$PVE_S1_IP:8006/" \
  PROXMOX_S2_API_URL="https://$PVE_S2_IP:8006/" \
  PROXMOX_S1_NODE="$PVE_S1_NODE" \
  PROXMOX_S2_NODE="$PVE_S2_NODE" \
  PROXMOX_ROOT_PASSWORD="$PVE_ROOT_PASSWORD" \
  PROXMOX_S1_TOKEN_ID="$PVE_TOKEN_ID" \
  PROXMOX_S2_TOKEN_ID="$PVE_TOKEN_ID" \
  PROXMOX_S1_TOKEN_SECRET="$PVE_S1_TOKEN_SECRET" \
  PROXMOX_S2_TOKEN_SECRET="$PVE_S2_TOKEN_SECRET" \
  PROXMOX_S2_NESTED="false" \
  TEMPLATE_ID="9000" \
  TEMPLATE_ID_S2="9001" \
  VM_PASSWORD="$(gen 20)" >/dev/null

# --- Cles SSH ---
doppler secrets set \
  SSH_PUBLIC_KEY="$(cat "$KEY.pub")" \
  SSH_PRIVATE_KEY="$(cat "$KEY")" >/dev/null

# --- NetBox ---
doppler secrets set \
  NETBOX_SECRET_KEY="$(gen 60)" \
  NETBOX_DB_PASSWORD="$(gen 24)" \
  NETBOX_ADMIN_USER="admin" \
  NETBOX_ADMIN_PASSWORD="$(gen 20)" \
  NETBOX_API_TOKEN="$(genhex 40)" >/dev/null

# --- Elasticsearch / Kibana ---
doppler secrets set \
  ELASTIC_PASSWORD="$(gen 20)" \
  KIBANA_PASSWORD="$(gen 20)" >/dev/null

# --- OpenVPN ---
doppler secrets set \
  OPENVPN_CA_PASS="$(gen 20)" >/dev/null

echo "OK - Tous les secrets sont dans Doppler."
echo
echo "Mot de passe admin NetBox (note-le) :"
doppler secrets get NETBOX_ADMIN_PASSWORD --plain
echo
echo "Prochaine etape :  ./deploy.sh init   puis   ./deploy.sh all"

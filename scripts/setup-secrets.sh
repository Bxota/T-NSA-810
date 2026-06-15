#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# setup-secrets.sh — Remplit TOUS les secrets Doppler du projet, en une fois.
#
# Avant de lancer :
#   1) brew install dopplerhq/cli/doppler && doppler login
#   2) cd dans le dossier du projet, puis : doppler setup   (crée/lie le projet)
#   3) crée le token Proxmox (voir le guide) et récupère son "value"
#   4) remplis les 3 lignes ci-dessous, puis :  bash scripts/setup-secrets.sh
# ═══════════════════════════════════════════════════════════════════════════
set -eu

# ╔═══════════ À REMPLIR — valeurs des DEUX nœuds Proxmox (PHASE 1) ══════════╗
# pve-s1 = Site 1 "On-Prem"
PVE_S1_IP="192.168.1.241"                   # IP de gestion choisie à l'install de pve-s1
PVE_S1_NODE="pve-s1"                         # nom d'hôte donné à pve-s1 à l'install
PVE_S1_TOKEN_SECRET="value-du-token-pve-s1"  # token créé SUR pve-s1
# pve-s2 = Site 2 "Remote"
PVE_S2_IP="192.168.1.242"                   # IP de gestion choisie à l'install de pve-s2
PVE_S2_NODE="pve-s2"                         # nom d'hôte donné à pve-s2 à l'install
PVE_S2_TOKEN_SECRET="value-du-token-pve-s2"  # token créé SUR pve-s2
# commun
PVE_ROOT_PASSWORD="ton-mot-de-passe-root"   # mot de passe root choisi à l'install (idem sur les 2)
# ╚══════════════════════════════════════════════════════════════════════════╝

PVE_TOKEN_ID="root@pam!terraform"           # même ID de token sur les deux nœuds

# ── Vérifications ───────────────────────────────────────────────────────────
command -v doppler >/dev/null || { echo "❌ Doppler CLI absent : brew install dopplerhq/cli/doppler"; exit 1; }
doppler configure get project >/dev/null 2>&1 || { echo "❌ Projet Doppler non lié. Lance d'abord : doppler setup"; exit 1; }

# ── 1) Clé SSH dédiée au projet (générée si absente) ────────────────────────
KEY="$HOME/.ssh/cia"
if [[ ! -f "$KEY" ]]; then
  echo "🔑 Génération de la clé SSH $KEY…"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "cia-iac" >/dev/null
fi

# ── 2) Générateur de valeurs aléatoires ─────────────────────────────────────
gen()    { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-24}"; }   # mot de passe
genhex() { LC_ALL=C tr -dc 'a-f0-9'    </dev/urandom | head -c "${1:-40}"; }   # token netbox (hexa)

echo "📦 Envoi des secrets vers Doppler…"

# ── Proxmox / Terraform (deux nœuds distincts : pve-s1 et pve-s2) ───────────
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
  TEMPLATE_ID_S2="9000" \
  VM_PASSWORD="$(gen 20)" >/dev/null

# ── Clés SSH ────────────────────────────────────────────────────────────────
doppler secrets set \
  SSH_PUBLIC_KEY="$(cat "$KEY.pub")" \
  SSH_PRIVATE_KEY="$(cat "$KEY")" >/dev/null

# ── NetBox (gestion d'adresses IP) ──────────────────────────────────────────
doppler secrets set \
  NETBOX_SECRET_KEY="$(gen 60)" \
  NETBOX_DB_PASSWORD="$(gen 24)" \
  NETBOX_ADMIN_USER="admin" \
  NETBOX_ADMIN_PASSWORD="$(gen 20)" \
  NETBOX_API_TOKEN="$(genhex 40)" >/dev/null

# ── Elasticsearch / Kibana (logs) ───────────────────────────────────────────
doppler secrets set \
  ELASTIC_PASSWORD="$(gen 20)" \
  KIBANA_PASSWORD="$(gen 20)" >/dev/null

# ── OpenVPN ─────────────────────────────────────────────────────────────────
doppler secrets set \
  OPENVPN_CA_PASS="$(gen 20)" >/dev/null

echo "✅ Tous les secrets sont dans Doppler."
echo
echo "👉 Mot de passe admin NetBox (note-le) :"
doppler secrets get NETBOX_ADMIN_PASSWORD --plain
echo
echo "Prochaine étape :  ./deploy.sh init   puis   ./deploy.sh all"

#!/bin/bash
# bootstrap-proxmox.sh — Prépare un Proxmox vide : bridge réseau + template Ubuntu 24.04
# Usage : ./bootstrap-proxmox.sh --site <1|2> [--template-id 9000]
set -euo pipefail

SITE=""
TEMPLATE_ID=9000
UBUNTU_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_PATH="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"

usage() {
  echo "Usage: $0 --site <1|2> [--template-id <id>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="$2"; shift 2 ;;
    --template-id) TEMPLATE_ID="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$SITE" ]] && usage

if [[ "$SITE" == "1" ]]; then
  BRIDGE="vmbr1"
  BRIDGE_IP="10.1.0.254"
  BRIDGE_MASK="24"
  COMMENT="LAN Site 1 (10.1.0.0/24)"
elif [[ "$SITE" == "2" ]]; then
  BRIDGE="vmbr2"
  BRIDGE_IP="10.2.0.254"
  BRIDGE_MASK="24"
  COMMENT="LAN Site 2 (10.2.0.0/24)"
else
  echo "Erreur : --site doit être 1 ou 2"
  exit 1
fi

echo "=== Bootstrap Proxmox — Site $SITE ==="

# ── 1. Créer le bridge si absent ─────────────────────────────────────────────
if ip link show "$BRIDGE" &>/dev/null; then
  echo "[bridge] $BRIDGE déjà présent, on passe."
else
  echo "[bridge] Création de $BRIDGE ($BRIDGE_IP/$BRIDGE_MASK)..."
  cat >> /etc/network/interfaces <<EOF

auto ${BRIDGE}
iface ${BRIDGE} inet static
    address ${BRIDGE_IP}/${BRIDGE_MASK}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # ${COMMENT}
EOF
  ifup "$BRIDGE"
  echo "[bridge] $BRIDGE actif."
fi

# ── 2. Télécharger l'image cloud Ubuntu 24.04 ────────────────────────────────
if [[ -f "$IMG_PATH" ]]; then
  echo "[image] Déjà présente : $IMG_PATH"
else
  echo "[image] Téléchargement Ubuntu 24.04 cloud image..."
  mkdir -p "$(dirname "$IMG_PATH")"
  wget -q --show-progress -O "$IMG_PATH" "$UBUNTU_URL"
  echo "[image] Téléchargée."
fi

# ── 3. Créer le template VM ───────────────────────────────────────────────────
if [[ -f "/etc/pve/qemu-server/${TEMPLATE_ID}.conf" ]]; then
  echo "[template] VM $TEMPLATE_ID déjà existante, on passe."
else
  echo "[template] Création du template VM $TEMPLATE_ID..."

  qm create "$TEMPLATE_ID" \
    --name "ubuntu-2404-template" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --ostype l26

  qm importdisk "$TEMPLATE_ID" "$IMG_PATH" local-lvm

  qm set "$TEMPLATE_ID" \
    --scsihw virtio-scsi-pci \
    --scsi0 "local-lvm:vm-${TEMPLATE_ID}-disk-0,discard=on" \
    --ide2 local-lvm:cloudinit \
    --boot order=scsi0 \
    --serial0 socket \
    --vga serial0 \
    --agent enabled=1 \
    --ciuser cia

  qm template "$TEMPLATE_ID"
  echo "[template] Template VM $TEMPLATE_ID créé."
fi

echo "=== Bootstrap Site $SITE terminé ==="
echo "  Bridge : $BRIDGE @ $BRIDGE_IP/$BRIDGE_MASK"
echo "  Template : VM $TEMPLATE_ID"

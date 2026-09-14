#!/bin/bash
# bootstrap-proxmox.sh — Prépare un Proxmox vide : bridge réseau + template Ubuntu 24.04
# Usage : ./bootstrap-proxmox.sh --site <1|2> [--template-id 9000]
set -euo pipefail

SITE=""
TEMPLATE_ID=9000
UBUNTU_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_PATH="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"

# ── pfSense (firewall/routeur de site) ───────────────────────────────────────
# L'install pfSense n'est pas scriptable via cloud-init : on prépare l'ISO + une
# VM d'install bootant dessus. L'install est faite une fois en console (voir
# docs/runbooks/rebuild-full.md), puis convertie en template via `qm template`.
# ID unique par site pour éviter les conflits dans un cluster Proxmox partagé.
# Site 1 → 9100, Site 2 → 9101
PFSENSE_TEMPLATE_ID="${PFSENSE_TEMPLATE_ID:-910${SITE:-0}}"
PFSENSE_ISO_URL="${PFSENSE_ISO_URL:-https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz}"
PFSENSE_ISO_PATH="/var/lib/vz/template/iso/pfSense-CE-amd64.iso"

usage() {
  echo "Usage: $0 --site <1|2> [--template-id <id>] [--with-pfsense]"
  exit 1
}

WITH_PFSENSE="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="$2"; shift 2 ;;
    --template-id) TEMPLATE_ID="$2"; shift 2 ;;
    --with-pfsense) WITH_PFSENSE="true"; shift ;;
    *) usage ;;
  esac
done

[[ -z "$SITE" ]] && usage

if [[ "$SITE" == "1" ]]; then
  BRIDGE="vmbr1"
  BRIDGE_IP="10.1.0.254"
  BRIDGE_MASK="24"
  COMMENT="LAN Site 1 (10.1.0.0/24)"
  # Route vers le LAN du site distant via le pfSense local (porte le tunnel VPN).
  # Sans ça, l'hôte Proxmox (gw par défaut = box internet) ne sait pas joindre l'autre site.
  REMOTE_LAN="10.2.0.0/24"
  REMOTE_GW="10.1.0.1"
elif [[ "$SITE" == "2" ]]; then
  BRIDGE="vmbr2"
  BRIDGE_IP="10.2.0.254"
  BRIDGE_MASK="24"
  COMMENT="LAN Site 2 (10.2.0.0/24)"
  REMOTE_LAN="10.1.0.0/24"
  REMOTE_GW="10.2.0.1"
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
    post-up ip route add ${REMOTE_LAN} via ${REMOTE_GW} || true
    pre-down ip route del ${REMOTE_LAN} via ${REMOTE_GW} || true
EOF
  ifup "$BRIDGE"
  echo "[bridge] $BRIDGE actif."
fi

# ── 1b. Route vers le site distant (si le bridge existait déjà sans la route) ──
if ! ip route show "$REMOTE_LAN" | grep -q "$REMOTE_GW"; then
  echo "[route] Ajout route $REMOTE_LAN via $REMOTE_GW (site distant)."
  ip route add "$REMOTE_LAN" via "$REMOTE_GW" 2>/dev/null || true
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

# ── 4. pfSense : ISO + VM d'install (template firewall/routeur) ───────────────
# WAN = vmbr0 (internet), LAN = $BRIDGE (LAN du site). Install manuelle one-shot,
# puis `qm template $PFSENSE_TEMPLATE_ID`. Voir docs/runbooks/rebuild-full.md.
if [[ "$WITH_PFSENSE" == "true" ]]; then
  # ISO pfSense (décompressée si fournie en .gz)
  if [[ -f "$PFSENSE_ISO_PATH" ]]; then
    echo "[pfsense] ISO déjà présente : $PFSENSE_ISO_PATH"
  else
    echo "[pfsense] Téléchargement ISO pfSense CE..."
    mkdir -p "$(dirname "$PFSENSE_ISO_PATH")"
    if [[ "$PFSENSE_ISO_URL" == *.gz ]]; then
      wget -q --show-progress -O "${PFSENSE_ISO_PATH}.gz" "$PFSENSE_ISO_URL"
      gunzip -f "${PFSENSE_ISO_PATH}.gz"
    else
      wget -q --show-progress -O "$PFSENSE_ISO_PATH" "$PFSENSE_ISO_URL"
    fi
    echo "[pfsense] ISO prête : $PFSENSE_ISO_PATH"
  fi

  if [[ -f "/etc/pve/qemu-server/${PFSENSE_TEMPLATE_ID}.conf" ]]; then
    echo "[pfsense] VM/template $PFSENSE_TEMPLATE_ID déjà existant, on passe."
  else
    echo "[pfsense] Création VM d'install pfSense $PFSENSE_TEMPLATE_ID..."
    # NIC0 = WAN (vmbr0), NIC1 = LAN ($BRIDGE). Pas de cloud-init (pfSense l'ignore).
    qm create "$PFSENSE_TEMPLATE_ID" \
      --name "pfsense-template" \
      --memory 1024 \
      --cores 2 \
      --net0 "virtio,bridge=vmbr0" \
      --net1 "virtio,bridge=${BRIDGE}" \
      --scsihw virtio-scsi-pci \
      --ostype other \
      --serial0 socket \
      --vga serial0

    qm set "$PFSENSE_TEMPLATE_ID" \
      --scsi0 "local-lvm:8" \
      --ide2 "local:iso/$(basename "$PFSENSE_ISO_PATH"),media=cdrom" \
      --boot "order=ide2;scsi0"

    echo "[pfsense] VM $PFSENSE_TEMPLATE_ID créée (boot sur ISO)."
    echo "[pfsense] >>> ACTION MANUELLE : installer pfSense en console"
    echo "          (qm terminal $PFSENSE_TEMPLATE_ID), puis :"
    echo "          qm set $PFSENSE_TEMPLATE_ID --ide2 none --boot order=scsi0"
    echo "          qm template $PFSENSE_TEMPLATE_ID"
  fi
fi

echo "=== Bootstrap Site $SITE terminé ==="
echo "  Bridge : $BRIDGE @ $BRIDGE_IP/$BRIDGE_MASK"
echo "  Template Ubuntu : VM $TEMPLATE_ID"
[[ "$WITH_PFSENSE" == "true" ]] && echo "  Template pfSense : VM $PFSENSE_TEMPLATE_ID"

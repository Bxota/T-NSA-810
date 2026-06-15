#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# create-nested-pve.sh  —  PHASE 1 : virtualiser les deux nœuds Proxmox
# ---------------------------------------------------------------------------
# À lancer SUR LE PROXMOX PARENT (le nœud "pve"), en root.
#
# Crée les deux Proxmox de ton archi (cf. docs/infra_V3.png), en les
# virtualisant dans ton pve actuel (tu n'as qu'une machine physique) :
#   - pve-s1  → Site 1 "On-Prem"  (hébergera pfSense-S1, NetBox, Elastic)
#   - pve-s2  → Site 2 "Remote"   (hébergera pfSense-S2, Bastion, WebApp)
#
# Chaque VM a la virtualisation imbriquée (--cpu host) pour faire tourner des
# VMs à l'intérieur. On boote sur l'ISO Proxmox VE : tu installes Proxmox une
# fois via la console (noVNC), puis le pipeline (deploy.sh) fait tout le reste.
#
# Usage :
#   ./create-nested-pve.sh create     # crée les 2 VMs et les démarre (défaut)
#   ./create-nested-pve.sh iso        # télécharge seulement l'ISO Proxmox VE
#   ./create-nested-pve.sh destroy    # supprime pve-s1 et pve-s2
#   ./create-nested-pve.sh status     # affiche l'état des deux VMs
#
# Réduire la RAM pour un test léger :
#   PVE_S1_MEM=6144 PVE_S2_MEM=4096 ./create-nested-pve.sh
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ───────────────────────────── PARAMÈTRES ─────────────────────────────────
ISO_STORAGE="${ISO_STORAGE:-local}"
ISO_NAME="${ISO_NAME:-proxmox-ve_8.4-1.iso}"
ISO_DIR="${ISO_DIR:-/var/lib/vz/template/iso}"
ISO_URL="${ISO_URL:-https://enterprise.proxmox.com/iso/proxmox-ve_8.4-1.iso}"

DISK_STORAGE="${DISK_STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"

PVE_S1_ID="${PVE_S1_ID:-701}";  PVE_S1_NAME="${PVE_S1_NAME:-pve-s1}"
PVE_S1_CORES="${PVE_S1_CORES:-4}";  PVE_S1_MEM="${PVE_S1_MEM:-12288}";  PVE_S1_DISK="${PVE_S1_DISK:-120}"

PVE_S2_ID="${PVE_S2_ID:-702}";  PVE_S2_NAME="${PVE_S2_NAME:-pve-s2}"
PVE_S2_CORES="${PVE_S2_CORES:-2}";  PVE_S2_MEM="${PVE_S2_MEM:-8192}";   PVE_S2_DISK="${PVE_S2_DISK:-80}"

START_AFTER="${START_AFTER:-1}"
TAG="${TAG:-nested-pve}"

NODES=(
  "$PVE_S1_ID $PVE_S1_NAME $PVE_S1_CORES $PVE_S1_MEM $PVE_S1_DISK"
  "$PVE_S2_ID $PVE_S2_NAME $PVE_S2_CORES $PVE_S2_MEM $PVE_S2_DISK"
)

# ───────────────────────────── HELPERS ────────────────────────────────────
log()  { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err()  { echo -e "\033[1;31m[x]\033[0m $*" >&2; }
require_root() { [[ $EUID -eq 0 ]] || { err "À lancer en root sur le shell du Proxmox parent."; exit 1; }; }

check_nested_enabled() {
  local f
  for f in /sys/module/kvm_intel/parameters/nested /sys/module/kvm_amd/parameters/nested; do
    if [[ -f "$f" ]]; then
      local v; v=$(cat "$f")
      [[ "$v" == "Y" || "$v" == "1" ]] && { log "Virtualisation imbriquée active ($f = $v)."; return 0; }
    fi
  done
  warn "La virtualisation imbriquée KVM n'est PAS active sur le parent."
  warn "Active-la (Intel) :  echo 'options kvm-intel nested=1' > /etc/modprobe.d/kvm-nested.conf"
  warn "             (AMD) :  echo 'options kvm-amd nested=1'  > /etc/modprobe.d/kvm-nested.conf"
  warn "Puis :  modprobe -r kvm_intel && modprobe kvm_intel   (ou reboot)."
  warn "Sans ça, les VMs internes ne démarreront pas. Je continue dans 5 s (Ctrl-C pour annuler)."
  sleep 5
}

check_memory() {
  local need_mb=$(( PVE_S1_MEM + PVE_S2_MEM ))
  local total_mb; total_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
  log "RAM parent : ${total_mb} Mo — demandée par les deux nœuds : ${need_mb} Mo."
  (( need_mb > total_mb - 2048 )) && warn "Peu de marge. Réduis avec PVE_S1_MEM / PVE_S2_MEM."
  return 0
}

iso_volid() { echo "${ISO_STORAGE}:iso/${ISO_NAME}"; }

ensure_iso() {
  local path="${ISO_DIR}/${ISO_NAME}"
  [[ -f "$path" ]] && { log "ISO déjà présente : $path"; return 0; }
  log "Téléchargement de l'ISO Proxmox VE → $path"
  mkdir -p "$ISO_DIR"
  wget -q --show-progress -O "$path" "$ISO_URL" || {
    err "Échec du téléchargement. Récupère l'ISO sur https://www.proxmox.com/downloads"
    err "et dépose-la dans $ISO_DIR (UI : storage 'local' > ISO Images > Upload)."
    exit 1
  }
  log "ISO téléchargée."
}

# ───────────────────────────── CREATE ─────────────────────────────────────
create_nodes() {
  ensure_iso
  local iso; iso="$(iso_volid)"
  for spec in "${NODES[@]}"; do
    read -r vmid name cores mem disk <<<"$spec"
    if qm status "$vmid" &>/dev/null; then warn "VMID $vmid ($name) existe déjà — sauté."; continue; fi
    log "Création de $name (VMID $vmid) : ${cores} vCPU, ${mem} Mo, ${disk} Go."
    qm create "$vmid" \
      --name "$name" --tags "$TAG" \
      --cores "$cores" --sockets 1 --cpu host --memory "$mem" \
      --ostype l26 --machine q35 --bios seabios \
      --scsihw virtio-scsi-single --scsi0 "${DISK_STORAGE}:${disk}" \
      --net0 "virtio,bridge=${BRIDGE}" \
      --ide2 "${iso},media=cdrom" \
      --boot "order=scsi0;ide2" \
      --agent enabled=1
    [[ "$START_AFTER" == "1" ]] && { qm start "$vmid"; log "$name démarré → ouvre la Console (noVNC) pour installer Proxmox."; }
  done
  echo
  log "PHASE 1 terminée. Pour CHAQUE nœud :"
  echo "   1) Console (>_ noVNC) → installe Proxmox VE sur le disque virtuel."
  echo "      IP de gestion : une IP libre du LAN du parent (ex. pve-s1=.241, pve-s2=.242)."
  echo "      Évite 10.1.0.x / 10.2.0.x (réservées aux VMs internes). Note le mot de passe root."
  echo "   2) Après install :  qm set <vmid> --ide2 none && qm reboot <vmid>   (éjecte l'ISO)."
  echo "   3) Sur CHAQUE nœud, crée un token API :"
  echo "        pveum user token add root@pam terraform --privsep 0"
  echo "   4) Reporte IP, mots de passe et tokens dans scripts/setup-secrets.sh (PHASE 2)."
}

destroy_nodes() {
  for spec in "${NODES[@]}"; do
    read -r vmid name _ <<<"$spec"
    if qm status "$vmid" &>/dev/null; then
      log "Suppression de $name (VMID $vmid)…"; qm stop "$vmid" &>/dev/null || true; qm destroy "$vmid" --purge
    else warn "VMID $vmid ($name) absent."; fi
  done
  log "Nœuds nested supprimés."
}

status_nodes() {
  for spec in "${NODES[@]}"; do
    read -r vmid name _ <<<"$spec"
    printf "  %-8s (VMID %s) : " "$name" "$vmid"; qm status "$vmid" 2>/dev/null || echo "absent"
  done
}

# ───────────────────────────── MAIN ───────────────────────────────────────
require_root
case "${1:-create}" in
  create)  check_nested_enabled; check_memory; create_nodes ;;
  iso)     ensure_iso ;;
  destroy) destroy_nodes ;;
  status)  status_nodes ;;
  *) err "Argument inconnu : $1  (create|iso|destroy|status)"; exit 1 ;;
esac

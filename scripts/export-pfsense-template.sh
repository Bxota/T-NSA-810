set -euo pipefail

TEMPLATE_ID="${TEMPLATE_ID:-9100}"
DUMP_DIR="${DUMP_DIR:-/var/lib/vz/dump}"

echo "[*] Export du template $TEMPLATE_ID (compression zstd)…"
vzdump "$TEMPLATE_ID" --dumpdir "$DUMP_DIR" --compress zstd --mode stop

ARCHIVE=$(ls -t "$DUMP_DIR"/vzdump-qemu-"$TEMPLATE_ID"-*.vma.zst | head -1)
echo
echo "[OK] Archive créée :"
echo "     $ARCHIVE"
echo "     taille : $(du -h "$ARCHIVE" | cut -f1)"
echo
echo "=== POUR L'INSTALLER SUR UN AUTRE PVE ==="
echo "1) Télécharger l'archive :"
echo "     scp root@<ce-noeud>:$ARCHIVE  ./"
echo "2) La déposer sur le nouveau PVE :"
echo "     scp ./$(basename "$ARCHIVE")  root@<nouveau-pve>:/var/lib/vz/dump/"
echo "3) Restaurer puis convertir en template (sur le nouveau PVE) :"
echo "     qmrestore /var/lib/vz/dump/$(basename "$ARCHIVE")  <nouvel-id>"
echo "     qm template <nouvel-id>"
echo
echo "Note : l'archive est un .vma.zst (déjà compressé). 'qmrestore' la décompresse"
echo "       et recrée la VM directement — pas besoin de dézipper à la main."

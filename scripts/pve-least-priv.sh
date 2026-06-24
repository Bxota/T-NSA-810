set -euo pipefail

ROLE="TerraformProv"
USER="terraform@pve"
TOKEN="provider"

# Privilèges strictement nécessaires au provider bpg/proxmox (clone, config VM,

PRIVS="VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network \
VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt \
Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Use"

echo "[*] Création du rôle $ROLE…"
pveum role add "$ROLE" -privs "$PRIVS" 2>/dev/null || pveum role modify "$ROLE" -privs "$PRIVS"

echo "[*] Création de l'utilisateur $USER…"
pveum user add "$USER" 2>/dev/null || echo "    (existe déjà)"

echo "[*] Attribution du rôle sur / (à l'utilisateur ET au token)…"
pveum aclmod / -user "$USER" -role "$ROLE"

echo "[*] Création du token $USER!$TOKEN (avec séparation de privilèges)…"
pveum user token add "$USER" "$TOKEN" --privsep 1 || echo "    (token déjà créé)"
pveum aclmod / -token "${USER}!${TOKEN}" -role "$ROLE"

echo
echo "[OK] Token de moindre privilège prêt."
echo "     Remplace dans Doppler :"
echo "       PROXMOX_S1_TOKEN_ID = ${USER}!${TOKEN}   (idem S2)"
echo "       PROXMOX_S1_TOKEN_SECRET = <le secret affiché ci-dessus>"
echo "     Puis ./deploy.sh init pour vérifier que Terraform fonctionne avec ce token."

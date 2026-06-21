# deploy-ansible.ps1
param(
    [string]$Tags = "",
    [switch]$BootstrapOnly
)

$PROXMOX    = "root@192.168.241.129"
$SSH_KEY    = "$env:USERPROFILE\.ssh\cia_infra"
$REMOTE_DIR = "/opt/cia"

function Run-SSH($Cmd) {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $PROXMOX $Cmd
}

function Write-UnixScript($Path, $Lines) {
    $content = $Lines -join "`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

# 1. Recuperer le service token depuis Doppler (local)
Write-Host "=== Recuperation du service token ===" -ForegroundColor Cyan
$deployToken = doppler secrets get PROXMOX_DEPLOY_TOKEN --plain
if (-not $deployToken) { Write-Error "PROXMOX_DEPLOY_TOKEN introuvable"; exit 1 }

# 2. Bootstrap Proxmox (apt + Doppler + Ansible + token)
Write-Host "=== Bootstrap Proxmox ===" -ForegroundColor Cyan
Write-UnixScript "$env:TEMP\bootstrap.sh" @(
    "#!/bin/bash",
    "set -e",
    "export DEBIAN_FRONTEND=noninteractive",
    "# Supprimer les repos enterprise qui bloquent apt",
    "rm -f /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/pve-enterprise.sources",
    "# Supprimer le doublon pve-no-subscription dans sources.list",
    "sed -i '/pve-no-subscription/d' /etc/apt/sources.list",
    "apt-get update -qq",
    "apt-get install -y -qq ansible curl ca-certificates",
    "# Installer Doppler via repo APT avec gpg en chemin absolu",
    "if ! command -v doppler &>/dev/null; then",
    "  curl -fsSL 'https://packages.doppler.com/public/cli/gpg.DE2A7741.key' | /usr/bin/gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg",
    "  echo 'deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main' > /etc/apt/sources.list.d/doppler-cli.list",
    "  apt-get update -qq && apt-get install -y -qq doppler",
    "fi",
    "mkdir -p /opt/cia"
)

scp -i $SSH_KEY -o StrictHostKeyChecking=no "$env:TEMP\bootstrap.sh" "${PROXMOX}:/tmp/bootstrap.sh"
Run-SSH "bash /tmp/bootstrap.sh && rm /tmp/bootstrap.sh"

# 3. Deposer le token sur Proxmox via SSH
Run-SSH "printf '%s' '$deployToken' > /root/.doppler-token && chmod 600 /root/.doppler-token"
Write-Host "Bootstrap termine" -ForegroundColor Green

if ($BootstrapOnly) {
    Write-Host "Mode BootstrapOnly - arret ici" -ForegroundColor Yellow
    exit 0
}

# 4. Copier ansible/ sur Proxmox
Write-Host "=== Copie du dossier ansible/ ===" -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no -r "$PSScriptRoot\ansible" "${PROXMOX}:${REMOTE_DIR}/"
Write-Host "Copie terminee" -ForegroundColor Green

# 5. Creer et envoyer le script ansible (LF pur)
Write-Host "=== Lancement Ansible ===" -ForegroundColor Cyan
$tagOption = if ($Tags) { "--tags $Tags" } else { "" }
Write-UnixScript "$env:TEMP\run-ansible.sh" @(
    "#!/bin/bash",
    "set -e",
    "export DEBIAN_FRONTEND=noninteractive",
    "cd /opt/cia",
    "TOKEN=$(cat /root/.doppler-token)",
    "doppler run --token=`$TOKEN -- ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml $tagOption"
)

scp -i $SSH_KEY -o StrictHostKeyChecking=no "$env:TEMP\run-ansible.sh" "${PROXMOX}:/tmp/run-ansible.sh"
Run-SSH "bash /tmp/run-ansible.sh && rm /tmp/run-ansible.sh"

Write-Host "=== Done ===" -ForegroundColor Green

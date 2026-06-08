# fix-deprecated.ps1 — Corrige uniquement les download_file dépréciés
# A lancer depuis la racine du repo

$files = @(
    "terraform\main.tf"
)

$old = "proxmox_virtual_environment_download_file"
$new = "proxmox_download_file"

foreach ($file in $files) {
    $content = Get-Content $file -Raw -Encoding UTF8
    $content = $content -replace [regex]::Escape($old), $new
    [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
    Write-Host "OK : $file"
}

Write-Host "Done."

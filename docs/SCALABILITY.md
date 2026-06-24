# Scalabilité — onboarder un nouveau site (S3, S4, …)

L'infra est pilotée par une **map de sites** (`terraform/sites.auto.tfvars`) et
déployée par `for_each`. Un seul provider gère tout le cluster (chaque ressource
cible son nœud via `node_name`). **Ajouter un site = ajouter une entrée**, aucun
nouveau module ni bloc Terraform.

## Architecture du code
- `providers.tf` : **un** provider Proxmox (cluster).
- `variables.tf` : la variable `sites` (typée).
- `sites.auto.tfvars` : la **topologie** (source de vérité, versionnée).
- `locals.tf` : aplatit les VMs de tous les sites en une map `site-service`.
- `main.tf` : `for_each` sur les sites (pfSense) et sur les VMs (applicatives).

## Ajouter un Site 3 — étapes

### 1. Prérequis sur le nouveau nœud Proxmox (pveX)
- Le nœud rejoint le **cluster** (corosync).
- Bridge LAN créé (ex. `vmbr3`, `10.3.0.254/24`) + template Ubuntu + template pfSense
  (cf. `scripts/bootstrap-proxmox.sh` et clone du template pfSense).

### 2. Décommenter / adapter le bloc dans `sites.auto.tfvars`
```hcl
s3 = {
  node             = "pve4"
  lan_bridge       = "vmbr3"
  gateway          = "10.3.0.1"
  pfsense_vmid     = 406
  pfsense_template = 9102
  ubuntu_template  = 9003
  vms = {
    app = { vmid = 407, cores = 2, memory = 4096, disk = 20, ip = "10.3.0.10/24" }
  }
}
```

### 3. Déployer
```bash
./deploy.sh infra        # Terraform crée pfSense-s3 + les VMs du site
```
Puis : config pfSense (clone du template + import d'un `config-s3.xml`), bridge,
VPN vers les autres sites, et `./deploy.sh config` pour Ansible.

### 4. Conventions d'adressage (multi-site ready)
- Site N → LAN `10.N.0.0/24`, gateway `10.N.0.1` (pfSense), Proxmox `10.N.0.254`.
- VMIDs : pfSense `4{N}0`, services `4{N}1+` ; templates `910{N}` (pfSense) / `900{N}` (Ubuntu).

## Pourquoi un seul provider
Terraform ne peut pas choisir un provider aliasé dynamiquement dans un `for_each`.
Comme les nœuds sont dans **un même cluster**, un provider unique (API du cluster)
suffit, et `node_name` route chaque ressource vers le bon nœud. C'est ce qui rend
le `for_each` multi-sites possible.

## Secrets Doppler requis (modèle cluster)
`PROXMOX_API_URL`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET` (le token de moindre
privilège créé par `scripts/pve-least-priv.sh`), `SSH_PUBLIC_KEY`, `VM_PASSWORD`,
+ les secrets NetBox/Elastic/OpenVPN.

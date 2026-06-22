# Runbook — Ajouter un site (onboarding d'un Site N)

Procédure d'ajout d'un nouveau site à l'infrastructure CIA. L'architecture est
prévue pour passer à l'échelle : chaque site suit la même convention, on duplique
les briques existantes. Exemple ici avec un **Site 3** (`pve6`, LAN `10.3.0.0/24`).

> Convention d'adressage : **Site N → `10.N.0.0/24`**, gateway pfSense `10.N.0.1`,
> bridge LAN `vmbrN`. Le VPN reste en hub-and-spoke : pfSense_s1 est le serveur,
> chaque nouveau site est un client OpenVPN supplémentaire.

## 0. Pré-requis

- Un node Proxmox `pve6` joint au cluster (`pvecm add` ou nouveau cluster).
- Accès Doppler en écriture.
- Le tunnel/clé SSH de déploiement (`./deploy.sh ssh-key`).

## 1. Secrets Doppler

Ajouter pour le nouveau node :

```
PROXMOX_S3_IP, PROXMOX_S3_API_URL, PROXMOX_S3_NODE,
PROXMOX_S3_TOKEN_ID, PROXMOX_S3_TOKEN_SECRET
```

## 2. Réseau Proxmox (sur pve6)

```bash
# Bridge LAN du Site 3 + IP de gateway temporaire (avant pfSense)
# vmbr0 = WAN (DHCP), vmbr3 = LAN 10.3.0.0/24
```

Bootstrap des templates (ubuntu + pfSense) :

```bash
SITE=3 ./deploy.sh bootstrap-s3      # ou bootstrap générique ciblant pve6
# Installer pfSense en console one-shot → template (voir pfsense-install.md)
```

## 3. Terraform

**`terraform/providers.tf`** — ajouter le provider du Site 3 :

```hcl
provider "proxmox" {
  alias     = "pve_s3"
  endpoint  = var.proxmox_s3_api_url
  api_token = "${var.proxmox_s3_token_id}=${var.proxmox_s3_token_secret}"
  insecure  = true
}
```

**`terraform/locals.tf`** — ajouter les IP du Site 3 :

```hcl
pfsense_s3 = "10.3.0.1/24"
# + toute VM applicative du site, ex. :
# app_s3   = "10.3.0.30/24"
```
(et `gw.s3 = split("/", local.ip.pfsense_s3)[0]`)

**`terraform/main.tf`** — bloc pfSense + VMs du Site 3 (copier le module
`pfsense_s2`, IDs 5xx, `providers = { proxmox = proxmox.pve_s3 }`, `lan_bridge = "vmbr3"`).

**`terraform/variables.tf`** — déclarer `proxmox_s3_*`. **`deploy.sh`** — exporter
les `PROXMOX_S3_*` (bloc `load_secrets` + `build_tf_args`).

## 4. VPN — étendre le site-à-site

Le Site 3 est un **nouveau client OpenVPN** vers pfSense_s1 (serveur, hub). Dans
`ansible/roles/pfsense/templates/config.xml.j2`, le rôle `client` est déjà
paramétré ; il suffit d'ajouter l'hôte. Côté serveur (s1), ajouter l'**iroute**
du LAN Site 3 dans le Client-Specific-Override (sinon les hôtes 10.3.0.x ne sont
pas routés — cf. le CSC existant pour 10.2.0.0/24) :

```xml
<openvpn-csc>
  <common_name>client-s3</common_name>
  <remote_network>10.3.0.0/24</remote_network>
  <server_list>1</server_list>
</openvpn-csc>
```

> ⚠️ Chaque client doit avoir un **certificat à CN unique** (`client-s3`) pour que
> l'iroute lui soit associé. Étendre `pki-bootstrap.sh.j2` pour générer ce cert.

## 5. DNS interne (Unbound)

Dans `group_vars/all.yml` : domaine `s3.local`, et ajouter les `dns_records` du
site. Les `domainoverrides` réciproques entre sites sont générés par le template ;
vérifier que s1↔s3 et s2↔s3 se résolvent.

## 6. Ansible — inventaire

**`ansible/inventory/hosts.yml`** :
- groupe `pfsense` → `pfsense_s3` (`ansible_host: 10.3.0.1`, `router_role: client`,
  `local_lan: 10.3.0.0/24`, `remote_*` vers s1)
- groupe `site3` → VMs applicatives du site

## 7. Déploiement

```bash
./deploy.sh init
./deploy.sh infra      # provisionne les VMs du Site 3
./deploy.sh config     # configure pfSense_s3 + services + filebeat
```

## 8. Vérifications

| Test | Commande |
|------|----------|
| Tunnel s3 ↔ s1 | `ping 10.1.0.1` depuis pfSense_s3 |
| Routage LAN distant | `ping 10.1.0.20` depuis une VM du Site 3 |
| Logs → ES (via VPN) | présence de `host.name: "cia-*-s3"` dans Kibana Discover |
| IPAM | les VMs du Site 3 apparaissent dans NetBox (sync auto < 15 min) |
| DNS | `dig netbox.s1.local` résout depuis le Site 3 |

## Notes de scalabilité

- **Adressage** : déterministe (`10.N.0.0/24`) → aucun chevauchement, planification triviale.
- **VPN** : topologie hub-and-spoke (s1 = hub). Au-delà de ~5 sites, envisager un
  full-mesh ou un routeur de transit pour éviter que tout le trafic inter-sites
  transite par s1.
- **Observabilité / IPAM** : aucun changement — Filebeat et le sync NetBox prennent
  automatiquement en charge les nouveaux hôtes.

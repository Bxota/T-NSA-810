# Déploiement de bout en bout / DRP — reconstruire l'infra sur des nœuds neufs

Procédure complète pour reconstruire l'infrastructure CIA sur **une nouvelle paire de
nœuds Proxmox** (cluster), à partir de zéro. Sert aussi de **plan de reprise (DRP)**.

Hypothèse : 2 nœuds Proxmox (ex. `pveA`, `pveB`) déjà installés et **dans le même
cluster**. Si tes nœuds sont eux-mêmes des VMs (nested), vérifie la PHASE 0.

Plan d'adressage de référence (réutilisable) :
| | LAN | pfSense (gw) | Proxmox node | VMs |
|---|---|---|---|---|
| Site 1 | 10.1.0.0/24 | 10.1.0.1 | pveA (vmbr1 @ .254) | netbox .10, elastic .20 |
| Site 2 | 10.2.0.0/24 | 10.2.0.1 | pveB (vmbr2 @ .254) | bastion .5, web .30 |
| VPN | 10.8.0.0/24 | 10.8.0.1↔.2 | | tunnel OpenVPN |

---

## PHASE 0 — Prérequis

**Sur ta machine (Mac/Linux)** :
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
brew install ansible doppler
brew install hudochenkov/sshpass/sshpass
```

**Sur les nœuds Proxmox** :
- RAM ≥ 16–20 Go et `local-lvm` ≥ 50 Go par nœud (sinon le pool sature → corruption).
- **Si les nœuds sont nested** (VMs Proxmox dans un Proxmox parent) : sur le parent,
  `echo 'options kvm-intel nested=1' > /etc/modprobe.d/kvm-nested.conf` + `--cpu host`
  sur les VMs-nœuds, puis reboot. Sans ça, les VMs internes ne démarrent pas.

---

## PHASE 1 — Récupérer les templates pfSense

Sur l'**ancien** nœud qui héberge les templates (9100 / 9101) :
```bash
./scripts/export-pfsense-template.sh                 # exporte 9100
TEMPLATE_ID=9101 ./scripts/export-pfsense-template.sh # exporte 9101
```
Copie les archives sur les **nouveaux** nœuds puis restaure (templates locaux à chaque nœud) :
```bash
# depuis l'ancien nœud
scp /var/lib/vz/dump/vzdump-qemu-9100-*.vma.zst root@<pveA>:/var/lib/vz/dump/
scp /var/lib/vz/dump/vzdump-qemu-9101-*.vma.zst root@<pveB>:/var/lib/vz/dump/
# sur pveA
qmrestore /var/lib/vz/dump/vzdump-qemu-9100-*.vma.zst 9100 && qm template 9100
# sur pveB
qmrestore /var/lib/vz/dump/vzdump-qemu-9101-*.vma.zst 9101 && qm template 9101
```

---

## PHASE 2 — Préparer les nœuds (bridges + template Ubuntu)

Les VMs Linux clonent un template Ubuntu et ont besoin des bridges LAN.
Le plus simple : via `deploy.sh` (PHASE 5), qui appelle `scripts/bootstrap-proxmox.sh`.
Sinon, manuellement sur chaque nœud : créer `vmbr1` (pveA, 10.1.0.254/24) / `vmbr2`
(pveB, 10.2.0.254/24) + le template Ubuntu 9000 (pveA) / 9001 (pveB)
(cf. `scripts/bootstrap-proxmox.sh`).

---

## PHASE 3 — Token Proxmox de moindre privilège

Sur un nœud du cluster (la base users est partagée) :
```bash
./scripts/pve-least-priv.sh
```
Note l'ID `terraform@pve!provider` et le secret affiché.

---

## PHASE 4 — Secrets Doppler

```bash
cd ~/Documents/T-NSA-810-BDX_1
doppler login && doppler setup        # projet cia / config dev
```
Renseigne (adapte aux IP des nouveaux nœuds) :
```bash
# Terraform (modèle cluster)
doppler secrets set PROXMOX_API_URL=https://<ip-pveA>:8006/
doppler secrets set PROXMOX_TOKEN_ID='terraform@pve!provider'
doppler secrets set PROXMOX_TOKEN_SECRET=<secret PHASE 3>
# Bootstrap SSH + inventaire Ansible (par nœud)
doppler secrets set PROXMOX_S1_IP=<ip-pveA>  PROXMOX_S2_IP=<ip-pveB>
doppler secrets set PROXMOX_ROOT_PASSWORD=<root des nœuds>
# Templates Ubuntu
doppler secrets set TEMPLATE_ID=9000 TEMPLATE_ID_S2=9001
```
Puis génère le reste (clés SSH + mots de passe NetBox/Elastic/OpenVPN aléatoires) :
```bash
bash scripts/setup-secrets.sh   # note le mot de passe admin NetBox affiché
```

> Les deux nœuds doivent être **joignables depuis ta machine** sur le port 8006
> (teste `nc -vz <ip-pveB> 8006`). Le `ping` peut échouer (ICMP filtré) sans que ce
> soit bloquant.

---

## PHASE 5 — Topologie + déploiement Terraform

Édite `terraform/sites.auto.tfvars` : mets les **noms des nouveaux nœuds** (`node = "pveA"`
/ `"pveB"`), garde les VMIDs/IPs (ou adapte). Puis :
```bash
./deploy.sh init
./deploy.sh bootstrap-s1     # pveA : vmbr1 + template Ubuntu 9000 + clé SSH
./deploy.sh bootstrap-s2     # pveB : vmbr2 + template Ubuntu 9001
./deploy.sh infra            # Terraform : clone pfSense (9100/9101) + crée les 4 VMs
```
À la fin : `cia-pf-s1`, `cia-pf-s2`, netbox, elastic, bastion, web sont créés.

---

## PHASE 6 — Configurer pfSense (import config.xml)

Pour **chaque** pfSense (cloné, démarre déjà installé) :
1. Console (noVNC) → option **2** → LAN = `10.1.0.1/24` (pf-s1) / `10.2.0.1/24` (pf-s2).
2. Tunnel SSH via le nœud : `ssh -L 8443:10.1.0.1:443 root@<ip-pveA>` (S1, port 8443)
   et `ssh -L 8444:10.2.0.1:443 root@<ip-pveB>` (S2, **port 8444 ≠**).
3. GUI `https://localhost:8443` (resp. 8444), `admin / pfSenseCIA!`.
4. **⚠️ Avant d'importer côté S2** : le `config-pf-s2…xml` contient l'**IP WAN de pf-s1**
   (OpenVPN client). Sur des nœuds neufs cette IP change → relève la nouvelle IP WAN
   de pf-s1 (Status → Interfaces) et corrige `server_addr` dans le XML S2.
5. Diagnostics → Backup & Restore → Restore → importe `pfsense-exported/config-pf-sX…xml`.

> Rappel des réglages déjà dans les configs exportées : OpenVPN AES-256-CBC,
> DNS Resolver (Outgoing=LAN, domain override vers la LAN de l'autre, Access List
> autorisant le subnet distant), NAT bastion 2222→10.2.0.5:22, kill switch (désactivé).

---

## PHASE 7 — Configurer les services (Ansible)

```bash
./deploy.sh config     # common + netbox + elastic/kibana + bastion + web + filebeat + metricbeat
./deploy.sh ipam       # peuple NetBox (sites, préfixes, IPs)
```

---

## PHASE 8 — Validation (tests de recette)

Depuis netbox (`ssh -i ~/.ssh/cia -J root@<ip-pveA> cia@10.1.0.10`) :
```bash
ping -c2 8.8.8.8 ; traceroute 8.8.8.8     # NAT pfSense (1er saut = 10.1.0.1)
ping -c2 10.2.0.30                         # VPN inter-sites
dig +short web.s2.cia @10.1.0.1            # DNS forwarding → 10.2.0.30
```
- pfSense : Status → OpenVPN (tunnel up), kill switch test (activer/désactiver).
- spec1 : `curl http://<WAN pf-s2>` depuis le segment WAN → bloqué.
- spec2 : `ssh -p 2222 -i ~/.ssh/cia cia@<WAN pf-s2>` depuis le segment WAN → bastion.
- Kibana `http://localhost:5601` (tunnel) : logs + métriques des 4 hôtes + index `pfsense-*`.

---

## PHASE 9 — Figer

```bash
# snapshots de rollback
qm snapshot <vmid> working-v1   # pour 400..405 sur leurs nœuds
# ré-exporter les config.xml validées et écraser pfsense-exported/
```

---

## Multi-site (S3)
Voir `docs/SCALABILITY.md` : décommenter le bloc `s3` dans `sites.auto.tfvars`,
transférer un template pfSense sur le nœud, `./deploy.sh infra`.

## Ordre résumé
PHASE 0 prérequis → 1 templates pfSense → 2 bridges+Ubuntu → 3 token → 4 Doppler →
5 `init`/`bootstrap`/`infra` → 6 config.xml pfSense → 7 `config`/`ipam` → 8 tests → 9 snapshots.

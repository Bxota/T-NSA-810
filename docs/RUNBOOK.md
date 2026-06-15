# RUNBOOK — déployer la fausse architecture (deux Proxmox nested)

Ton archi (`docs/infra_V3.png`) prévoit **deux Proxmox** : Site 1 « On-Prem » et Site 2 « Remote », reliés par un VPN site-à-site. Comme tu n'as qu'une machine physique, on les recrée en les **virtualisant dans ton `pve`** : deux VMs-Proxmox (`pve-s1`, `pve-s2`) côte à côte, chacune hébergeant ensuite ses propres VMs.

Il y a donc **deux niveaux** :

```
  ton pve (machine physique)
  ├── pve-s1  (VM-Proxmox, nested)        ← PHASE 1
  │     ├── pfSense-S1   (10.1.0.1)        ← PHASE 4
  │     ├── NetBox       (10.1.0.10)
  │     └── Elastic      (10.1.0.20)
  └── pve-s2  (VM-Proxmox, nested)        ← PHASE 1
        ├── pfSense-S2   (10.2.0.1)        ← PHASE 4
        ├── Bastion      (10.2.0.5)
        └── WebApp       (10.2.0.30)
```

---

## PHASE 0 — Doppler (une fois)

```bash
brew install dopplerhq/cli/doppler
doppler login                 # crée un compte gratuit + connecte-toi
cd ~/Documents/T-NSA-810-BDX_1
doppler setup                 # "Create new project" → nomme-le cia
```

## PHASE 1 — Virtualiser les deux nœuds Proxmox (sur le pve parent)

Sur le **Shell de ton `pve`** (Datacenter → pve → Shell) :

```bash
cd T-NSA-810-BDX_1/scripts
chmod +x create-nested-pve.sh
./create-nested-pve.sh        # crée pve-s1 (VMID 701) et pve-s2 (VMID 702), boote l'ISO Proxmox
```

Puis, pour **chaque** nœud :

1. Ouvre la **Console (noVNC)** dans l'interface → installe Proxmox VE sur le disque virtuel.
   - IP de gestion : une IP libre du LAN de ton parent (ex. `pve-s1 = …241`, `pve-s2 = …242`). **Évite** `10.1.0.x` / `10.2.0.x` (réservées aux VMs internes). Note le mot de passe root.
2. Éjecte l'ISO :  `qm set 701 --ide2 none && qm reboot 701`  (idem 702).
3. Crée un token API **sur ce nœud** (via sa console ou en SSH dessus) :
   ```bash
   pveum user token add root@pam terraform --privsep 0
   ```
   Note le `value`. Tu auras donc **deux** tokens (un par nœud).

## PHASE 2 — Secrets Doppler

Édite `scripts/setup-secrets.sh` : renseigne les IP, noms d'hôte et tokens des **deux** nœuds, puis :

```bash
cd ~/Documents/T-NSA-810-BDX_1
bash scripts/setup-secrets.sh   # génère clés SSH + mots de passe et remplit Doppler
```

Il affiche le mot de passe admin NetBox à la fin — note-le.

## PHASE 3 + 4 + 5 — Préparer, déployer, configurer

```bash
./deploy.sh all
```

`all` enchaîne tout : `bootstrap-s1` / `bootstrap-s2` (bridge + template Ubuntu dans chaque nœud) → `init` → `netbox-bootstrap` (pfSense-S1 + NetBox) → `ipam` → `infra` (les VMs restantes) → `config` (Ansible). Tu peux aussi lancer ces étapes une par une pour suivre.

> **Le moment où les VMs naissent À L'INTÉRIEUR des nœuds = les étapes `netbox-bootstrap` puis `infra`.**

## Accès

```bash
./tunnel.sh        # tunnels SSH via les Proxmox  →  NetBox http://10.1.0.10, Kibana …:5601
```

## Repartir de zéro

```bash
./deploy.sh destroy                       # supprime les VMs internes
./scripts/create-nested-pve.sh destroy    # supprime pve-s1 / pve-s2 (sur le parent)
```

---

## Prérequis & réglages

- **Virtualisation imbriquée** sur le parent (sinon les VMs internes ne démarrent pas) :
  ```bash
  echo 'options kvm-intel nested=1' > /etc/modprobe.d/kvm-nested.conf   # AMD : kvm-amd
  modprobe -r kvm_intel && modprobe kvm_intel
  cat /sys/module/kvm_intel/parameters/nested      # doit afficher Y
  ```
- **Ressources** : par défaut `pve-s1` = 12 Go, `pve-s2` = 8 Go. Pour un test léger :
  `PVE_S1_MEM=6144 PVE_S2_MEM=4096 ./create-nested-pve.sh`.
- **Raccourci sans nested** (si un jour tu veux juste vérifier que le code tourne, sans reproduire les deux Proxmox) : tu peux pointer `PROXMOX_S1_IP` et `PROXMOX_S2_IP` vers ton `pve` parent et mettre les deux `*_NODE` à `pve` — mais ça ne reflète pas ton schéma à deux sites.

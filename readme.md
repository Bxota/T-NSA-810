# T-NSA_810

## Prerequisites

- install terraform

```bash
brew tap hashicorp/tap
```

```bash
brew install hashicorp/tap/terraform
```

- install doppler

```bash
doppler setup
```

- configure template ubuntu 
```bash
 # Télécharger l'image Ubuntu 24.04 cloud
wget -P /var/lib/vz/template/iso/ \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Créer la VM template (ID 9000)
qm create 9000 --name "ubuntu-2404-template" --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26

# Importer le disque
qm importdisk 9000 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-lvm

# Attacher le disque et configurer cloud-init
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Convertir en template
qm template 9000
```

- Supprimer cache terraform

```bash
cd terraform/
terraform state list | xargs -I{} terraform state rm {}
```
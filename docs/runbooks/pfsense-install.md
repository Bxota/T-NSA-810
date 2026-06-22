# pfSense — Install console one-shot

## Paramètres VM (Proxmox)

- VM ID : 9100
- RAM : 1024 Mo
- CPU : 2 cores, KVM désactivé (`--kvm 0`) — nested virt
- VGA : `std` (pas `serial0`)
- NIC0 : vtnet0 → vmbr0 (WAN)
- NIC1 : vtnet1 → vmbr1 (LAN S1) / vmbr2 (LAN S2)
- Disque : 8 Go, local-lvm, scsi0

## Étapes d'installation

1. Boot sur ISO pfSense CE 2.7.2 (option 3 au menu SeaBIOS)
2. Accept → **Install pfSense**
3. Partition : **UFS** → **Entire disk** → **GPT**
4. Disque : `da0`
5. Reboot

## Configuration post-install (menu console)

- VLANs : **No**
- WAN : `vtnet0`
- LAN : `vtnet1`
- Option **2 (Set interface IP)** → LAN :
  - IP : `10.1.0.1` (S1) / `10.2.0.1` (S2)
  - Subnet : `24`
  - Gateway : vide
  - IPv6 : vide
  - DHCP : **No**
  - Revert to HTTP : **Yes**

## Conversion en template

```bash
qm stop 9100
qm set 9100 --ide2 none --boot order=scsi0
qm template 9100
```

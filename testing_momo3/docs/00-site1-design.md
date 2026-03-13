# Site 1 Design Freeze

## 1. Objective
Site 1 is the on-prem Proxmox site hosted on node `pve2`.

It contains 3 VMs:
- `cia-pf-s1` : pfSense firewall for Site 1
- `cia-netbox` : NetBox IPAM / source of truth
- `cia-elastic` : Elasticsearch + Kibana for centralized logs

## 2. Current Proxmox Context
Cluster nodes:
- `pve2`
- `pve3`

For now, Site 1 will be modeled on:
- Node: `pve2`

Current relevant bridges on `pve2`:
- `vmbr0` = management / upstream network
- `vmbr1` = Site 1 internal network (used for now)
- `vmbr2` = currently exists on pve2 but not part of final Site 1 design

Current Ubuntu template:
- VM ID: `9000`
- Name: `ubuntu-2404-template`

## 3. Site 1 VM Inventory
### VM 400 - cia-pf-s1
- Role: firewall / router / OpenVPN server / DNS forwarder
- Node: `pve2`
- VM ID: `400`

### VM 401 - cia-netbox
- Role: NetBox
- Node: `pve2`
- VM ID: `401`

### VM 402 - cia-elastic
- Role: Elasticsearch + Kibana
- Node: `pve2`
- VM ID: `402`

## 4. Site 1 Network Plan
### Proxmox bridge usage
- pfSense WAN NIC -> `vmbr0`
- pfSense LAN NIC -> `vmbr1`
- NetBox NIC -> `vmbr1`
- Elastic NIC -> `vmbr1`

### Intended IP addressing
- pfSense S1 LAN: `10.1.0.1/24`
- NetBox: `10.1.0.10/24`
- Elastic: `10.1.0.20/24`

### Default gateway
- NetBox gateway: `10.1.0.1`
- Elastic gateway: `10.1.0.1`

## 5. Terraform Scope
Terraform will manage:
- VM creation
- VM names
- VM IDs
- target node
- CPU / RAM / disk
- network bridge attachment
- cloning Linux VMs from template
- cloud-init network configuration for Linux VMs

Terraform will NOT yet manage:
- NetBox application installation
- Elasticsearch installation
- pfSense firewall rules
- OpenVPN configuration
- DNS forwarder configuration

## 6. Ansible Scope
Ansible will later manage:
- NetBox installation and configuration
- Elasticsearch + Kibana installation and configuration
- logging agents where needed

## 7. Known Lab Constraints
- Both sites are currently inside the same Proxmox lab environment
- `pve2` currently carries bridges for both site ranges
- This is acceptable for the lab phase
- We are starting with Site 1 only

## 8. Inputs Terraform Will Need
- Proxmox API URL
- Proxmox username or API token
- target node = `pve2`
- template VM ID = `9000`
- storage name for disks
- bridge for Site 1 LAN = `vmbr1`
- VM IDs = `400`, `401`, `402`

## 9. First Terraform Milestone
First milestone:
Terraform must create only `cia-netbox` successfully on `pve2` from template `9000`.


## Bootstrap Result
A temporary Terraform-managed VM was created successfully for learning and validation.

- VM ID: 411
- Name: cia-netbox-tf
- Node: pve2
- Bridge: vmbr1
- Storage: local-lvm
- Purpose: validate Terraform -> Proxmox workflow before managing final Site 1 VMs
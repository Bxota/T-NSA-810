#!/usr/bin/env python3
"""Synchronise l'inventaire Proxmox → NetBox (IPAM source de vérité).

Interroge l'API de chaque nœud Proxmox, récupère les VMs réelles (nom, état,
vCPU, RAM, disque, IP cloud-init) et réconcilie dans NetBox :
  - cluster type « Proxmox » + un cluster par nœud
  - une virtual-machine NetBox par VM Proxmox (taguée `proxmox-sync`)
  - l'interface réseau + l'adresse IP primaire

Réconciliation : les VMs NetBox taguées `proxmox-sync` absentes de Proxmox sont
supprimées → NetBox reflète en continu l'état réel de l'infra.

Idempotent. Piloté par variables d'environnement (cf. unit systemd) :
  NETBOX_URL, NETBOX_TOKEN, PROXMOX_NODES (JSON), STATIC_IPS (JSON), VERIFY_SSL
"""
import json
import os
import sys
import urllib3
import requests

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

NETBOX_URL = os.environ["NETBOX_URL"].rstrip("/")
NETBOX_TOKEN = os.environ["NETBOX_TOKEN"]
# PROXMOX_NODES = [{"url","node","token_id","token_secret"}, ...]
PROXMOX_NODES = json.loads(os.environ["PROXMOX_NODES"])
# STATIC_IPS = {"vm-name": "10.1.0.1/24"}  (VMs sans cloud-init, ex. pfSense)
STATIC_IPS = json.loads(os.environ.get("STATIC_IPS", "{}"))
VERIFY_SSL = os.environ.get("VERIFY_SSL", "false").lower() == "true"
SYNC_TAG = "proxmox-sync"

nb = requests.Session()
nb.headers.update({"Authorization": f"Token {NETBOX_TOKEN}",
                   "Content-Type": "application/json", "Accept": "application/json"})


# ── Helpers NetBox REST ───────────────────────────────────────────────────────
def nb_get(path, **params):
    r = nb.get(f"{NETBOX_URL}/api/{path}", params=params, verify=VERIFY_SSL, timeout=30)
    r.raise_for_status()
    return r.json()


def nb_first(path, **params):
    res = nb_get(path, **params)["results"]
    return res[0] if res else None


def nb_post(path, data):
    r = nb.post(f"{NETBOX_URL}/api/{path}", json=data, verify=VERIFY_SSL, timeout=30)
    r.raise_for_status()
    return r.json()


def nb_patch(path, data):
    r = nb.patch(f"{NETBOX_URL}/api/{path}", json=data, verify=VERIFY_SSL, timeout=30)
    r.raise_for_status()
    return r.json()


def nb_delete(path):
    r = nb.delete(f"{NETBOX_URL}/api/{path}", verify=VERIFY_SSL, timeout=30)
    r.raise_for_status()


def ensure(path, lookup, defaults):
    """Crée l'objet s'il n'existe pas (selon lookup), sinon le retourne."""
    found = nb_first(path, **lookup)
    if found:
        return found
    return nb_post(path, {**lookup, **defaults})


# ── Proxmox API ───────────────────────────────────────────────────────────────
def pve_get(node_cfg, path):
    url = f"{node_cfg['url'].rstrip('/')}/api2/json/{path}"
    hdr = {"Authorization": f"PVEAPIToken={node_cfg['token_id']}={node_cfg['token_secret']}"}
    r = requests.get(url, headers=hdr, verify=VERIFY_SSL, timeout=30)
    r.raise_for_status()
    return r.json()["data"]


def parse_ipconfig(cfg):
    """Extrait l'IP CIDR depuis ipconfig0 cloud-init (ip=10.1.0.20/24,gw=...)."""
    raw = cfg.get("ipconfig0", "")
    for part in raw.split(","):
        if part.startswith("ip=") and part != "ip=dhcp":
            return part[3:]
    return None


def parse_mac(cfg):
    raw = cfg.get("net0", "")
    for part in raw.split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            if k in ("virtio", "e1000", "vmxnet3", "rtl8139") and ":" in v:
                return v
    return None


# ── Sync ──────────────────────────────────────────────────────────────────────
def main():
    # Pré-requis NetBox : tag + cluster type
    ensure("extras/tags/", {"slug": SYNC_TAG}, {"name": SYNC_TAG, "color": "2196f3"})
    ctype = ensure("virtualization/cluster-types/", {"slug": "proxmox"}, {"name": "Proxmox"})

    seen_vm_ids = set()

    for node_cfg in PROXMOX_NODES:
        node = node_cfg["node"]
        cluster = ensure("virtualization/clusters/",
                         {"name": node},
                         {"type": ctype["id"]})

        for vm in pve_get(node_cfg, f"nodes/{node}/qemu"):
            if vm.get("template"):
                continue  # ignore les templates
            name = vm["name"]
            vmid = vm["vmid"]
            cfg = pve_get(node_cfg, f"nodes/{node}/qemu/{vmid}/config")
            status = "active" if vm.get("status") == "running" else "offline"

            vm_body = {
                "name": name,
                "status": status,
                "cluster": cluster["id"],
                "vcpus": vm.get("cpus"),
                "memory": int(vm.get("maxmem", 0) / 1024 / 1024) or None,
                "disk": int(vm.get("maxdisk", 0) / 1024 / 1024 / 1024) or None,
                "comments": f"Synchronisé depuis Proxmox (node={node}, vmid={vmid}).",
                "tags": [{"slug": SYNC_TAG}],
            }

            existing = nb_first("virtualization/virtual-machines/", name=name)
            if existing:
                nbvm = nb_patch(f"virtualization/virtual-machines/{existing['id']}/", vm_body)
            else:
                nbvm = nb_post("virtualization/virtual-machines/", vm_body)
            seen_vm_ids.add(nbvm["id"])
            print(f"[vm] {name} (vmid={vmid}, {status})")

            # Interface + IP
            cidr = parse_ipconfig(cfg) or STATIC_IPS.get(name)
            if not cidr:
                print("     pas d'IP connue, skip IPAM")
                continue

            iface = ensure("virtualization/interfaces/",
                           {"virtual_machine_id": nbvm["id"], "name": "eth0"},
                           {"virtual_machine": nbvm["id"], "name": "eth0",
                            "mac_address": parse_mac(cfg)})

            ip = nb_first("ipam/ip-addresses/", address=cidr)
            ip_body = {
                "address": cidr, "status": "active",
                "assigned_object_type": "virtualization.vminterface",
                "assigned_object_id": iface["id"],
                "tags": [{"slug": SYNC_TAG}],
            }
            if ip:
                ipobj = nb_patch(f"ipam/ip-addresses/{ip['id']}/", ip_body)
            else:
                ipobj = nb_post("ipam/ip-addresses/", ip_body)

            nb_patch(f"virtualization/virtual-machines/{nbvm['id']}/",
                     {"primary_ip4": ipobj["id"]})
            print(f"     IP {cidr} → primaire")

    # ── Réconciliation : purge des VMs synchronisées disparues ────────────────
    for nbvm in nb_get("virtualization/virtual-machines/", tag=SYNC_TAG, limit=1000)["results"]:
        if nbvm["id"] not in seen_vm_ids:
            print(f"[purge] {nbvm['name']} absente de Proxmox → suppression")
            nb_delete(f"virtualization/virtual-machines/{nbvm['id']}/")

    print("Sync terminée.")


if __name__ == "__main__":
    try:
        main()
    except requests.HTTPError as e:
        print(f"Erreur API : {e}\n{e.response.text}", file=sys.stderr)
        sys.exit(1)

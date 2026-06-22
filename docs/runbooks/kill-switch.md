# Runbook — Kill switch (déconnexion d'urgence)

Coupure d'urgence **réversible** d'un site, en cas de compromission ou d'incident.
Isole le site du monde extérieur (WAN + tunnel VPN coupés) tout en gardant le LAN local
opérationnel pour l'investigation.

## Déclenchement
```bash
./deploy.sh kill-switch s2     # isole le Site 2
./deploy.sh kill-switch all    # isole les deux sites
```
Effet sur la pfSense ciblée :
- arrêt de tous les tunnels OpenVPN (`killall openvpn`) ;
- interface WAN coupée (`ifconfig <wan> down`) → plus aucun flux entrant/sortant externe ;
- pose d'un flag `/var/run/cia_killswitch`.

## Rétablissement
```bash
./deploy.sh restore s2         # rétablit le Site 2
./deploy.sh restore all
```
Effet : WAN réactivé, suppression du flag, `rc.reload_all` (interfaces + OpenVPN + filtre
rechargés depuis `config.xml`) → retour à l'état nominal.

## Vérifier l'état
```bash
ssh -J root@$PROXMOX_S2_IP admin@10.2.0.1 '/root/kill-switch.sh status'
```

## Détails techniques
- Script déployé par Ansible : `ansible/roles/pfsense/templates/kill-switch.sh.j2`
  → `/root/kill-switch.sh` sur chaque pfSense.
- Réversibilité garantie : aucune modification persistante de `config.xml` ; tout est
  rétabli par `rc.reload_all`.
- Le LAN local reste actif → les VMs du site restent accessibles en interne pour le
  forensic (logs, auditd, etc.).

# Rôle Ansible `pfsense`

Pousse le `config.xml` validé de chaque site sur le pfSense correspondant, par SSH,
puis l'applique (`/etc/rc.reload_all`). Rend la config pfSense **IaC** : plus de
console, plus d'import GUI manuel — `./deploy.sh config` configure aussi les pfSense.

## Pourquoi un pré-requis « une fois »
Le SSH de pfSense ouvre par défaut le **menu console** (`/etc/rc.initial`), pas un
shell Unix → `ssh admin@pf 'cmd'` et `scp` ne marchent pas. Il faut **une seule fois**
mettre le shell de l'admin à `/bin/sh`. Après ça, tous les clones du template en
héritent et le rôle est 100 % automatique.

## Prep du template (UNE FOIS)
Sur le pfSense qui sert de base au template :
1. **SSH activé** : console option `14` (Enable Secure Shell), ou System → Advanced → Admin Access → Enable SSH.
2. **Shell admin = /bin/sh** : console option `8` (Shell), puis :
   ```
   pw usermod admin -s /bin/sh
   ```
3. **WAN statique sur S1** (déterminisme du VPN) : Interfaces → WAN → IPv4 = Static,
   ex. `192.168.1.50/24`, gateway = ta box. Et sur S2 : VPN → OpenVPN → Client →
   Server host = `192.168.1.50`.
4. **Ré-exporte** les deux configs (Diagnostics → Backup) → écrase
   `pfsense-exported/config-pf-s1.s1.cia.xml` et `config-pf-s2.s2.cia.xml`.
5. **Refais les templates** (9100 = config S1, 9101 = config S2) avec ces configs.

À partir de là : clone Terraform → pfSense bootent déjà bons ; et `./deploy.sh config`
(ré)applique le config.xml de façon idempotente, sans aucune action manuelle.

## Ce que fait le rôle
1. Vérifie l'accès shell SSH (`echo OK`).
2. `scp` le `config.xml` du site → `/cf/conf/config.xml` (via ProxyJump par le nœud
   Proxmox, clé `/tmp/cia_infra` ; auth pfSense par mot de passe `pfsense_admin_password`).
3. `rm -f /tmp/config.cache && /etc/rc.reload_all`.

## Variables
- `pfsense_admin_password` (def. `pfSenseCIA!`) — mettre en Doppler idéalement.
- `pfsense_config_dir` — dossier des configs (def. `pfsense-exported/`).
- Par hôte (inventaire) : `proxmox_jump_ip`, `pfsense_config_file`, `site`.

## Statut
Première version. Le SSH pfSense (ProxyJump + password + shell) demande souvent
1–2 ajustements selon l'environnement — à valider d'abord sur **pf-s1** :
```
ansible-playbook -i inventory/hosts.yml site.yml --limit pfsense_s1
```

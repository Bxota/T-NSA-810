# Configurations pfSense

Deux jeux de fichiers, deux rôles distincts :

## `pfsense-exported/` — SOURCE DE VÉRITÉ (à utiliser)
- `config-pf-s1.s1.cia.xml`
- `config-pf-s2.s2.cia.xml`

Ce sont les configurations **réellement validées**, exportées depuis le GUI pfSense
après tous les réglages testés (OpenVPN AES-256-CBC, DNS forwarding via LAN, access
lists inter-sites, NAT bastion, kill switch…). **C'est ce qu'on importe** lors d'un
déploiement, et ce qui sert de base au DRP.

Import : pfSense GUI → Diagnostics → Backup & Restore → Restore configuration →
choisir le fichier du site correspondant.

## `pfsense/config-s1.xml` & `config-s2.xml` — TÉMOINS (référence)
Base écrite à la main au départ du projet. **Conservés volontairement comme témoins**
de l'évolution (avant/après), mais **non utilisés** pour le déploiement réel. Ne pas
les importer : ils sont incomplets par rapport aux exportés validés.

## Quel fichier pour quel cas
| Cas | Fichier |
|---|---|
| Déployer / restaurer pf-s1 | `pfsense-exported/config-pf-s1.s1.cia.xml` |
| Déployer / restaurer pf-s2 | `pfsense-exported/config-pf-s2.s2.cia.xml` |
| Comprendre la base initiale | `pfsense/config-s1.xml` / `config-s2.xml` |

## Flux de déploiement pfSense (rappel)
1. Terraform clone le template (9100 sur pve2 / 9101 sur pve3) → VM pfSense.
2. Console : assignation interfaces + IP LAN (10.1.0.1 / 10.2.0.1).
3. Import du `config.xml` **exporté** du site → pfSense applique tout et reboote.

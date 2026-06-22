# Plan de Reprise d'Activité (DRP) — Infrastructure CIA

_Disaster Recovery Plan — projet T-NSA-810._

## 1. Objectif

Garantir la reconstruction de l'infrastructure hybride Proxmox (2 sites) après un
sinistre, dans un délai maîtrisé, grâce à l'approche **100 % IaC** (Terraform + Ansible).
Tout est reconstructible depuis le dépôt Git + le coffre de secrets Doppler.

## 2. Éléments critiques à sauvegarder

| Élément | Emplacement | Sauvegarde | Criticité |
|---|---|---|---|
| Code IaC (Terraform/Ansible) | Dépôt Git | Remote Git (GitHub) | ⭐⭐⭐ |
| Secrets (clés, tokens, mots de passe) | Doppler | Coffre Doppler + export chiffré hors-ligne | ⭐⭐⭐ |
| PKI OpenVPN (CA, certs, ta.key) | `pfsense_s1:/root/cia-pki/` | Snapshot pfSense + export config.xml | ⭐⭐⭐ |
| `config.xml` pfSense (les 2 sites) | `pfsense:/cf/conf/config.xml` | Régénéré par Ansible (idempotent) | ⭐⭐ |
| État Terraform | `terraform/terraform.tfstate` | Backend distant recommandé (cf. §6) | ⭐⭐ |
| Données NetBox (PostgreSQL) | VM netbox | Dump `pg_dump` périodique | ⭐⭐ |
| Données Elasticsearch | VM elastic | Snapshot ES | ⭐ |

> ⚠️ La PKI OpenVPN est régénérée à neuf si `pfsense_s1:/root/cia-pki/` est perdu — ce qui
> invalide le certificat client de S2. En reconstruction complète c'est sans impact (les
> deux configs sont régénérées ensemble). En reconstruction **partielle de S1 seul**,
> rejouer aussi `pfsense_s2` pour redistribuer la nouvelle PKI.

## 3. Scénarios & procédures

### S1 — Perte d'une VM applicative (netbox, elastic, bastion, web)
1. `./deploy.sh infra` recrée la VM manquante (Terraform converge).
2. `ansible-playbook site.yml --limit <hôte>` réapplique sa configuration.
3. Restaurer les données applicatives depuis la dernière sauvegarde (dump PostgreSQL
   NetBox / snapshot ES) si nécessaire.
- **RTO** : ~15 min. **RPO** : dernier dump.

### S2 — Perte d'un pfSense (firewall/routeur)
Voir [runbooks/pfsense-recover.md](runbooks/pfsense-recover.md).
- Recréer la VM pfSense (Terraform), réappliquer `config.xml` via Ansible.
- **RTO** : ~30 min (dont install pfSense one-shot si le template est perdu aussi).

### S3 — Perte complète d'un site (Proxmox HS)
1. Réinstaller Proxmox sur le matériel.
2. `./deploy.sh bootstrap-s<N>` (bridge + templates Ubuntu **et** pfSense).
3. Install pfSense one-shot (console) → `qm template`.
4. `./deploy.sh all` reconstruit le site.
- **RTO** : ~2 h. **RPO** : dépôt Git + Doppler (toujours à jour).

### S4 — Perte totale (les 2 sites)
Dérouler [runbooks/rebuild-full.md](runbooks/rebuild-full.md) de bout en bout.
- **RTO** : ~3-4 h.

### S5 — Compromission / incident sécurité
1. **Kill switch** : isoler le(s) site(s) immédiatement
   (`./deploy.sh kill-switch all`) — cf. [runbooks/kill-switch.md](runbooks/kill-switch.md).
2. Investiguer via les logs centralisés (Elasticsearch/Kibana, auditd bastion).
3. Rotation des secrets dans Doppler, régénération PKI, redéploiement.

## 4. Ordre de reconstruction (dépendances)

```
bootstrap (bridges + templates) → pfsense_s1 (PKI + gateway) → netbox → ipam
   → infra (toutes VMs + pfsense_s2) → config (tous services)
```
pfsense_s1 **doit** être configuré avant pfsense_s2 (il génère la PKI du tunnel).

## 5. Vérification post-reprise

- Tunnel VPN : `ssh admin@pfsense_s1 'ping 10.2.0.1'`.
- DNS inter-sites : `dig web.s2.local @10.1.0.1` depuis S1.
- Firewall : `nmap` du WAN → seul le port OpenVPN ouvert sur S1.
- Services : NetBox (`:80`), Kibana, site web interne, accès bastion 2FA.

## 6. Recommandations de durcissement DRP

- Migrer l'état Terraform vers un **backend distant** (S3/Postgres) pour éviter la perte
  locale du `tfstate`.
- Automatiser un **dump périodique** PostgreSQL NetBox + snapshot ES.
- Tester le DRP au moins une fois (exercice de bascule sur un site).

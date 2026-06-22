# Runbook — Restauration d'un pfSense

Restaure un firewall/routeur pfSense (S1 ou S2) après perte de la VM. Durée : ~30 min.

## Cas A — Le template pfSense existe encore sur le Proxmox
1. Recréer la VM via Terraform :
   ```bash
   ./deploy.sh infra            # converge, recrée la pfSense manquante
   # ou ciblé : terraform apply -target=module.pfsense_s2 "${TF_ARGS[@]}"
   ```
2. Réappliquer la configuration (config.xml généré par Ansible) :
   ```bash
   cd ansible && ansible-playbook -i inventory/hosts.yml site.yml --limit pfsense_s2
   ```
3. Si c'est **pfsense_s1** qui a été reconstruit (PKI régénérée), réappliquer aussi
   **pfsense_s2** pour redistribuer le nouveau certificat client :
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --limit pfsense_s2
   ```

## Cas B — Le template pfSense est perdu aussi
1. Recréer le template (ISO + install one-shot) :
   ```bash
   ./deploy.sh bootstrap-s<N>   # retélécharge l'ISO + recrée la VM d'install
   ```
   Puis install console + `qm template` (cf. rebuild-full.md §2).
2. Reprendre au Cas A.

## Vérification
```bash
# Tunnel rétabli
ssh -J root@$PROXMOX_S1_IP admin@10.1.0.1 'ping -c2 10.2.0.1'
# Firewall actif (depuis le WAN, seul OpenVPN ouvert sur S1)
# DNS forwarding
dig web.s2.local @10.1.0.1 +short
```

## Notes
- La configuration pfSense n'est **jamais éditée à la main** : `config.xml` est régénéré
  par le rôle Ansible `pfsense`. Toute modification durable passe par le template
  `ansible/roles/pfsense/templates/config.xml.j2`.
- Sauvegarde rapide possible depuis la GUI pfSense (Diagnostics → Backup) mais la source
  de vérité reste le dépôt Git.

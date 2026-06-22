# Justification des écarts par rapport au sujet

Document technique accompagnant la Keynote — choix d'architecture et écarts assumés.

## 1. Firewall : pfSense ✅ (conforme)

Le sujet impose **pfSense** comme firewall. L'infrastructure le déploie désormais comme
firewall/routeur de chaque site (remplaçant le routeur Linux du POC intermédiaire) :
- VPN site-à-site OpenVPN, firewall **deny-by-default**, NAT sortant et résolveur DNS
  (Unbound) sont portés par pfSense ;
- configuration **100 % IaC** via un `config.xml` templaté (Jinja) appliqué par Ansible
  (rôle `pfsense`), conformément à l'exigence « tout en IaC ».

> Écart résiduel : l'**installation** de pfSense (image FreeBSD, pas de cloud-init) reste
> une étape console one-shot lors du bootstrap d'un hyperviseur ; elle est documentée
> (cf. runbooks) et n'affecte pas le caractère reproductible de la **configuration**.

## 2. Gestion des secrets : Doppler au lieu de Vault

Le kickoff mentionnait **HashiCorp Vault** ; le projet utilise **Doppler**.

**Pourquoi ce choix est valide :**
- Doppler est un gestionnaire de secrets centralisé équivalent fonctionnellement à Vault
  pour le périmètre du projet : stockage chiffré, contrôle d'accès, injection par
  variables d'environnement, rotation et versionnement des secrets.
- **Intégration IaC native** : tous les secrets (tokens Proxmox, clés SSH, mots de passe
  NetBox/Elastic, PKI, bcrypt admin pfSense) sont injectés au runtime via
  `doppler secrets get` dans `deploy.sh` — **aucun secret en clair dans le dépôt**.
- Moindre coût opérationnel : pas de cluster Vault à déployer/sceller/maintenir, ce qui est
  cohérent avec la taille de l'infrastructure et le calendrier projet.

**Couverture de l'exigence « database de credentials sécurisée » :** Doppler joue ce rôle.
Une migration vers Vault resterait possible sans changer l'architecture (même point
d'injection unique dans `deploy.sh` et `group_vars`).

**Limites assumées :** dépendance à un SaaS tiers. Mitigation : export chiffré hors-ligne
des secrets critiques (cf. [DRP.md](DRP.md) §2).

## 3. Synthèse des exigences notées

| Exigence | État | Implémentation |
|---|---|---|
| Firewall pfSense | ✅ | Rôle `pfsense`, `config.xml` deny-by-default |
| VPN site-à-site | ✅ | OpenVPN dans pfSense (PKI générée en IaC) |
| DNS forwarding inter-sites | ✅ | Unbound pfSense (host overrides + domain overrides) |
| Web interne uniquement | ✅ | Pas de port-forward WAN + règle FW source LAN/VPN |
| Kill switch | ✅ | `kill-switch.sh` + `deploy.sh kill-switch/restore` |
| DRP / runbooks | ✅ | [DRP.md](DRP.md) + [runbooks/](runbooks/) |
| Secrets sécurisés | ✅* | Doppler (écart Vault justifié ci-dessus) |
| Tout en IaC | ✅ | Terraform + Ansible + `deploy.sh` |

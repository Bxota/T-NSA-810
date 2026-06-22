# Kick-off T-NSA-810

## Mise en place et sécurisation d'une infrastructure hybride avec Proxmox

## Sommaire

- Technologies
- Besoin Client
- Contraintes Techniques
- Objectifs pédagogiques
- Livrables & Critères d'évaluations

---

# Technologies

## Cloud Privé

### Proxmox

Proxmox VE est une solution de virtualisation de type **bare metal**.

L'installation de Proxmox VE s'effectue via une image ISO.

---

## VPN

### OpenVPN

OpenVPN est un logiciel open source permettant de créer un VPN (réseau privé virtuel) pour sécuriser les connexions Internet.

Fonctionnalités :

- Chiffrement des données entre l'appareil et le serveur VPN
- Protection de la navigation sur les réseaux publics (Wi-Fi)
- Accès distant sécurisé au réseau d'entreprise
- Contournement de certaines restrictions d'accès

---

## IPAM

### NetBox

NetBox est une solution de référence pour la modélisation et la documentation des réseaux modernes.

Elle combine :

- Gestion des adresses IP (IPAM)
- Gestion des infrastructures de datacenter (DCIM)
- API d'automatisation
- Extensions et intégrations

NetBox constitue une source de vérité idéale pour l'automatisation des réseaux.

---

## Observabilité

### Elasticsearch

Elasticsearch est une solution open source distribuée conçue pour :

- La recherche
- L'analyse de données
- La montée en charge
- Les applications d'intelligence artificielle

---

## Gestion des secrets

### Vault

Vault permet d'accéder de manière sécurisée aux secrets :

- Clés API
- Mots de passe
- Certificats
- Informations sensibles

Fonctionnalités :

- Interface unifiée
- Contrôle d'accès strict
- Journalisation détaillée des accès

---

# Besoin Client

Le client souhaite :

- 1 site on-premise
- 1 site distant
- Interconnexion des deux sites via un VPN site-à-site
- Firewall sur les deux sites afin de limiter l'exposition
- Possibilité de déconnexion d'urgence
- IPAM mis à jour automatiquement
- Accès au site distant depuis Internet via un bastion
- Supervision globale de l'infrastructure
- DNS forwarding entre les deux sites
- Architecture évolutive permettant l'ajout de nouveaux sites

---

# Architecture Globale

> Schéma à définir pendant la phase de conception.

---

# Contraintes Techniques

- 3 VM sur Proxmox Site 1
- 3 VM sur Proxmox Site 2
- Utilisation obligatoire de technologies maintenues et toujours supportées par la communauté

---

# Objectifs pédagogiques

- Déployer une infrastructure hybride (Proxmox S1 & Proxmox S2)
- Configurer un VPN site-à-site sécurisé
- Installer et configurer des firewalls
- Déployer un maximum de ressources en Infrastructure as Code (IaC)
- Installer un bastion sécurisé
- Automatiser la gestion IP avec NetBox
- Centraliser et analyser les logs avec Elasticsearch
- Déployer un site web accessible uniquement depuis le réseau interne
- Stocker les données sensibles dans un Vault

---

# Livrables

## Follow-Up 1

### Travail attendu

- Découverte des technologies
- Diagramme de Gantt des phases projet
- Découpage du projet en tickets
- Remontée des blocages techniques
- Mise en place des dépôts GitOps
- Ajout des pédagogues/intervenants en lecture seule
- Liste des tickets à terminer avant le prochain suivi
- Schéma d'infrastructure à faire valider

---

## Follow-Up 2

### Travail attendu

- Premières briques d'infrastructure déployées
- Diagramme de Gantt et ticketing mis à jour
- Liste finale des technologies retenues
- Remontée des blocages techniques
- Liste des tickets prévus pour le prochain suivi

---

## Follow-Up 3

### Travail attendu

- Infrastructure et applicatifs en version bêta
- Diagramme de Gantt et ticketing mis à jour
- Liste finale des technologies retenues
- Remontée des blocages techniques

---

## Keynote

### Livrables attendus

- Documentation technique détaillée avec captures d'écran
- Code source des configurations réseau et logs
- Base sécurisée des identifiants
- Schéma d'infrastructure
- Documentation de reprise après sinistre

---

# Critères d'évaluation

- Fonctionnalité et robustesse de l'infrastructure
- Qualité et lisibilité du code
- Sécurité et efficacité des configurations firewall
- Pertinence des analyses Elasticsearch
- Justification des choix techniques
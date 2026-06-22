# CIA

## Deployment and Securing of a Hybrid Infrastructure with Proxmox

---

# Context

As a member of the **Cloud Infrastructure Architects (CIA)** team, a client asks you to design, deploy, and secure a hybrid infrastructure composed of:

- Two Proxmox sites
  - One on-premise
  - One remote
- VPN
- Firewalls
- IPAM
- Observability platform

The architecture must be scalable to support additional sites in the future.

---

# Goals

## Main Objectives

- Deploy a hybrid infrastructure:
  - Proxmox Site 1
  - Proxmox Site 2
- Configure a secure site-to-site VPN
- Deploy firewalls on both sites
- Provide an emergency cut-off capability
- Deploy a bastion host for remote access
- Automate IP management with NetBox
- Keep IPAM synchronized automatically
- Centralize logs with Elasticsearch
- Publish an internal-only website
- Build a scalable architecture ready for future sites

---

# Survival Tips

- Separate traffic:
  - Administration
  - Users
  - Services
- Apply least privilege principles
- Prepare an emergency kill-switch strategy
- Ensure recovery remains possible
- Document rebuild procedures
- Prefer automation over manual configuration

---

# Expected Deliverables

The team must provide:

- A functional infrastructure
- Secure connectivity
- Controlled access
- Monitoring and observability
- A project-oriented methodology
- Planning and ticket management
- Risk and blocker tracking
- Maximum Infrastructure as Code deployment
- Clear and reproducible documentation
- Runbooks and infrastructure diagrams

---

# Core Stack Technologies

## Private Cloud

### Proxmox VE

Bare-metal virtualization platform used to host VMs for each site.

---

## VPN

### OpenVPN

Provides encrypted site-to-site connectivity and secure remote access.

---

## IPAM

### NetBox

Acts as the source of truth for:

- IP addresses
- Prefixes
- Devices

Provides APIs for automation and documentation.

---

## Observability

### Elasticsearch

Used to:

- Centralize logs
- Search logs
- Analyze logs
- Investigate incidents

---

## Firewall

### pfSense

FreeBSD-based firewall/router used to:

- Filter traffic
- Reduce attack surface
- Enforce security policies

---

# Expectations and Constraints

## Client Expectations

- One on-premise site
- One remote site
- Site-to-site VPN
- Firewall on both sites
- Emergency disconnection capability
- Auto-updated IPAM
- Bastion host access
- Infrastructure monitoring
- DNS forwarding between sites
- Future multi-site support

---

## Technical Constraints

- Maximum 3 VMs per Proxmox site
- Technologies must be actively maintained by the community

---

# Infrastructure Diagram Requirements

The diagram must include:

## Sites

- Site 1
- Site 2
- LAN
- DMZ
- Admin network (if segmented)

## VPN

- VPN termination points
- Routed subnets
- Encryption method

## Security Controls

- Firewalls
- Main filtering rules

## Bastion

- Allowed flows
- Authentication methods
- Logging

## Services

- NetBox
- Elasticsearch

For each service:

- Hosting location
- Access permissions
- Network flows

## DNS

- Forwarding paths
- Zones
- Resolution process

---

# Deliverables

## Follow-up 1 — Scoping

- Initial technology exploration
- Technical blocker reporting
- GitOps repositories setup
- Gantt chart
- Ticket backlog
- Next milestone ticket list
- Infrastructure diagram validation

---

## Follow-up 2 — First Building Blocks

- First infrastructure components deployed
- Updated Gantt chart
- Updated ticketing
- Technical blocker reporting
- Next milestone ticket list

---

## Follow-up 3 — Beta

- Beta infrastructure
- Beta application stack
- Updated Gantt chart
- Updated ticketing
- Final technology choices
- Technical blocker reporting

---

## Keynote — Final Delivery

- Detailed technical documentation
- Screenshots
- Version-controlled network configuration
- Version-controlled logs
- Secure credential storage
- Final infrastructure diagram
- Disaster Recovery Plan (DRP)
- Runbooks

---

# Evaluation Criteria

- Infrastructure robustness
- Infrastructure functionality
- Code quality
- Code readability
- Firewall security
- Firewall effectiveness
- Elasticsearch analysis relevance
- Technical decision justification

---

# Bonus

## CI/CD

- IaC linting
- Automated tests
- Automated deployments

## Golden Paths

Reusable templates for:

- Virtual machines
- Firewall rules
- IPAM
- Logging

## Advanced Monitoring

- Dashboards
- Alerting
- Log parsing

## Multi-Site Readiness

- Addressing conventions
- Third-site onboarding procedures
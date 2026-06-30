#!/bin/bash
set -e

# Ouvre des tunnels SSH vers tous les services CIA via le Proxmox.
# Usage: PROXMOX_HOST=192.168.1.39 ./tunnel.sh

PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.98}"
NETBOX_PORT="${NETBOX_PORT:-18080}"
KIBANA_PORT="${KIBANA_PORT:-15601}"
ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-19200}"
WEB_PORT="${WEB_PORT:-18081}"
BASTION_PORT="${BASTION_PORT:-12222}"

echo "=== CIA Infrastructure Tunnels ==="
echo ""
echo "Les services seront accessibles sur :"
echo "  NetBox        -> http://localhost:${NETBOX_PORT}      (S1 10.1.0.10:80)"
echo "  Kibana        -> http://localhost:${KIBANA_PORT}      (S1 10.1.0.20:5601)"
echo "  Elasticsearch -> http://localhost:${ELASTICSEARCH_PORT}      (S1 10.1.0.20:9200)"
echo "  Web interne   -> http://localhost:${WEB_PORT}      (S2 10.2.0.30:80, via VPN)"
echo "  Bastion SSH   -> ssh -p ${BASTION_PORT} <user>@localhost  (S2 10.2.0.5:22, via VPN)"
echo ""
echo "Ctrl+C pour fermer tous les tunnels"
echo ""

ssh \
  -L "${NETBOX_PORT}:10.1.0.10:80" \
  -L "${KIBANA_PORT}:10.1.0.20:5601" \
  -L "${ELASTICSEARCH_PORT}:10.1.0.20:9200" \
  -L "${WEB_PORT}:10.2.0.30:80" \
  -L "${BASTION_PORT}:10.2.0.5:22" \
  -N \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  "root@${PROXMOX_HOST}"

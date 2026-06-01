#!/bin/bash
set -e

# Ouvre des tunnels SSH vers tous les services CIA via le Proxmox.
# Usage: PROXMOX_HOST=192.168.1.39 ./tunnel.sh

PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.39}"
NETBOX_PORT="${NETBOX_PORT:-18080}"
KIBANA_PORT="${KIBANA_PORT:-15601}"
ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-19200}"

echo "=== CIA Infrastructure Tunnels ==="
echo ""
echo "Les services seront accessibles sur :"
echo "  NetBox        -> http://localhost:${NETBOX_PORT}"
echo "  Kibana        -> http://localhost:${KIBANA_PORT}"
echo "  Elasticsearch -> http://localhost:${ELASTICSEARCH_PORT}"
echo ""
echo "Ctrl+C pour fermer tous les tunnels"
echo ""

ssh \
  -L "${NETBOX_PORT}:10.1.0.10:80" \
  -L "${KIBANA_PORT}:10.1.0.20:5601" \
  -L "${ELASTICSEARCH_PORT}:10.1.0.20:9200" \
  -N \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  "root@${PROXMOX_HOST}"

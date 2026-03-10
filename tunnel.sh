#!/bin/bash
# Ouvre des tunnels SSH vers tous les services CIA via le Proxmox
# Usage: ./tunnel.sh

PROXMOX="root@192.168.1.37"

echo "=== CIA Infrastructure Tunnels ==="
echo ""
echo "Les services seront accessibles sur :"
echo "  NetBox        -> http://localhost:8080"
echo "  Kibana        -> http://localhost:5601"
echo "  Elasticsearch -> http://localhost:9200"
echo ""
echo "Ctrl+C pour fermer tous les tunnels"
echo ""

ssh \
  -L 8080:10.1.0.10:80 \
  -L 5601:10.1.0.20:5601 \
  -L 9200:10.1.0.20:9200 \
  -N \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  "$PROXMOX"

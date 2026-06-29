#!/bin/bash
# Script para resetear fingerprints SSH de los nodos Proxmox

NODES=("192.168.50.10" "192.168.50.11" "192.168.50.12" "192.168.50.21" "192.168.50.22")

for NODE in "${NODES[@]}"; do
    echo "🔄 Limpiando fingerprint de $NODE..."
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$NODE"
done

echo "✅ Fingerprints eliminados. Ahora reconecta con: ssh root@<IP>"

    cidr    = "192.168.50.0/24"
    vip_ha  = "192.168.50.10 (Keepalived)"
    fe1     = "192.168.50.11"
    fe2     = "192.168.50.12"
    node1   = "192.168.50.21"
    node2   = "192.168.50.22"
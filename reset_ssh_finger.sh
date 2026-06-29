#!/bin/bash
# =============================================================================
# reset_ssh_finger.sh — Limpia los fingerprints SSH del laboratorio OpenNebula HA
# =============================================================================

NODES=("192.168.50.11" "192.168.50.12" "192.168.50.21" "192.168.50.22")

echo "🧹 Limpiando registros antiguos en ~/.ssh/known_hosts para evitar bloqueos de Ansible..."

for NODE in "${NODES[@]}"; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$NODE" &>/dev/null
    echo "  ✓ Registro de $NODE eliminado."
done

echo "✅ Limpieza completada. Las conexiones SSH lógicas se renovarán limpiamente."

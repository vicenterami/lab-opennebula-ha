#!/bin/bash
# =============================================================================
# check-cluster.sh — Verifica el estado del clúster OpenNebula HA
# =============================================================================
# Ejecutar desde tu laptop DESPUÉS de que Ansible haya terminado:
#   bash scripts/check-cluster.sh
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

check_host() {
    local name=$1
    local ip=$2
    local service=$3

    if ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@"$ip" "systemctl is-active --quiet $service" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name ($ip) — $service ACTIVO"
    else
        echo -e "  ${RED}✗${NC} $name ($ip) — $service INACTIVO o no alcanzable"
    fi
}

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE} Estado del Clúster OpenNebula HA${NC}"
echo -e "${BLUE}========================================================${NC}"

echo -e "\n${YELLOW}[Frontends — oned]${NC}"
check_host "one-fe1" "192.168.50.11" "opennebula"
check_host "one-fe2" "192.168.50.12" "opennebula"

echo -e "\n${YELLOW}[Frontends — Keepalived (VIP 192.168.50.10)]${NC}"
check_host "one-fe1" "192.168.50.11" "keepalived"
check_host "one-fe2" "192.168.50.12" "keepalived"

echo -e "\n${YELLOW}[Nodos de Cómputo — libvirtd]${NC}"
check_host "one-node1" "192.168.50.21" "libvirtd"
check_host "one-node2" "192.168.50.22" "libvirtd"

echo -e "\n${YELLOW}[VIP Keepalived — Sunstone accesible]${NC}"
if curl -s --connect-timeout 5 "http://192.168.50.10:9869" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Sunstone responde en http://192.168.50.10:9869"
else
    echo -e "  ${RED}✗${NC} Sunstone NO responde en http://192.168.50.10:9869"
fi

echo -e "\n${YELLOW}[NFS — Montajes en VMs]${NC}"
for ip in 192.168.50.11 192.168.50.12 192.168.50.21 192.168.50.22; do
    if ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@"$ip" "mountpoint -q /var/lib/one/datastores" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $ip — NFS montado en /var/lib/one/datastores"
    else
        echo -e "  ${RED}✗${NC} $ip — NFS NO montado"
    fi
done

echo -e "\n${YELLOW}[Estado HA desde FE1 (oneha server-list)]${NC}"
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@192.168.50.11 \
    "sudo -u oneadmin oneha server-list 2>/dev/null || echo '  No disponible (verificar oned)'"

echo -e "\n${BLUE}========================================================${NC}"
echo -e "${BLUE} FIN VERIFICACIÓN${NC}"
echo -e "${BLUE}========================================================${NC}"
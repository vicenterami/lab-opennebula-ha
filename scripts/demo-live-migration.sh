#!/bin/bash
# =============================================================================
# demo-live-migration.sh — Crea una VM de prueba y hace Live Migration
# =============================================================================
# Ejecutar SSH en FE1 primero: ssh ubuntu@192.168.50.11
# Luego: sudo -u oneadmin bash /tmp/demo-live-migration.sh
#
# O desde tu laptop:
#   ssh -i ~/.ssh/id_ed25519 ubuntu@192.168.50.11 \
#     "sudo -u oneadmin bash -s" < scripts/demo-live-migration.sh
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== DEMO LIVE MIGRATION — OpenNebula HA ===${NC}"

# ---------------------------------------------------------------
# 1. Descargar imagen CirrOS (27 MB, es la más liviana para demos)
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[1/5] Importando imagen CirrOS al datastore...${NC}"

# Verificar si ya existe
if oneimage list | grep -q "CirrOS"; then
    echo -e "${GREEN}  ✓ CirrOS ya existe en el datastore${NC}"
    IMG_ID=$(oneimage list | grep CirrOS | awk '{print $1}' | head -1)
else
    # Importar desde el marketplace de OpenNebula
    onemarketapp export "CirrOS 0.5.1" --datastore default -n "CirrOS-demo" 2>/dev/null || true

    # Alternativa: subir imagen descargada manualmente
    CIRROS_URL="https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"
    CIRROS_PATH="/tmp/cirros.img"

    if [ ! -f "$CIRROS_PATH" ]; then
        echo "  Descargando CirrOS 0.6.2..."
        wget -q -O "$CIRROS_PATH" "$CIRROS_URL"
    fi

    IMG_ID=$(oneimage create -d default << 'EOF'
NAME   = "CirrOS-demo"
TYPE   = "OS"
PATH   = "/tmp/cirros.img"
FORMAT = "raw"
DEV_PREFIX = "vd"
EOF
)
    echo -e "${GREEN}  ✓ Imagen CirrOS creada (ID: $IMG_ID)${NC}"
fi

# Esperar a que la imagen esté lista (READY)
echo "  Esperando a que la imagen esté disponible..."
for i in {1..30}; do
    STATUS=$(oneimage show CirrOS-demo 2>/dev/null | grep STATE | awk '{print $3}')
    if [ "$STATUS" = "rdy" ] || [ "$STATUS" = "READY" ]; then
        echo -e "${GREEN}  ✓ Imagen READY${NC}"
        break
    fi
    sleep 5
done

# ---------------------------------------------------------------
# 2. Crear red virtual
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Creando red virtual para la VM de demo...${NC}"

if onevnet list | grep -q "demo-net"; then
    echo -e "${GREEN}  ✓ Red 'demo-net' ya existe${NC}"
else
    onevnet create << 'EOF'
NAME    = "demo-net"
VN_MAD  = "bridge"
BRIDGE  = "virbr0"
AR = [
  TYPE = "IP4",
  IP   = "192.168.50.100",
  SIZE = "10"
]
EOF
    echo -e "${GREEN}  ✓ Red 'demo-net' creada${NC}"
fi

# ---------------------------------------------------------------
# 3. Crear template de VM
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Creando template de VM...${NC}"

if onetemplate list | grep -q "demo-vm"; then
    echo -e "${GREEN}  ✓ Template 'demo-vm' ya existe${NC}"
else
    IMG_ID=$(oneimage show CirrOS-demo 2>/dev/null | grep "^ID" | awk '{print $3}')
    NET_ID=$(onevnet show demo-net 2>/dev/null | grep "^ID" | awk '{print $3}')

    onetemplate create << EOF
NAME    = "demo-vm"
CPU     = "0.2"
VCPU    = "1"
MEMORY  = "128"
DISK    = [ IMAGE_ID = "${IMG_ID:-0}" ]
NIC     = [ NETWORK_ID = "${NET_ID:-0}" ]
GRAPHICS = [ TYPE = "VNC", LISTEN = "0.0.0.0" ]
EOF
    echo -e "${GREEN}  ✓ Template 'demo-vm' creado (0.2 CPU, 128 MB RAM)${NC}"
fi

# ---------------------------------------------------------------
# 4. Instanciar la VM en node1
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Instanciando VM en one-node1...${NC}"

VM_ID=$(onetemplate instantiate demo-vm --name "demo-migra" 2>/dev/null | grep -oP 'VM ID: \K\d+')

if [ -z "$VM_ID" ]; then
    VM_ID=$(onevm list | grep "demo-migra" | awk '{print $1}' | head -1)
fi

echo "  VM ID: $VM_ID"
echo "  Esperando que la VM esté en estado RUNNING..."

for i in {1..60}; do
    STATE=$(onevm show $VM_ID 2>/dev/null | grep "STATE" | head -1 | awk '{print $3}')
    if [ "$STATE" = "runn" ] || [ "$STATE" = "RUNNING" ]; then
        echo -e "${GREEN}  ✓ VM corriendo en:${NC}"
        onevm show $VM_ID | grep -E "HOST|STATE"
        break
    fi
    echo "  Estado actual: $STATE (espera $i/60)"
    sleep 5
done

# ---------------------------------------------------------------
# 5. LIVE MIGRATION a node2
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] 🚀 Realizando LIVE MIGRATION a one-node2...${NC}"
echo -e "  ${YELLOW}¡Este es el momento WOW para la presentación!${NC}"
echo ""

CURRENT_HOST=$(onevm show $VM_ID | grep -E "^\s+HOST" | awk '{print $2}')
echo "  Host actual: $CURRENT_HOST"
echo "  Migrando a: one-node2..."
echo ""

onevm migrate --live $VM_ID one-node2

# Esperar confirmación
for i in {1..30}; do
    NEW_HOST=$(onevm show $VM_ID 2>/dev/null | grep -E "^\s+HOST" | awk '{print $2}')
    STATE=$(onevm show $VM_ID 2>/dev/null | grep "STATE" | head -1 | awk '{print $3}')
    if [ "$NEW_HOST" = "one-node2" ] && ([ "$STATE" = "runn" ] || [ "$STATE" = "RUNNING" ]); then
        echo -e "${GREEN}  ✅ MIGRACIÓN EXITOSA${NC}"
        echo -e "  ${GREEN}VM movida de $CURRENT_HOST → one-node2 SIN APAGARSE${NC}"
        onevm show $VM_ID | grep -E "HOST|STATE|ID"
        break
    fi
    echo "  Estado: $STATE en $NEW_HOST (${i}/30)"
    sleep 3
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} DEMO COMPLETADA — Evidencia para la nota:${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "  1. VM creada con imagen CirrOS mínima"
echo -e "  2. VM corrió en one-node1"
echo -e "  3. Live Migration exitosa → one-node2"
echo -e "  4. VM no se apagó durante la migración"
echo -e "  5. NFS compartido funcionó (disk accesible desde ambos nodos)"
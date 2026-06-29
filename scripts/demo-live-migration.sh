#!/bin/bash
# =============================================================================
# demo-live-migration.sh — Crea una VM de prueba y hace Live Migration
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== DEMO LIVE MIGRATION — OpenNebula HA ===${NC}"

# ---------------------------------------------------------------
# 1. Verificar o importar imagen CirrOS
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[1/5] Importando imagen CirrOS al datastore...${NC}"

if oneimage list | grep -q "CirrOS"; then
    echo -e "${GREEN}  ✓ CirrOS ya existe en el datastore${NC}"
else
    CIRROS_URL="https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"
    CIRROS_PATH="/var/lib/one/cirros.img"

    if [ ! -f "$CIRROS_PATH" ]; then
        echo "  Descargando CirrOS 0.6.2..."
        wget -q -O "$CIRROS_PATH" "$CIRROS_URL"
    fi

    oneimage create -d default --name "CirrOS-demo" --path "$CIRROS_PATH" --type "OS" --format "raw" 2>/dev/null
    echo -e "${GREEN}  ✓ Imagen CirrOS creada${NC}"
fi

# Esperar a que la imagen esté lista (READY)
echo "  Esperando a que la imagen esté disponible..."
for i in {1..30}; do
    STATUS=$(oneimage list | grep "CirrOS" | awk '{print $5}')
    if [ "$STATUS" = "rdy" ] || [ "$STATUS" = "READY" ] || [ "$STATUS" = "USED" ] || [ "$STATUS" = "used" ]; then
        echo -e "${GREEN}  ✓ Imagen LISTA para usar ($STATUS)${NC}"
        break
    fi
    sleep 3
done

# ---------------------------------------------------------------
# 2. Verificar red virtual existente del laboratorio
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Verificando red virtual para la VM de demo...${NC}"

# Usamos la red que tu playbook de Ansible ya creó en el sistema
if onevnet list | grep -q "opennebula-net"; then
    echo -e "${GREEN}  ✓ Red 'opennebula-net' detectada y lista${NC}"
else
    echo -e "${RED}  ✗ ERROR: No se encontró la red 'opennebula-net'. Ejecuta progresar_lab.yml primero.${NC}"
    exit 1
fi

# ---------------------------------------------------------------
# 3. Crear template de VM vinculando la red correcta
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Creando template de VM...${NC}"

if onetemplate list | grep -q "demo-vm"; then
    echo -e "${GREEN}  ✓ Template 'demo-vm' ya existe${NC}"
else
    IMG_ID=$(oneimage list | grep "CirrOS" | awk '{print $1}' | head -1)
    NET_ID=$(onevnet list | grep "opennebula-net" | awk '{print $1}' | head -1)

    onetemplate create << EOF
NAME    = "demo-vm"
CPU     = "0.2"
VCPU    = "1"
MEMORY  = "128"
DISK    = [ IMAGE_ID = "${IMG_ID}" ]
NIC     = [ NETWORK_ID = "${NET_ID}" ]
GRAPHICS = [ TYPE = "VNC", LISTEN = "0.0.0.0" ]
EOF
    echo -e "${GREEN}  ✓ Template 'demo-vm' creado (0.2 CPU, 128 MB RAM)${NC}"
fi

# ---------------------------------------------------------------
# 4. Instanciar la VM en node1
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Instanciando VM en one-node1...${NC}"

# Lanzamos la instancia capturando directamente la salida estándar
SALIDA_INSTANCIA=$(onetemplate instantiate demo-vm --name "demo-migra" 2>/dev/null)
sleep 2

# Extraemos el ID numérico directamente de la respuesta de OpenNebula
VM_ID=$(echo "$SALIDA_INSTANCIA" | grep -oP 'VM ID: \K\d+' || echo "")

# Si por alguna razón falló el parseo anterior, usamos el método de respaldo por nombre
if [ -z "$VM_ID" ]; then
    VM_ID=$(onevm list | grep "demo-migra" | awk '{print $1}' | head -1)
fi

# Si de verdad no se encuentra la VM, detenemos con diagnóstico claro
if [ -z "$VM_ID" ]; then
    echo -e "${RED}  ✗ ERROR: No se pudo registrar la VM.${NC}"
    echo "  Detalle de la salida de OpenNebula:"
    echo "$SALIDA_INSTANCIA"
    exit 1
fi

echo "  VM ID Detectado Exitosamente: $VM_ID"
echo "  Esperando que la VM pase a estado RUNNING..."

for i in {1..60}; do
    # Consultamos el estado específico de este ID para evitar falsos positivos
    STATE=$(onevm list | grep "^ *${VM_ID} " | awk '{print $5}')
    
    if [ "$STATE" = "runn" ] || [ "$STATE" = "RUNNING" ]; then
        echo -e "${GREEN}  ✓ VM perfectamente corriendo en el nodo KVM${NC}"
        break
    fi
    echo "  Estado en OpenNebula: ${STATE:-PENDING} (Intento $i/60)"
    sleep 4
done

# ---------------------------------------------------------------
# 5. LIVE MIGRATION a node2
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] 🚀 Realizando LIVE MIGRATION a one-node2...${NC}"
echo -e "  ${YELLOW}¡Momento clave para la entrega del laboratorio!${NC}"
echo ""

# Enviar comando de migración en vivo
onevm migrate --live $VM_ID one-node2 2>/dev/null
echo "  Comando enviado. Monitoreando transferencia a través de la red NFS..."

for i in {1..20}; do
    # Obtener el host actual asignado a la VM
    CURRENT_HOST=$(onevm show $VM_ID | grep -E "^\s+HOST" | awk '{print $2}')
    STATE=$(onevm list | grep "demo-migra" | awk '{print $5}')
    
    if [ "$CURRENT_HOST" = "one-node2" ] && [ "$STATE" = "runn" ]; then
        echo -e "\n${GREEN}  ✅ MIGRACIÓN EN VIVO EXITOSA${NC}"
        echo -e "${GREEN}  VM movida de uno-node1 → one-node2 SIN PERDER DISPONIBILIDAD${NC}\n"
        onevm list | grep "demo-migra"
        break
    fi
    echo "  Progreso: Estado [$STATE] en el Servidor [$CURRENT_HOST] (Monitoreo ${i}/20)"
    sleep 3
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} DEMO COMPLETADA EXITOSAMENTE${NC}"
echo -e "${GREEN}============================================${NC}"
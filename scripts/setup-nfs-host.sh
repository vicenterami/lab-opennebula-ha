#!/bin/bash
# =============================================================================
# setup-nfs-host.sh — Configura el servidor NFS en TU LAPTOP (host físico)
# =============================================================================
# EJECUTAR COMO ROOT en tu laptop ANTES de correr Ansible:
#   sudo bash scripts/setup-nfs-host.sh
#
# Lo que hace:
#   1. Instala nfs-kernel-server
#   2. Crea /var/lib/one/datastores con los permisos correctos
#   3. Exporta ese directorio a la red del laboratorio (192.168.50.0/24)
#   4. Activa el servidor NFS
# =============================================================================

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN} Configurando servidor NFS para Lab OpenNebula HA${NC}"
echo -e "${GREEN}========================================================${NC}"

# Verificar que se corre como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Este script debe ejecutarse como root (sudo)${NC}"
    exit 1
fi

# ---------------------------------------------------------------
# 1. Instalar servidor NFS
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[1/5] Instalando nfs-kernel-server...${NC}"
apt-get update -qq
apt-get install -y nfs-kernel-server nfs-common

# ---------------------------------------------------------------
# 2. Crear y configurar el directorio que será exportado
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Creando directorio /var/lib/one/datastores...${NC}"
mkdir -p /var/lib/one/datastores

# UID/GID 9869 es el que usa oneadmin por defecto en OpenNebula
# Hay que asegurarse que las VMs y el host usen el mismo UID
# Si oneadmin no existe en el host, usamos el UID directamente
if id oneadmin &>/dev/null; then
    chown -R oneadmin:oneadmin /var/lib/one/datastores
    ONE_UID=$(id -u oneadmin)
    ONE_GID=$(id -g oneadmin)
else
    # Crear el usuario oneadmin en el host con UID fijo
    useradd --uid 9869 --gid 9869 --system --no-create-home oneadmin 2>/dev/null || true
    groupadd --gid 9869 oneadmin 2>/dev/null || true
    chown -R 9869:9869 /var/lib/one/datastores
    ONE_UID=9869
    ONE_GID=9869
fi

chmod 755 /var/lib/one/datastores
echo -e "${GREEN}  ✓ Directorio creado con UID:GID = ${ONE_UID}:${ONE_GID}${NC}"

# ---------------------------------------------------------------
# 3. Configurar /etc/exports
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Configurando /etc/exports...${NC}"

EXPORT_LINE="/var/lib/one/datastores  192.168.50.0/24(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=${ONE_UID},anongid=${ONE_GID})"

# Eliminar entrada anterior si existe y agregar la nueva
sed -i '\|/var/lib/one/datastores|d' /etc/exports
echo "$EXPORT_LINE" >> /etc/exports

echo -e "${GREEN}  ✓ Exportación configurada:${NC}"
echo "    $EXPORT_LINE"

# ---------------------------------------------------------------
# 4. Aplicar exports y arrancar NFS
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Aplicando configuración NFS...${NC}"
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
exportfs -ra

# ---------------------------------------------------------------
# 5. Verificación
# ---------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] Verificando configuración...${NC}"

echo -e "\n${GREEN}--- Exports activos: ---${NC}"
exportfs -v

echo -e "\n${GREEN}--- Estado del servicio NFS: ---${NC}"
systemctl status nfs-kernel-server --no-pager | head -5

# Detectar IP del host en la red del laboratorio
HOST_IP=$(ip -4 addr show | grep 'inet 192.168.50' | awk '{print $2}' | cut -d'/' -f1 | head -1)
if [ -z "$HOST_IP" ]; then
    # Intentar con la IP del bridge de libvirt
    HOST_IP=$(ip -4 addr show virbr0 | grep inet | awk '{print $2}' | cut -d'/' -f1 2>/dev/null || echo "NO DETECTADA")
fi

echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN} ✅ Servidor NFS configurado exitosamente${NC}"
echo -e "${GREEN}========================================================${NC}"
echo ""
echo -e "  ${YELLOW}IP del host (servidor NFS):${NC} ${HOST_IP}"
echo -e "  ${YELLOW}Directorio exportado:${NC}       /var/lib/one/datastores"
echo -e "  ${YELLOW}Red permitida:${NC}              192.168.50.0/24"
echo ""
echo -e "${YELLOW}NOTA: Si la IP del host no es 192.168.50.1, debes editar${NC}"
echo -e "${YELLOW}ansible/roles/nfs-client/tasks/main.yml y ajustar la IP.${NC}"
echo ""
echo -e "${GREEN}Próximo paso: cd terraform/ && terraform init && terraform apply${NC}"
#!/bin/bash
# Script para destruir y limpiar el laboratorio OpenNebula
# USO: ./limpia.sh
# ADVERTENCIA: destruye TODAS las VMs y discos del lab

echo "⚠️  Esto destruirá todas las VMs y discos del laboratorio OpenNebula."
read -p "¿Continuar? (escribe 'si' para confirmar): " confirm

if [ "$confirm" != "si" ]; then
    echo "Operación cancelada."
    exit 0
fi

echo "🗑️  Destruyendo infraestructura con Terraform..."
terraform destroy -auto-approve

echo "🧹 Limpiando archivos de estado..."
rm -rf .terraform*
rm -f terraform.tfstate*
rm -f crash.log

echo "✅ Laboratorio limpiado. Puedes volver a correr 'terraform init && terraform apply'."
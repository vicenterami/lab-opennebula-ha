# Lab OpenNebula HA — Mención Informática, Módulo 4

Implementación de infraestructura cloud on-premise en Alta Disponibilidad usando OpenNebula, desplegada sobre KVM con Terraform y configurada con Ansible.

## Arquitectura

```
HOST FÍSICO (vicenterog@vicenterog) — Servidor NFS
├── Red KVM: 192.168.50.0/24 (virbr/opennebula-net)
│
├── PLANO DE CONTROL (HA activo/pasivo)
│   ├── one-fe1  → 192.168.50.11  (Frontend OpenNebula + Keepalived MASTER)
│   └── one-fe2  → 192.168.50.12  (Frontend OpenNebula + Keepalived BACKUP)
│         └── IP Flotante: 192.168.50.10 (VIP Keepalived)
│
└── PLANO DE CÓMPUTO (KVM/QEMU Hypervisors)
    ├── one-node1 → 192.168.50.21 (Hypervisor KVM)
    └── one-node2 → 192.168.50.22 (Hypervisor KVM)

ALMACENAMIENTO: NFS desde host físico → /var/lib/one/datastores (montado en todas las VMs)
```

## Requisitos previos en el host

- KVM + libvirt instalados y activos
- Terraform >= 1.0 con provider `dmacvicar/libvirt`
- Ansible >= 2.10
- Imagen base Ubuntu 22.04 cloud en `~/vmstore/jammy-server-cloudimg-amd64.img`
- Llave SSH generada en `~/.ssh/id_ed25519`

## Pasos de despliegue

### 1. Preparar servidor NFS en el host

```bash
chmod +x scripts/setup-nfs-host.sh
sudo ./scripts/setup-nfs-host.sh
```

### 2. Desplegar VMs con Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### 3. Configurar todo con Ansible

```bash
cd ansible/
# Verificar conectividad primero
ansible all -i inventory.ini -m ping

# Desplegar
ansible-playbook -i inventory.ini site.yml
```

### 4. Acceder a Sunstone (UI web)

Abrir en el navegador: `http://192.168.50.10:9869` (IP flotante Keepalived)

Usuario por defecto: `oneadmin` / contraseña generada automáticamente en fe1.

## Estructura del repositorio

```
.
├── terraform/          # Infraestructura como código (VMs KVM)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── templates/
│       └── cloud_init.cfg
├── ansible/            # Configuración y despliegue de software
│   ├── inventory.ini
│   ├── site.yml
│   └── roles/
│       ├── common/           # Base OS: paquetes, usuarios, SSH
│       ├── nfs-client/       # Montar NFS desde host físico
│       ├── keepalived/       # IP Flotante para HA del frontend
│       ├── opennebula-frontend/  # Instala y configura oned + Sunstone
│       └── opennebula-node/      # Instala KVM + agente OpenNebula
├── scripts/
│   └── setup-nfs-host.sh    # Configura servidor NFS en tu laptop
└── docs/
    └── arquitectura.md       # Documentación para la presentación
```
variable "kvm_image_path" {
  type        = string
  description = "Ruta absoluta a la imagen cloud Ubuntu 22.04 .img en el host"
  # RUTA CORREGIDA: donde realmente está la imagen en tu sistema
  default     = "/home/vicenterog/vmstore/jammy-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Ruta a la llave pública SSH para inyectar en las VMs vía cloud-init"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vms" {
  type = map(object({
    cpu  = number
    ram  = number
    ip   = string
    role = string
  }))
  description = "Definición de las 4 VMs del laboratorio OpenNebula HA"
  default = {
    # --- PLANO DE CONTROL (Frontend HA) ---
    "one-fe1" = {
      cpu  = 2
      ram  = 2048   # 2 GB RAM
      ip   = "192.168.50.11"
      role = "frontend"
    }
    "one-fe2" = {
      cpu  = 2
      ram  = 2048   # 2 GB RAM
      ip   = "192.168.50.12"
      role = "frontend"
    }
    # --- PLANO DE CÓMPUTO (Hypervisors KVM) ---
    "one-node1" = {
      cpu  = 2
      ram  = 2048   # 2 GB RAM — suficiente para CirrOS/Alpine
      ip   = "192.168.50.21"
      role = "node"
    }
    "one-node2" = {
      cpu  = 2
      ram  = 2048   # 2 GB RAM
      ip   = "192.168.50.22"
      role = "node"
    }
  }
}
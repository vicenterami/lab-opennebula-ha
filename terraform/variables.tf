variable "kvm_image_path" {
  type        = string
  description = "Ruta absoluta a la imagen .qcow2 de Ubuntu Server en tu host"
  default     = "/var/lib/libvirt/images/jammy-server-cloudimg-amd64.img" 
}

variable "vm_user" {
  type    = string
  default = "ubuntu"
}

variable "vms" {
  type = map(object({
    cpu  = number
    ram  = number
    ip   = string
    role = string
  }))
  default = {
    "one-fe1" = {
      cpu  = 2
      ram  = 2048
      ip   = "192.168.50.11"
      role = "frontend"
    }
    "one-fe2" = {
      cpu  = 2
      ram  = 2048
      ip   = "192.168.50.12"
      role = "frontend"
    }
    "one-node1" = {
      cpu  = 2
      ram  = 2048
      ip   = "192.168.50.21"
      role = "node"
    }
    "one-node2" = {
      cpu  = 2
      ram  = 2048
      ip   = "192.168.50.22"
      role = "node"
    }
  }
}

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# 1. Definición de la Red Aislada del Laboratorio
resource "libvirt_network" "opennebula_net" {
  name      = "opennebula-net"
  mode      = "nat"
  domain    = "opennebula.local"
  addresses = ["192.168.50.0/24"]

  dns {
    enabled = true
    local_only = true
  }
}

# 2. Volúmen base (Imagen del Sistema Operativo)
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu_base.qcow2"
  pool   = "default"
  source = var.kvm_image_path
  format = "qcow2"
}

# 3. Volúmenes de disco específicos para cada VM (Copia enlazada para ahorrar espacio)
resource "libvirt_volume" "vm_disk" {
  for_each       = var.vms
  name           = "${each.key}-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = 21474836480 # 20 GB en bytes
  format         = "qcow2"
}

# 4. Configuración de Cloud-Init para inyectar SSH
resource "libvirt_cloudinit_disk" "common_init" {
  for_each  = var.vms
  name      = "${each.key}-init.iso"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    ssh_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
  })
}

# 5. Creación y Despliegue de las Máquinas Virtuales
resource "libvirt_domain" "opennebula_vms" {
  for_each = var.vms
  name     = each.key
  memory   = each.value.ram
  vcpu     = each.value.cpu

  # Crucial para habilitar virtualización anidada dentro de las VMs
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.common_init[each.key].id

  network_interface {
    network_id     = libvirt_network.opennebula_net.id
    addresses      = [each.value.ip]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

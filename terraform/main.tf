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

# ---------------------------------------------------------------
# 1. Red Aislada del Laboratorio OpenNebula
# ---------------------------------------------------------------
resource "libvirt_network" "opennebula_net" {
  name      = "opennebula-net"
  mode      = "nat"
  domain    = "opennebula.local"
  addresses = ["192.168.50.0/24"]

  # IP Flotante del Keepalived necesita ser parte de esta red
  # La VIP 192.168.50.10 será asignada dinámicamente por Keepalived

  dns {
    enabled    = true
    local_only = true
  }
}

# ---------------------------------------------------------------
# 2. Volumen base (imagen cloud Ubuntu 22.04 — no se modifica)
# ---------------------------------------------------------------
resource "libvirt_volume" "ubuntu_base" {
  name   = "opennebula-ubuntu-base.qcow2"
  pool   = "default"
  source = var.kvm_image_path
  format = "qcow2"
}

# ---------------------------------------------------------------
# 3. Discos individuales por VM (linked clones, ahorran espacio)
# ---------------------------------------------------------------
resource "libvirt_volume" "vm_disk" {
  for_each = var.vms

  name           = "one-${each.key}-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = 21474836480 # 20 GB en bytes
  format         = "qcow2"
}

# ---------------------------------------------------------------
# 4. Disco Cloud-Init por VM (inyecta usuario + SSH)
# ---------------------------------------------------------------
resource "libvirt_cloudinit_disk" "vm_init" {
  for_each = var.vms

  name      = "one-${each.key}-init.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/templates/cloud_init.cfg", {
    hostname = each.key
    ssh_key  = file(pathexpand(var.ssh_public_key_path))
  })
}

# ---------------------------------------------------------------
# 5. Máquinas Virtuales
# ---------------------------------------------------------------
resource "libvirt_domain" "vm" {
  for_each = var.vms

  name   = each.key
  memory = each.value.ram
  vcpu   = each.value.cpu

  # host-passthrough: habilita KVM anidado dentro de las VMs
  # (necesario para que los nodos puedan correr VMs de OpenNebula)
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.vm_init[each.key].id

  network_interface {
    network_id     = libvirt_network.opennebula_net.id
    addresses      = [each.value.ip]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  # Consola serie para troubleshooting (virsh console <vm>)
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # SPICE para acceso gráfico si es necesario
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # Asegura que la VM arranca y tiene IP antes de continuar
  provisioner "local-exec" {
    command = "echo 'VM ${each.key} desplegada en ${each.value.ip}'"
  }
}
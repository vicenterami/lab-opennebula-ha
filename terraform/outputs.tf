output "vm_ips" {
  description = "IPs asignadas a cada VM del laboratorio"
  value = {
    for name, vm in libvirt_domain.vm :
    name => vm.network_interface[0].addresses
  }
}

output "acceso_sunstone" {
  description = "URL de la interfaz web de OpenNebula (después de correr Ansible)"
  value       = "http://192.168.50.10:9869  (usuario: oneadmin)"
}

output "network_info" {
  description = "Red del laboratorio"
  value = {
    nombre  = libvirt_network.opennebula_net.name
    cidr    = "192.168.50.0/24"
    vip_ha  = "192.168.50.10 (Keepalived)"
    fe1     = "192.168.50.11"
    fe2     = "192.168.50.12"
    node1   = "192.168.50.21"
    node2   = "192.168.50.22"
  }
}
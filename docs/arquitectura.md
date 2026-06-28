# Arquitectura del Lab OpenNebula HA

## Resumen del Sistema

Infraestructura cloud **on-premise simulada** corriendo íntegramente en una laptop con KVM (virtualización anidada). Se implementa un clúster OpenNebula en **Alta Disponibilidad** con 4 nodos virtuales.

---

## Las 4 Capas de la Arquitectura

### Capa 1 — Almacenamiento Compartido (Persistencia)
- **Componente:** NFS Server corriendo en el **host físico (laptop)**
- **Qué hace:** Exporta `/var/lib/one/datastores` a la red `192.168.50.0/24`
- **Por qué es crítico:** Permite que las VMs de OpenNebula tengan sus discos accesibles desde **cualquier nodo de cómputo**. Sin esto, la Live Migration es imposible (la VM no puede moverse si su disco está atado a un solo nodo).

### Capa 2 — Red Virtual
- **Componente:** Red NAT de libvirt `opennebula-net`
- **Subred:** `192.168.50.0/24`
- **IPs del laboratorio:**
  - `.10` → VIP Keepalived (IP flotante, siempre apunta al FE activo)
  - `.11` → one-fe1
  - `.12` → one-fe2
  - `.21` → one-node1
  - `.22` → one-node2

### Capa 3 — Plano de Control HA (Frontend)
- **Componente:** 2 instancias de `oned` (daemon OpenNebula) + Keepalived
- **Protocolo HA:** Raft consensus (built-in en OpenNebula)
- **Puerto:** 2633 (comunicación entre frontends)
- **Keepalived:** Implementa VRRP para la IP Flotante `.10`
  - FE1 = MASTER (prioridad 101)
  - FE2 = BACKUP (prioridad 100)
  - Si FE1 cae → FE2 toma la VIP en ~3 segundos
- **Sunstone (UI web):** accesible en `http://192.168.50.10:9869`

### Capa 4 — Plano de Cómputo (Hypervisors)
- **Componente:** 2 nodos KVM con `libvirtd` y agente `opennebula-node-kvm`
- **Hypervisor:** QEMU/KVM con virtualización anidada (host-passthrough)
- **Función:** Ejecutan las VMs de los usuarios finales

---

## Flujo de Alta Disponibilidad (qué pasa si cae FE1)

```
1. FE1 se apaga (falla hardware simulada)
2. Keepalived en FE2 detecta ausencia de heartbeat VRRP en <3 seg
3. FE2 se apropia de la VIP 192.168.50.10
4. oned en FE2 es promovido a LEADER por el protocolo Raft
5. Sunstone sigue respondiendo en http://192.168.50.10:9869
6. Las VMs en los nodos siguen corriendo sin interrupción
```

---

## Flujo de Live Migration (demo en vivo)

```
1. VM "demo-migra" corre en one-node1
2. Se ejecuta: onevm migrate --live <ID> one-node2
3. OpenNebula copia las páginas de memoria activas al destino (pre-copy)
4. Duran# Arquitectura del Lab OpenNebula HA

## Resumen del Sistema

Infraestructura cloud **on-premise simulada** corriendo íntegramente en una laptop con KVM (virtualización anidada). Se implementa un clúster OpenNebula en **Alta Disponibilidad** con 4 nodos virtuales.

---

## Las 4 Capas de la Arquitectura

### Capa 1 — Almacenamiento Compartido (Persistencia)
- **Componente:** NFS Server corriendo en el **host físico (laptop)**
- **Qué hace:** Exporta `/var/lib/one/datastores` a la red `192.168.50.0/24`
- **Por qué es crítico:** Permite que las VMs de OpenNebula tengan sus discos accesibles desde **cualquier nodo de cómputo**. Sin esto, la Live Migration es imposible (la VM no puede moverse si su disco está atado a un solo nodo).

### Capa 2 — Red Virtual
- **Componente:** Red NAT de libvirt `opennebula-net`
- **Subred:** `192.168.50.0/24`
- **IPs del laboratorio:**
  - `.10` → VIP Keepalived (IP flotante, siempre apunta al FE activo)
  - `.11` → one-fe1
  - `.12` → one-fe2
  - `.21` → one-node1
  - `.22` → one-node2

### Capa 3 — Plano de Control HA (Frontend)
- **Componente:** 2 instancias de `oned` (daemon OpenNebula) + Keepalived
- **Protocolo HA:** Raft consensus (built-in en OpenNebula)
- **Puerto:** 2633 (comunicación entre frontends)
- **Keepalived:** Implementa VRRP para la IP Flotante `.10`
  - FE1 = MASTER (prioridad 101)
  - FE2 = BACKUP (prioridad 100)
  - Si FE1 cae → FE2 toma la VIP en ~3 segundos
- **Sunstone (UI web):** accesible en `http://192.168.50.10:9869`

### Capa 4 — Plano de Cómputo (Hypervisors)
- **Componente:** 2 nodos KVM con `libvirtd` y agente `opennebula-node-kvm`
- **Hypervisor:** QEMU/KVM con virtualización anidada (host-passthrough)
- **Función:** Ejecutan las VMs de los usuarios finales

---

## Flujo de Alta Disponibilidad (qué pasa si cae FE1)

```
1. FE1 se apaga (falla hardware simulada)
2. Keepalived en FE2 detecta ausencia de heartbeat VRRP en <3 seg
3. FE2 se apropia de la VIP 192.168.50.10
4. oned en FE2 es promovido a LEADER por el protocolo Raft
5. Sunstone sigue respondiendo en http://192.168.50.10:9869
6. Las VMs en los nodos siguen corriendo sin interrupción
```

---

## Flujo de Live Migration (demo en vivo)

```
1. VM "demo-migra" corre en one-node1
2. Se ejecuta: onevm migrate --live <ID> one-node2
3. OpenNebula copia las páginas de memoria activas al destino (pre-copy)
4. Durante la copia, la VM sigue atendiendo requests
5. En el último paso (<100ms de pausa), se completa la transferencia
6. La VM ahora corre en one-node2
7. El disco NO se mueve (ya estaba en NFS, ambos nodos lo ven)
```

**Por qué esto demuestra que el NFS funciona:** La Live Migration solo es posible si ambos nodos acceden al mismo disco. Si el NFS no estuviera configurado, la migración fallaría con error de acceso al datastore.

---

## Comparación: OpenNebula vs OpenStack (para preguntas del docente)

| Criterio | OpenNebula | OpenStack (DevStack) |
|---|---|---|
| Filosofía | Monolítica (un daemon `oned`) | Microservicios (Nova, Neutron, Glance, Keystone...) |
| Consumo RAM | ~2 GB por frontend | ~8-16 GB solo para el controlador |
| Complejidad instalación | Media | Alta |
| Gestión de redes | Simple (Linux Bridges nativos) | Compleja (Neutron SDN) |
| Multi-tenancy | Básico (grupos/VDC) | Avanzado (proyectos/tenants aislados) |
| Curva de aprendizaje | Baja-Media | Alta |
| Casos de uso ideales | Empresas medianas, edge, laboratorio | Telcos, nube pública grande |
| HA del control plane | Raft integrado | Necesita configuración extra (Pacemaker) |

### Respuestas preparadas para el docente

**¿Cuál te parece más compleja y por qué?**
OpenStack es considerablemente más compleja. Tiene más de 10 servicios independientes (Nova para cómputo, Neutron para redes, Glance para imágenes, Keystone para identidad, Cinder para almacenamiento en bloque...) que deben coordinarse entre sí. Un fallo en uno puede cascadear a otros. OpenNebula concentra toda la lógica en `oned`, lo que simplifica la operación pero limita la escalabilidad horizontal de cada componente.

**¿En qué escenario usarías una u otra?**
OpenNebula es ideal para empresas medianas que necesitan una nube privada sin un equipo dedicado de 10 ingenieros. También es ideal para educación y laboratorio por su bajo consumo. OpenStack es la elección cuando se necesita aislamiento fuerte de tenants (proveedor de nube pública), redes SDN avanzadas, o se dispone de hardware bare-metal a gran escala.

**¿Qué ventajas o limitaciones identificas?**
OpenNebula: ventaja en simplicidad operacional y bajo overhead. Limitación en ecosistema (menos integraciones nativas). OpenStack: ventaja en flexibilidad y ecosistema enorme. Limitación en complejidad y consumo de recursos.te la copia, la VM sigue atendiendo requests
5. En el último paso (<100ms de pausa), se completa la transferencia
6. La VM ahora corre en one-node2
7. El disco NO se mueve (ya estaba en NFS, ambos nodos lo ven)
```

**Por qué esto demuestra que el NFS funciona:** La Live Migration solo es posible si ambos nodos acceden al mismo disco. Si el NFS no estuviera configurado, la migración fallaría con error de acceso al datastore.

---

## Comparación: OpenNebula vs OpenStack (para preguntas del docente)

| Criterio | OpenNebula | OpenStack (DevStack) |
|---|---|---|
| Filosofía | Monolítica (un daemon `oned`) | Microservicios (Nova, Neutron, Glance, Keystone...) |
| Consumo RAM | ~2 GB por frontend | ~8-16 GB solo para el controlador |
| Complejidad instalación | Media | Alta |
| Gestión de redes | Simple (Linux Bridges nativos) | Compleja (Neutron SDN) |
| Multi-tenancy | Básico (grupos/VDC) | Avanzado (proyectos/tenants aislados) |
| Curva de aprendizaje | Baja-Media | Alta |
| Casos de uso ideales | Empresas medianas, edge, laboratorio | Telcos, nube pública grande |
| HA del control plane | Raft integrado | Necesita configuración extra (Pacemaker) |

### Respuestas preparadas para el docente

**¿Cuál te parece más compleja y por qué?**
OpenStack es considerablemente más compleja. Tiene más de 10 servicios independientes (Nova para cómputo, Neutron para redes, Glance para imágenes, Keystone para identidad, Cinder para almacenamiento en bloque...) que deben coordinarse entre sí. Un fallo en uno puede cascadear a otros. OpenNebula concentra toda la lógica en `oned`, lo que simplifica la operación pero limita la escalabilidad horizontal de cada componente.

**¿En qué escenario usarías una u otra?**
OpenNebula es ideal para empresas medianas que necesitan una nube privada sin un equipo dedicado de 10 ingenieros. También es ideal para educación y laboratorio por su bajo consumo. OpenStack es la elección cuando se necesita aislamiento fuerte de tenants (proveedor de nube pública), redes SDN avanzadas, o se dispone de hardware bare-metal a gran escala.

**¿Qué ventajas o limitaciones identificas?**
OpenNebula: ventaja en simplicidad operacional y bajo overhead. Limitación en ecosistema (menos integraciones nativas). OpenStack: ventaja en flexibilidad y ecosistema enorme. Limitación en complejidad y consumo de recursos.
# libvirt on arrakis

Decision **D8** (2026-11-08): use libvirt and QEMU on the existing kernel. Do
not install Proxmox. See learning.md Q11 and Q12 for the reasoning.

## The three layers

```
KVM      already in the kernel    virtual CPU and memory
QEMU     to install               virtual disk, network card, screen
libvirt  to install               remembers each VM, starts and stops them
```

## Versions available, checked 2026-11-08

Read from `apt-cache policy` on arrakis. All were `Installed: (none)`.

| Package | Version | Why it is needed |
|---|---|---|
| `qemu-system-x86` | 1:10.0.13+ds-0+deb13u1 | The virtual hardware |
| `libvirt-daemon-system` | 11.3.0-3+deb13u3 | The service that manages VMs |
| `libvirt-clients` | 11.3.0-3+deb13u3 | The `virsh` command |
| `virtinst` | 1:5.0.0-5+deb13u1 | `virt-install`, to create a VM |
| `dnsmasq-base` | 2.91-1+deb13u2 | The DHCP and DNS server on the VM network |
| `ovmf` | 2025.02-8+deb13u1 | UEFI firmware for the guests |

`dnsmasq-base` is the piece that makes NAT work. It hands each VM an address.
Note it is `dnsmasq-base`, **not** `dnsmasq`. The plain `dnsmasq` package runs a
server on the host and will conflict with libvirt.

## Files in this directory

```
networks/arrakis-nat.xml    the private NAT network, 10.10.10.0/24
domains/                    one XML file per VM (empty until the VMs exist)
```

These files are the source of truth. A change goes here first, then onto the
machine. Never edit a definition only with `virsh edit`, or this directory and
the machine will drift apart.

## The address plan

```
10.10.10.1              arrakis itself, on the virtual switch
10.10.10.11  mentat     the Kubernetes node
10.10.10.12  windtrap   PostgreSQL, Redis
10.10.10.13  sietch   a second node, later
10.10.10.100-200        pool for temporary VMs
```

Each VM has a fixed MAC address in the network file, so its address never moves.
The `52:54:00` prefix is the range reserved for QEMU.

## How the network works

```
   mentat   10.10.10.11 --+
   windtrap 10.10.10.12 --+--> virbr-arrakis --> NAT --> wlp3s0 --> router
   sietch 10.10.10.13 --+    (software switch)  (rewrite  192.168.1.21
                               10.10.10.1          sender)
```

A VM can start a connection outward. Nothing outside can reach a VM inward
without a forwarding rule added by hand.

To reach a VM from your PC, go through arrakis:

```bash
ssh -J arrakis muaddib@10.10.10.12
```

**`-J`** means "jump": connect to arrakis first, then on to the VM from there.
Nothing needs to be exposed.

## Exporting a definition back into this repository

After libvirt creates or changes a VM, write the result back here:

```bash
ssh arrakis 'virsh dumpxml windtrap' > libvirt/domains/windtrap.xml
```

**dumpxml** prints the live definition. Keep that file in git so a VM can be
rebuilt exactly.

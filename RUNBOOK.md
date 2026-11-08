# RUNBOOK: rebuild arrakis from nothing

Every step, in order, with nothing assumed. Follow it top to bottom and you get
the same machine. Each step says **where to run it**, because that was the
source of a real mistake (learning.md Q9).

Verified on 2026-11-08 against the live machine. Every version number here was
read from the machine or from the project's own release API, never from memory.

Legend for where a command runs:

```
[PC]       your laptop, the Omarchy one
[arrakis]  on arrakis, after `ssh arrakis`
```

---

## 0. Starting point

```
arrakis    Dell laptop, Debian 13 (trixie), kernel 6.12.111+deb13-amd64
CPU        Intel i5-1135G7, 4 cores, 8 threads, vmx present
RAM        11690 MB
Disk       456 GB
Wi-Fi      Qualcomm Atheros QCA9377, driver ath10k_pci
Ethernet   enp2s0 present but the port does not work
Network    ifupdown + wpa_supplicant. NetworkManager NOT installed.
Tailscale  100.114.18.44
cgroups    v2
Firmware   EFI with GRUB. systemd-boot not installed.
```

---

## 1. Access

**[PC]** Confirm the agent holds a key.

```bash
echo "$SSH_AUTH_SOCK"        # expect /run/user/1000/ssh-agent.socket
ssh-add -l                   # expect: sohail-omarchy (ED25519)
ssh arrakis 'hostname'       # expect: arrakis
```

If `ssh-add -l` is empty, the systemd user agent is not running. Start it with
`systemctl --user start ssh-agent.socket`.

---

## 2. Stop the machine sleeping

A laptop suspends when the lid shuts. A server must not. **(blocker B1, fixed)**

**[arrakis]**

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-server-no-sleep.conf >/dev/null <<'EOF'
[Login]
# arrakis is a server, not a personal laptop. Ignore the lid.
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl reload systemd-logind
```

**Verify. Do not trust the file; ask logind what it is using.**

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitch
```

Must print `s "ignore"`. If it prints `suspend`, use `restart` instead of
`reload`.

All three settings are needed. `HandleLidSwitch` alone covers battery power
only; `ExternalPower` covers the charger, which is arrakis's normal state.

---

## 3. Install the virtualisation stack

KVM is already in the kernel. Confirm, then add the missing layers.

**[arrakis]**

```bash
# confirm the engine is there
ls -l /dev/kvm                            # must exist
lsmod | grep '^kvm'                       # kvm, kvm_intel loaded
grep -oE 'vmx|svm' /proc/cpuinfo | sort -u   # must print vmx

sudo apt update
sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients \
  virtinst dnsmasq-base ovmf

sudo usermod -aG libvirt,kvm "$USER"
exec newgrp libvirt
```

Versions installed on 2026-11-08:

```
qemu-system-x86         1:10.0.13+ds-0+deb13u1
libvirt-daemon-system   11.3.0-3+deb13u3
libvirt-clients         11.3.0-3+deb13u3
virtinst                1:5.0.0-5+deb13u1
dnsmasq-base            2.91-1+deb13u2
ovmf                    2025.02-8+deb13u1
cloud-image-utils       0.33-1
```

**`dnsmasq-base`, NOT `dnsmasq`.** The plain package runs a DNS server on the
host and conflicts with libvirt.

**`-aG`, not `-G`.** Without `-a` you replace every group the user has.

Make `virsh` talk to the system's VMs rather than your user's private set:

```bash
echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> ~/.zshrc
export LIBVIRT_DEFAULT_URI=qemu:///system
```

**Verify:**

```bash
systemctl is-active libvirtd      # active
virsh version                     # libvirt 11.3.0, QEMU 10.0.13
```

---

## 4. The storage pool

**[arrakis]**

```bash
sudo mkdir -p /var/lib/libvirt/images
sudo mkdir -p /var/lib/libvirt/qemu/nvram    # for UEFI settings files
virsh pool-define-as arrakis-images dir --target /var/lib/libvirt/images
virsh pool-start arrakis-images
virsh pool-autostart arrakis-images
virsh pool-list --all                        # active, autostart yes
```

All three steps matter. **define** writes it, **start** activates it now,
**autostart** brings it back after a reboot. Skipping the third is a common
cause of VMs that will not start after a restart.

---

## 5. The NAT network

The VMs cannot be bridged onto Wi-Fi. This is a hardware limit, not a choice:

```bash
iw phy phy0 info | grep -A3 'Supported interface modes'
# IBSS, managed only. No AP mode, no 4-address mode.
```

A Wi-Fi client frame has three address fields; carrying traffic for a machine
behind it needs a fourth. So NAT is forced. See learning.md Q5 and Q6.

**[arrakis]**

```bash
cat > /tmp/arrakis-nat.xml <<'EOF'
<network>
  <name>arrakis-nat</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr-arrakis' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.10.10.100' end='10.10.10.200'/>
      <host mac='52:54:00:10:10:11' name='mentat'   ip='10.10.10.11'/>
      <host mac='52:54:00:10:10:12' name='windtrap' ip='10.10.10.12'/>
      <host mac='52:54:00:10:10:13' name='sietch' ip='10.10.10.13'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/arrakis-nat.xml
virsh net-start arrakis-nat
virsh net-autostart arrakis-nat
virsh net-undefine default        # remove libvirt's unused 192.168.122.0/24
virsh net-list --all              # arrakis-nat active, autostart yes
```

The source of truth for this file is
`libvirt/networks/arrakis-nat.xml` in this repository. Change it there first.

---

## 6. arrakis needs its own SSH key

arrakis is logged **into** from the PC, so it never had a key of its own.
Without one it cannot log into the VMs.

**[arrakis]**

```bash
ssh-keygen -t ed25519 -C "arrakis-to-vms" -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub        # must print a key
```

`-N ""` sets an empty passphrase, which is correct for a key a machine uses
unattended.

---

## 7. The base cloud image

**[arrakis]**

```bash
cd /var/lib/libvirt/images
sudo wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2

echo "1207e6e3efaff8ee77ab7a32c156a3eea6a9e53f94cfc48efbd1f49ba554ca36ac62ab27395aa813a1775a8c0a393b1a1ce5377d9e5670f6113e3110c57fee4b  debian-13-generic-amd64.qcow2" | sha512sum -c
```

Must print `OK`. The checksum came from Debian's own `SHA512SUMS` file.

If the image is newer than 2026-11-08, fetch the current checksum rather than
using the line above:

```bash
curl -s https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS \
  | grep generic-amd64.qcow2
```

A **cloud image** is Debian already installed, with no installer and no
password. It reads its settings on first boot. That is what makes it scriptable.

**Never use this file directly.** Copy it per VM so it stays pristine.

---

## 8. mentat, by hand

`mentat` is the Kubernetes node. It is deliberately **not** managed by OpenTofu
(decision D11: a resource is managed by one or the other, never both).

**[arrakis]**

```bash
cd /tmp
cat > user-data <<EOF
#cloud-config
hostname: mentat
fqdn: mentat.arrakis.local
users:
  - name: muaddib
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_ed25519.pub)
      - $(grep -m1 'sohail-omarchy' ~/.ssh/authorized_keys)
package_update: true
EOF

cat > meta-data <<EOF
instance-id: mentat-001
local-hostname: mentat
EOF

# CHECK THE SUBSTITUTION WORKED. This is not optional.
grep -c 'ssh-ed25519' user-data        # MUST print 2
```

`$(cat missing-file)` fails **silently** into an empty string. The first attempt
produced a config with no key, which would have made the VM impossible to log
into, because cloud images have no password. Count the result before using it.

```bash
cloud-localds /tmp/mentat-seed.iso user-data meta-data
sudo cp /tmp/mentat-seed.iso /var/lib/libvirt/images/

sudo cp /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
        /var/lib/libvirt/images/mentat.qcow2
sudo qemu-img resize /var/lib/libvirt/images/mentat.qcow2 20G
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/mentat.qcow2 \
                                      /var/lib/libvirt/images/mentat-seed.iso

virt-install \
  --name mentat \
  --memory 3072 --vcpus 2 \
  --boot uefi \
  --disk /var/lib/libvirt/images/mentat.qcow2,bus=virtio \
  --disk /var/lib/libvirt/images/mentat-seed.iso,device=cdrom \
  --network network=arrakis-nat,mac=52:54:00:10:10:11 \
  --os-variant debian13 \
  --import --graphics none --noautoconsole --autostart
```

### `--boot uefi` is mandatory

Without it the VM boot-loops in silence. `virsh list` reports `running` while
nothing works, and the QEMU log shows no error. The symptom on the console is:

```
  Booting `Debian GNU/Linux'
  Booting `Debian GNU/Linux'
  Booting `Debian GNU/Linux'
```

Debian's cloud image expects UEFI. `virt-install` defaults to BIOS. This cost
four attempts to find. Full account in learning.md Q14.

`chown libvirt-qemu` also matters: QEMU runs as that user, and the failure
without it reads like a missing file, not a permission problem.

**Verify:**

```bash
virsh list --all                      # mentat running
sleep 45                              # first boot takes about 41 s
virsh net-dhcp-leases arrakis-nat     # 10.10.10.11, hostname mentat
ssh muaddib@10.10.10.11 'hostname'    # mentat
ssh muaddib@10.10.10.11 'ping -c1 1.1.1.1 >/dev/null && echo "NAT works"'
```

Watch a failed boot with `virsh console mentat`. **Escape with Ctrl + ]** —
never Ctrl+C, and never by closing the terminal, or the console stays attached
and blocks the next attempt.

### Record it back into this repository

**[PC]**

```bash
cd ~/Github/arrakis
ssh arrakis 'virsh --connect qemu:///system dumpxml mentat' > libvirt/domains/mentat.xml
```

Otherwise the machine and the repository drift apart.

---

## 9. windtrap, with OpenTofu

**[PC]**

```bash
yay -S opentofu
tofu version
```

Arch ships **1.12.1** in `extra`. Upstream's newest is 1.13.9 (2026-11-05). The
configuration needs only `>= 1.6`, so 1.12.1 is fine.

```bash
ssh arrakis 'sudo mkdir -p /var/lib/libvirt/qemu/nvram'

cd ~/Github/arrakis/tofu
tofu init
```

`tofu init` downloads the provider, pinned to exactly `0.9.9`, and writes
`.terraform/` plus a lock file. The pin matters: the provider is pre-1.0, so its
settings can change between releases.

```bash
cat > terraform.tfvars <<EOF
ssh_public_keys = [
  "$(cat ~/.ssh/id_ed25519.pub)",
]
EOF
```

`terraform.tfvars` is in `.gitignore`. Keys and state never go into git.

```bash
tofu plan      # a dry run. Changes nothing. READ IT.
tofu apply
```

`tofu plan` is the one thing the by-hand path has no equivalent for. Read it
before every `apply`.

**Verify:**

```bash
ssh arrakis 'virsh --connect qemu:///system list --all'
ssh -J arrakis muaddib@10.10.10.12 'hostname; free -m | head -2'
```

`-J` means "jump": connect to arrakis first, then on to the VM. Nothing on the
VM network is exposed outside arrakis.

### Undoing it

```bash
tofu destroy
```

Removes the VM **and its disk**, with no backup. Never run it once `windtrap`
holds a real database.

---

## 10. Expected end state

```
arrakis                       11690 MB RAM, about 8700 MB available
├── virbr-arrakis  10.10.10.1/24   NAT, dnsmasq
├── mentat         10.10.10.11     3 GB, 2 vCPU   by hand
└── windtrap       10.10.10.12     2 GB, 2 vCPU   OpenTofu
```

**A VM costs what it has touched, not what it was promised.** Measured
2026-11-08: a 3 GB VM held only **1023 MB** of real host memory, because QEMU
hands memory over lazily. That is what makes three VMs fit in 11 GB.

---

## 11. Things that are still not done

See `TODO.md`. The largest is **T1**: ccache misses 99.66 percent of its lookups,
so the nightly ClickHouse build recompiles about 46000 files from scratch every
night.

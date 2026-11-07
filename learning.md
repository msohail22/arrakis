# learning.md

A running log of this project. Every question, answer, decision and command goes
here. Newest entries go at the bottom of each section.

Rules for this file:
- Write it in plain words. Assume zero prior knowledge.
- Every command gets a line that says what it means.
- Every decision gets a date and a reason.

---

## 1. Decisions taken

| # | Date | Decision | Reason |
|---|---|---|---|
| D1 | 2026-11-08 | Two repositories: `quarantine` for the app, `arrakis` for the machine | They change at different times. Argo CD watches `quarantine`; machine tweaks must not trigger it. |
| D2 | 2026-11-08 | Use OpenTofu, not Terraform | Terraform's licence changed from open source (MPL-2.0) to BUSL in August 2023. OpenTofu is the open fork. |
| D3 | 2026-11-08 | Name the machine repository `arrakis` | One machine, one name. |
| D4 | 2026-11-08 | **No Ethernet. The VMs will use NAT.** | The Ethernet port on arrakis does not work. Wi-Fi cannot be bridged. NAT is the only remaining option. |
| D6 | 2026-11-08 | Ignore the laptop lid. arrakis is a server. | Closing the lid suspended the whole machine. Verified with `busctl`, fixed with a drop-in file. |
| D7 | 2026-11-08 | Use a systemd **drop-in** file, never edit `logind.conf` directly | A systemd package update can rewrite `logind.conf` and silently undo the edit. It never touches a drop-in. |
| D8 | 2026-11-08 | **Use libvirt and QEMU on the existing kernel. Do not install Proxmox.** | KVM is already in the running kernel (Q11). Proxmox would replace that kernel for a web interface and cluster features that need more than one machine. It also risks losing Wi-Fi, which is the only way in. Cost: about 50 MB against about 700 MB. |
| D9 | 2026-11-08 | Name the database VM `windtrap`, not `db` | A windtrap collects moisture from the air and stores it. Exact metaphor for a database, and unambiguous on a command line. |
| D10 | 2026-11-08 | Build `windtrap` with OpenTofu, not by hand | Learning OpenTofu is a goal of the project, and `mentat` already proved the recipe. Overrules the advice to do it by hand first; see Q16. |
| D11 | 2026-11-08 | A resource is managed by OpenTofu **or** by hand, never both | OpenTofu keeps a state file of what it believes exists. A `virsh` change behind its back makes the next `apply` behave confusingly. |
| D12 | 2026-11-08 | Keep four files with four jobs: RUNBOOK (rebuild), plan (now), learning (why), TODO (next) | Mixing them is what makes a project unreproducible. Each has its own tense. |
| D13 | 2026-11-08 | OpenTofu state and `terraform.tfvars` stay out of git; `.terraform.lock.hcl` goes in | State is a record of reality and may hold secrets. The lock file is intent, and pins the provider for other machines. |
| ~~D5~~ | ~~open~~ | ~~Proxmox or no Proxmox~~ | **Closed by D8 on 2026-11-08.** |

---

## 2. Questions and answers

### Q1. Should the infrastructure live in the `quarantine` repository or its own?

**Answer: its own.** Split by how often a thing changes, not by subject.

Code changes often. The machine changes rarely. Argo CD watches the code
repository and syncs the cluster on every commit. If machine notes lived there
too, every note would trigger a sync.

Everyday comparison: the recipe book and the kitchen wiring diagram are separate
documents. You rewrite recipes weekly. You rewire the kitchen once.

### Q2. Was Terraform dropped?

**No. Its licence changed.** In August 2023 HashiCorp moved Terraform from
MPL-2.0 (open source) to BUSL, which restricts commercial use. OpenTofu is a
copy of the last open version, now run by the Linux Foundation. Same lineage,
different licence, and the command is `tofu` instead of `terraform`.

Latest version checked 2026-11-08: **OpenTofu v1.13.9**.

### Q3. Does OpenTofu install Proxmox?

**No.** OpenTofu gives orders to things that are already running. It talks over
an API — a network interface that a running program offers. Proxmox's API lives
at port 8006. That port does not exist until Proxmox is installed.

The official docs say:
> "OpenTofu creates and manages resources on cloud platforms and other services
> through their application programming interfaces (APIs)."

The Proxmox provider's own docs give it away in their example:
```hcl
password = "the-password-set-during-installation-of-proxmox-ve"
```
You can only fill that in **after** installing Proxmox.

**The correct order and tool for each step:**

```
1. install Proxmox on the laptop        apt, by hand, once
2. the Proxmox API appears on :8006     automatic
3. create the 3 VMs                     OpenTofu
4. install software inside the VMs      Ansible
```

**The dividing line: OpenTofu makes empty boxes. Ansible fills them.**

Versions checked 2026-11-08: provider `bpg/proxmox` v0.120.0, needs Proxmox VE
9.x. It is still version 0.x, so pin the exact version — the settings can change
between releases.

### Q4. Do we need to set up Wi-Fi on arrakis?

**No. It already works.** Measured 2026-11-08:

```
wlp3s0   UP   192.168.1.21/24   gateway 192.168.1.1
SSID     Airtel_aksh_6013   5 GHz   signal -68 dBm
managed by  ifupdown + wpa_supplicant
```

`wpa_supplicant` is the program that joins the laptop to Wi-Fi. It is already
enabled and running. Nothing to install.

One piece of luck: **NetworkManager is not installed.** Proxmox and
NetworkManager both want to control the network interfaces. They would fight.
They cannot, because only one of them is here.

### Q5. Why can the VMs not just share the Wi-Fi connection?

Because of how Wi-Fi frames are built. This is a hardware and protocol limit,
not a setting.

A **bridge** is a network switch made of software. A switch reads the addresses
written in each frame and forwards it to the right place.

An Ethernet frame has two addresses: who sent it, who it is for. That is enough.

A Wi-Fi frame in client mode has three: sender, receiver, and the access point.
To carry traffic for a machine sitting *behind* the laptop, it needs a **fourth**
address field. That is called 4-address mode. Intel Wi-Fi cards do not have it.

```
Ethernet frame            Wi-Fi client frame
+-----+-----+------+      +-----+-----+-----+------+
| dst | src | data |      | AP  | src | dst | data |
+-----+-----+------+      +-----+-----+-----+------+
  a bridge works             no field left to say
                             "this is for the VM behind me"
```

The card confirmed it:
```
$ iw phy phy0 info
    Supported interface modes:
         * IBSS
         * managed
```
`managed` means "client only". No AP mode. No 4-address mode.

The card is a **Qualcomm Atheros QCA9377**, driver `ath10k_pci`, firmware from
the package `firmware-atheros`. (Corrected 2026-11-08: an earlier entry said
Intel `iwlwifi`. Wrong chip, same conclusion — the `iw phy` output is the
measurement that decides it.)

**So: NAT is forced, not chosen.** See the next answer.

### Q6. What is NAT and why do we need it? (decision D4)

**NAT** means Network Address Translation. One real address, shared by many
private ones.

The VMs get private addresses that only exist inside arrakis. When a VM sends
traffic out, arrakis rewrites the sender address to its own. When the answer
comes back, arrakis looks up which VM asked, and rewrites it back.

```
   VM mentat   10.10.10.11 --+
   VM windtrap 10.10.10.12 --+--> vmbr0 ---> NAT ---> wlp3s0 ---> router
   VM sietch-1 10.10.10.13 --+   (software   (rewrite  192.168.1.21
                                  switch)     sender)
```

`vmbr0` is that software switch. It has no physical cable attached. It only
joins the VMs to each other and to the host.

Everyday comparison: an office with one phone line. Each desk has an extension
number. The switchboard places every outgoing call on the one line, and
remembers which extension made it, so the answer reaches the right desk. Nobody
outside can dial an extension directly.

**What NAT costs you:** a VM can start a connection outward. Nothing outside can
start a connection inward to a VM, unless you add a forwarding rule by hand for
each port.


### Q7. What is "the lid"?

The lid is **the screen half of a laptop** — the part you close onto the
keyboard.

Linux assumes a laptop belongs to a person who walks away. So the default is:
close the lid, the machine sleeps. Sleep means everything stops, not just the
screen.

arrakis is not a personal laptop any more. It is a server. A server must keep
running with nobody sitting at it.

```
lid open                        lid closed (before the fix)
+------------------+            +------------------+
| ClickHouse build |            |  everything      |
| Tailscale        |    --->    |  STOPPED         |
| your SSH session |            |  SSH fails       |
+------------------+            +------------------+
```

Everyday comparison: a fridge light goes out when you shut the door, but the
fridge keeps cooling. arrakis should be the fridge.

### Q8. Was the lid really a problem, or was I imagining it?

**It was real.** Reading the config file was not enough, because the setting was
commented out, and a commented setting falls back to a built-in default. The
reliable way is to ask logind what value it is using *right now*:

```
$ busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager HandleLidSwitch
s "suspend"
```

Supporting evidence gathered at the same time:

```
drop-in dirs      none existed
logind.conf       held only "[Login]" — nothing set
/sys/power/state  freeze mem    <- sleep is supported, so it would have worked
lid state         open          <- why nothing had happened yet
suspends so far   none this boot
```

**Conclusion: lucky, not safe.** The lid had simply never been closed.

Three settings had to change, not one. `HandleLidSwitch` only covers battery
power. `HandleLidSwitchExternalPower` covers it while the charger is plugged in,
which is arrakis's normal state — and that one was **empty**, so it fell back to
the same `suspend` default.

### Q9. Why did `ssh arrakis '...'` fail with "Permission denied (publickey)"?

Because the command was run **from inside arrakis**, not from the PC.

```
➜  arrakis git:(main) ✗ ssh muaddib@arrakis     <- logged IN to arrakis
➜  ~ ssh arrakis 'sudo mkdir -p ...'            <- this ran ON arrakis
The authenticity of host 'arrakis (127.0.1.1)'  <- arrakis calling itself
muaddib@arrakis: Permission denied (publickey)
```

The second prompt belonged to arrakis's shell. So `ssh arrakis` told arrakis to
SSH to itself at `127.0.1.1`. arrakis holds no key authorising itself.

```
What was meant:                What happened:
PC --ssh--> arrakis            PC --ssh--> arrakis --ssh--> arrakis
                                                     X no key
```

**Rule: `ssh arrakis '<command>'` is for running from the PC. Once you are
logged in you are already there — type the command with no wrapper.**

Side effect: arrakis now lists itself in `~/.ssh/known_hosts` at `127.0.1.1`.
Harmless, but it is the same loopback address as blocker B2.


### Q10. How was the Wi-Fi chip identified, and how was the earlier error caught?

This entry exists as the **example of how every correction gets logged**: the
wrong claim, the command that exposed it, and the command that found the truth.

**The wrong claim (2026-11-08, earlier the same day):** "the card is an Intel
chip on the `iwlwifi` driver". That was asserted from memory, not measured. It
was wrong.

**What exposed it.** While checking whether Wi-Fi would survive a kernel swap,
the firmware packages were listed:

```bash
ssh arrakis 'dpkg -l | grep -i firmware'
```
**dpkg -l** lists installed packages. Result:

```
firmware-atheros        <- Atheros, not Intel
firmware-intel-graphics
firmware-realtek
firmware-sof-signed
intel-microcode
```

`firmware-iwlwifi` was **absent**. If the card were Intel, Wi-Fi could not have
worked without it. That contradiction is what forced a real check.

**The command that found the truth:**

```bash
ssh arrakis 'lspci -nnk | grep -iA3 "network\|wireless"'
```
**lspci** lists devices on the PCI bus — the internal bus that connects the
Wi-Fi card, the graphics and the disk controller. The flags:
**`-nn`** prints the numeric vendor and device ID as well as the name, so there
is no guessing. **`-k`** prints **which kernel driver is actually bound** to the
device, which is the fact that matters.

```
03:00.0 Network controller [0280]: Qualcomm Atheros QCA9377 802.11ac
        Wireless Network Adapter [168c:0042] (rev 31)
        Subsystem: Dell Device [1028:1810]
        Kernel driver in use: ath10k_pci
```

`168c` is the Qualcomm Atheros vendor ID. Confirmed a second way:

```bash
ssh arrakis 'cat /sys/class/net/wlp3s0/device/uevent'
```
Linux exposes each device's identity as a file. **uevent** holds the facts the
kernel itself used to pick a driver. Result: `DRIVER=ath10k_pci`,
`PCI_ID=168C:0042`. Two independent sources, same answer.

**A trap worth knowing:**

```bash
ssh arrakis 'modinfo -F name iwlwifi'
```
printed `iwlwifi`. That looks like confirmation, but it is not. **modinfo** only
reports that a module **exists on disk**. Every Debian kernel ships `iwlwifi`
whether or not you own an Intel card. It says nothing about what is in the
machine.

**Rule learnt: `modinfo` tells you what is available. `lspci -k` tells you what
is present and bound. Use `lspci -k`.**

**Did the correction change any decision?** No. The decision was D4, that
bridging is impossible and NAT is required. That rested on a *measurement*, not
on the chip name:

```
$ iw phy phy0 info
    Supported interface modes:
         * IBSS
         * managed
```

No AP mode, no 4-address mode. True of this Atheros card, and it would have been
true of an Intel one too.

**The real lesson is about method, not Wi-Fi.** The chip name was stated from
memory and went unchallenged for several hours because nothing depended on it.
The measurement underneath happened to be sound. Next time it might not be.

**Rule: state a fact only with the command that produced it. If there is no
command, mark it as a guess.**


### Q11. If I add a hypervisor, does my kernel get replaced?

**No. Your kernel already is a hypervisor.** Measured 2026-11-08:

```
$ ls -l /dev/kvm
crw-rw----+ 1 root kvm 10, 232        <- exists right now
$ lsmod | grep ^kvm
kvm_intel  413696  0
kvm       1396736  1 kvm_intel        <- already loaded
$ grep -oE 'vmx' /proc/cpuinfo
vmx                                   <- the CPU supports it
```

**KVM** is the hypervisor built into Linux. It is in the running kernel, loaded,
and working. VMs can run today.

**So why does Proxmox replace the kernel?** Because Proxmox is not a hypervisor.
It is a management product wrapped *around* KVM: a web interface, clustering, a
storage manager. It ships its own patched kernel and insists on using it.

```
Proxmox = web UI + cluster tools + storage manager + KVM
                                                      ^
                                             already present
```

Replacing a working kernel buys the wrapper, not the virtualisation.

| | Kernel replaced? | What you get | RAM |
|---|---|---|---|
| libvirt + QEMU | **No** | VMs from the command line | about 50 MB |
| Proxmox | **Yes** | VMs plus a web UI and cluster features | about 700 MB |

The clustering features need more than one machine. arrakis is one machine.

**The real trade is not "VMs or no VMs". It is "command line or web UI".**

### Q12. If KVM is already built in, why install libvirt and QEMU?

Because KVM is one **part** of a virtual machine — the hard part, but only a
part. KVM gives a virtual processor and virtual memory. Nothing else.

It gives no disk, no network card, no screen, and no way to start or stop
anything.

```
What a VM needs:          Who provides it:

virtual CPU + memory  ->  KVM        <- already present
virtual disk          ->  QEMU       <- missing
virtual network card  ->  QEMU       <- missing
virtual screen        ->  QEMU       <- missing
start / stop / list   ->  libvirt    <- missing
```

**KVM** makes virtualisation possible.
**QEMU** pretends to be the rest of the computer: disk, network card, graphics.
**libvirt** remembers the settings, so a VM is described once and started by name.

Everyday comparison:

```
KVM      =  an engine
QEMU     =  wheels, seats, lights, steering
libvirt  =  the ignition key and the parking space
```

An engine alone is not a car. The engine is the part that is hard to build and
impossible to add afterwards. That is why having it already matters.

**Can QEMU be used without libvirt?** Yes, but every piece of virtual hardware
goes on the command line, every time:

```bash
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 \
  -drive file=windtrap.qcow2,if=virtio -netdev user,id=n0 \
  -device virtio-net,netdev=n0 -nographic
```

Now repeat that for three VMs, remember it after a reboot, and make them start
on boot. That is libvirt's job.

**QEMU cannot be skipped.** Without it there is no disk and no network card, so
nothing can boot.

```
KVM only              -> nothing runs
KVM + QEMU            -> VMs run; you retype everything forever
KVM + QEMU + libvirt  -> VMs run, and are remembered
```

### Q13. A happy accident: libvirt already does the NAT we need

Decision D4 said the VMs must use NAT, because this Wi-Fi card cannot be
bridged (see Q5).

libvirt's standard way of giving VMs network access **is** NAT. It creates a
software switch, runs a small DHCP server on it, and sets up the address
rewriting. That is exactly the design D4 forced on us, and it comes as the
default rather than as extra work.

So the constraint that looked like bad news costs almost nothing on this path.


### Q14. Why did the first VM fail, and how was it found? (the UEFI boot loop)

This is the most useful debugging story so far. Read the method, not just the fix.

**The symptom.** `virsh list` said `running`. But there was no DHCP lease, and
`ssh 10.10.10.11` gave `No route to host`.

**Step 1 — check the host side first, because it is cheaper to check.**

```bash
virsh dumpxml mentat | grep -A4 "<interface"   # MAC matches the network file?
ip -br addr show virbr-arrakis                 # bridge up with 10.10.10.1?
ip -br link show master virbr-arrakis          # is the VM's cable plugged in?
pgrep -a dnsmasq                               # is the DHCP server running?
```

All four were correct. The bridge was UP, `vnet0` was attached and `LOWER_UP`,
dnsmasq was running. **Conclusion: the host was fine, so the guest never asked
for an address.**

**Step 2 — one number gave the game away.**

```bash
virsh dominfo mentat
```

```
CPU time:  188.3s
```

188 seconds of CPU in about two minutes of life. An idle VM after boot uses
almost none. **It was spinning, not sitting.** Something inside it was looping.

**Step 3 — the wrong guess, written down on purpose.** The theory at this point
was that `package_update: true` in the cloud-config was making cloud-init retry
`apt` without a network. That was a guess with no evidence, and it was wrong.

**Step 4 — look at the machine instead of theorising.**

```bash
virsh console mentat
```
**console** attaches your terminal to the VM's serial port, the same way a
physical cable would. Escape with **Ctrl + ]**, never Ctrl+C, and never by
closing the terminal, or the console stays attached and blocks the next attempt.

The output was the answer:

```
  Booting `Debian GNU/Linux'
  Booting `Debian GNU/Linux'
  Booting `Debian GNU/Linux'
  Booting `Debian GNU/Linux'
```

That is GRUB's message printed immediately before it hands over to the kernel.
Repeated, with no kernel output between, it means: GRUB loads the kernel, the
kernel dies instantly, the machine resets, and it starts again. **A boot loop.**

**Step 5 — the log that said nothing, which was itself informative.**

```bash
sudo tail -40 /var/log/libvirt/qemu/mentat.log
```

This file holds the exact QEMU command line libvirt built, plus any QEMU errors.
There were **no errors**. QEMU had started cleanly. That ruled out the host and
the hypervisor, and pinned the fault inside the guest.

The same log carried the real clue, by **absence**: there was no `-bios` line and
no `pflash` drive, which means the VM was using the default **BIOS** firmware.

**Step 6 — the cause.** Debian's cloud image expects **UEFI** firmware.
`virt-install` defaults to **BIOS**. A UEFI-built image on BIOS firmware gives
exactly this loop.

```
image expects:  UEFI  ->  kernel boots
image got:      BIOS  ->  "Booting..." -> reset -> repeat
```

**Step 7 — the fix was one flag.**

```bash
virt-install ... --boot uefi ...
```

Then the console showed pages of kernel messages and a `mentat login:` prompt.
Boot took 41 seconds. The theory was confirmed by the fix working, which is the
only confirmation that counts.

**Two harmless messages seen on the good boot, recorded so they are not chased
later:**

```
error: prohibited by secure boot policy    GRUB tried to load an unsigned
                                           graphics module. Serial works. Ignore.
failed to load regulatory.db               A Wi-Fi regulations file. The VM has
                                           no Wi-Fi. Ignore.
```

**The method, which is the real lesson:**

```
1. check the cheap side first        (host: bridge, MAC, DHCP server)
2. find the number that is wrong     (188s of CPU)
3. write the guess down, then test it, and keep it if it was wrong
4. look at the machine, not the theory  (virsh console)
5. a silent log still tells you something: it moves the fault elsewhere
6. change ONE thing
```

### Q15. Why is the database VM called `windtrap`?

In Dune, a windtrap pulls moisture out of the desert air and stores it in a
sealed basin. That is what a database does: take in a scattered precious
resource and hold it safely. The metaphor is exact, not decorative.

```
arrakis    the laptop                         (the planet)
mentat     Kubernetes node                    (the thinker)
windtrap   PostgreSQL, Redis   10.10.10.12    (collects and stores)
sietch-1   second node, later  10.10.10.13    (a settlement)
```

It also beats `db` on a command line: `db` could mean anything, `windtrap`
could not. See decision D9.

### Q16. Can OpenTofu create the VMs, rather than doing it by hand?

**Yes.** Checked 2026-11-08 against the provider's own repository, not from
memory:

```
provider   dmacvicar/libvirt
version    v0.9.9, published 2026-08-30
archived   false        1900 stars, 50 open issues
registry   present in the OpenTofu registry
```

Its resources map one to one onto the commands already run by hand:

| Done by hand | OpenTofu resource |
|---|---|
| `virsh pool-define-as` | `libvirt_pool` |
| `virsh net-define` | `libvirt_network` |
| `cp` plus `qemu-img resize` | `libvirt_volume` |
| `cloud-localds` | `libvirt_cloudinit_disk` |
| `virt-install` | `libvirt_domain` |

From the provider's own documentation for `libvirt_cloudinit_disk`:

> "Generates a cloud-init configuration disk as an ISO image with the `cidata`
> volume label. This ISO can be uploaded to a libvirt volume and attached to a
> domain for cloud-init configuration."

That is precisely the seed ISO built by hand with `cloud-localds`.

**The argument against doing it now, recorded because it was overruled:** the
UEFI bug in Q14 took four attempts and was found by poking a live machine. A
tool between you and the error makes that slower. The usual order is: do it by
hand, learn where it breaks, then describe it.

**The argument for doing it now, which won:** learning OpenTofu is itself a goal
of this project, and `mentat` already proved the recipe works, so the unknowns
are smaller than they were an hour ago. See decision D10.

**Two real costs, accepted:**

1. `v0.9.9` is pre-1.0. The settings can change between releases, so the version
   must be pinned exactly.
2. OpenTofu keeps a **state file**: its record of what it believes exists. If a
   VM is also changed by hand with `virsh`, the two disagree, and the next
   `tofu apply` behaves confusingly. **Rule: a resource is managed by OpenTofu
   or by hand, never both.**


### Q17. What makes this project reproducible?

Four files, each with one job. Mixing them is what makes a project
unreproducible, so the split is deliberate.

| File | Job | Tense |
|---|---|---|
| `RUNBOOK.md` | Rebuild the machine from nothing | imperative: "run this" |
| `plan.md` | What is true now, what is next | present |
| `learning.md` | How we got here and why | past |
| `TODO.md` | Agreed work not yet done | future |

`RUNBOOK.md` carries one rule the others do not: **every command says where it
runs**, `[PC]` or `[arrakis]`. That is not decoration. Running a command in the
wrong place already caused a real failure (Q9), where `ssh arrakis '...'` was
typed while already logged into arrakis, so arrakis tried to SSH to itself.

It also records the traps, not just the happy path:

1. `--boot uefi` is mandatory, or the VM boot-loops in silence (Q14).
2. `grep -c 'ssh-ed25519' user-data` must print 2, because `$(cat missing-file)`
   fails silently into an empty string.
3. `dnsmasq-base`, never `dnsmasq`.
4. `usermod -aG`, never `-G`.
5. A pool and a network each need **define, start and autostart**. Skipping
   autostart gives VMs that will not come back after a reboot.
6. Verify the lid setting with `busctl`, not by reading the config file.

**A runbook that only lists the steps that worked is not reproducible.** The
traps are the content; the steps are the easy part.

### Q18. Why is the state file kept out of git?

OpenTofu writes a **state file**: its record of what it believes exists in the
real world. It is not source code. Two reasons it stays out of git:

1. It holds machine details, and can hold secrets that passed through a
   resource.
2. It is a record of reality, not of intent. Git tracks intent. Committing state
   invites two people to commit two different realities.

The entries added to `.gitignore`:

```
tofu/.terraform/           the downloaded provider, megabytes, re-fetchable
tofu/*.tfstate             the state itself
tofu/*.tfstate.*           its backups
tofu/terraform.tfvars      the inputs, which hold SSH public keys
crash.log                  written when the provider panics
```

`.terraform.lock.hcl` **is** committed. That is intent: it pins the exact
provider version and its checksums, so another machine gets the same provider.

---

## 3. Commands we ran, and what each one means

### Checking SSH and the key agent

```bash
echo "$SSH_AUTH_SOCK"
```
Prints where the ssh-agent listens. **ssh-agent** is a small program that holds
your unlocked private key in memory, so you type the passphrase once instead of
every time.

```bash
ssh-add -l
```
Lists the keys the agent currently holds. Result: one key, `sohail-omarchy`.

Our socket was `/run/user/1000/ssh-agent.socket`. That path means systemd
manages the agent, not the shell. That is the good setup: it survives closing a
terminal and survives a reboot.

### Checking the machine

```bash
ssh arrakis 'hostnamectl'
```
Prints the hostname, the operating system and the kernel version.
Result: Debian 13 (trixie), kernel 6.12.111.

```bash
ssh arrakis 'free -h'
```
Prints memory use. The column to read is **`available`**, not `free`. `free`
looks alarmingly small because Linux fills spare memory with a disk cache and
gives it back when a program needs it. Result: 9.0 GiB available.

```bash
ssh arrakis 'stat -fc %T /sys/fs/cgroup'
```
Prints which cgroup version the kernel uses. **cgroups** are the kernel feature
that limits how much CPU and memory a process may use. Result: `cgroup2fs`,
meaning version 2. Version 2 is required for the sandbox and for Kubernetes swap
support.

```bash
ssh arrakis 'ps -eo pcpu,pmem,rss,etime,comm --sort=-pcpu | head'
```
Lists processes, busiest first. `rss` is the real memory a process holds.
Result: four `clang++-22` at 100 percent each — the ClickHouse build.

```bash
ssh arrakis 'systemctl --user list-timers --all'
```
Lists scheduled jobs for your user account. A **timer** is systemd's version of
cron. **`--user`** matters: without it you see only system-wide timers, and this
build timer belongs to the user `muaddib`. That is why the first check missed
it. **`--all`** also shows timers with no next run.

```bash
ssh arrakis 'systemctl --user cat clickhouse-master-build.service'
```
Prints the full text of a unit file, with the path it came from. **cat** here is
systemd's own subcommand, not the shell `cat` — it finds the file for you and
shows any drop-ins too. This is how we learnt the build already yields CPU
(`Nice=19`, `CPUWeight=20`).

```bash
ssh arrakis 'lscpu | grep -E "^Model name|^CPU\(s\)|^Core|^Thread"'
```
Prints processor details. The important distinction: **cores** are real, and
**threads** are the operating system's view. arrakis has 4 cores and 8 threads.
Four heavy compiles fill the machine, not eight.

```bash
ssh arrakis 'df -h /'
```
Shows free disk space. **`-h`** means human-readable (GB instead of raw blocks).
Result: 456 GB total, 291 GB free. On 2026-10-31 it was 345 GB free, so build
artifacts are growing.

```bash
ssh arrakis 'uname -r'
```
Prints the running kernel version. It matters because installing Proxmox
**replaces** this kernel. Result: `6.12.111+deb13-amd64`.

```bash
ssh arrakis '[ -d /sys/firmware/efi ] && echo EFI || echo BIOS; bootctl is-installed'
```
Finds out how the machine boots. The directory `/sys/firmware/efi` exists only
on an EFI system. **bootctl** reports whether systemd-boot is the bootloader.
Result: EFI, but systemd-boot is **not** installed, so GRUB is in use. This
cleared one of the five Proxmox risks, because Proxmox is unsupported on
systemd-boot with Secure Boot.

```bash
ssh arrakis 'sensors | grep -iE "package|core 0"'
```
Reads the temperature sensors. Result: 52 C, against a 100 C limit.

```bash
ssh arrakis 'ss -tlnp'
```
Lists which programs are waiting for network connections. **ss** replaces the
old `netstat`. The flags: **`-t`** TCP only, **`-l`** listening only, **`-n`**
show numbers not names (faster, no DNS lookups), **`-p`** show the program.
Result: only port 22 on the real interface. Nothing is exposed.

```bash
ssh arrakis 'for s in docker kubectl k3s ansible; do command -v $s; done'
```
Checks whether a program is installed. **`command -v`** prints the path if the
program exists and prints nothing if it does not. It is preferred over `which`
because it is built into the shell and always present. Result: Docker and
Tailscale are installed; k3s, kubectl and Ansible are not.

```bash
ssh arrakis 'systemctl is-enabled docker; systemctl is-active docker'
```
Two different questions. **is-enabled** asks "will it start at boot?".
**is-active** asks "is it running right now?". A service can be one and not the
other.

```bash
ssh arrakis 'p=$(pgrep -x ninja); tr "\0" " " < /proc/$p/cmdline; readlink /proc/$p/cwd'
```
Finds out exactly what a running process is doing. **pgrep -x** finds the process
id by exact name. Linux exposes every process as files under `/proc/<id>/`:
`cmdline` is the command it was started with, and `cwd` is a link to its working
directory. `cmdline` separates arguments with a zero byte, so **`tr "\0" " "`**
swaps those for spaces to make it readable. Result: the build runs in
`~/Github/worktrees/latest-build/build_master` — the fact that matters for the
ccache problem.

### Checking the network

```bash
ssh arrakis 'ip -br addr'
```
Lists every network interface and its address. `-br` means brief, one line each.
Result: `wlp3s0` is the live Wi-Fi interface; `enp2s0` is the dead Ethernet one.

```bash
ssh arrakis 'ip route'
```
Shows where traffic goes. The line starting `default via` is the router that
handles everything not on the local network. Result: `192.168.1.1`.

```bash
ssh arrakis 'iw phy phy0 info'
```
Asks the Wi-Fi chip what it can do. `phy0` is the physical radio.
This is the command that proved bridging is impossible. See Q5.

```bash
ssh arrakis 'hostname --ip-address'
```
Prints the address the machine's own name resolves to. Result: `127.0.1.1`,
which is a loopback address — an address that means "myself". Proxmox refuses to
install with a loopback here. This is an open blocker.

```bash
ssh arrakis 'iw dev; iw wlp3s0 link'
```
**iw** is the tool for wireless interfaces. `iw dev` lists them; `iw <name> link`
shows the live connection. Result: SSID `Airtel_aksh_6013`, 5805 MHz, signal
-68 dBm. Signal is measured in dBm and is always negative; closer to zero is
better. -68 is usable but not strong.

```bash
ssh arrakis '/usr/sbin/sysctl net.ipv4.ip_forward'
```
Reads one kernel tuning value. **sysctl** reads and writes kernel settings.
`ip_forward` decides whether the machine will pass traffic between its network
interfaces — which is exactly what NAT needs. Result: already `1`, switched on
by Docker when it was installed.

Note: `sysctl` lives in `/usr/sbin`, which is not in the search path of a
non-login shell. That is why the first attempt failed with "command not found"
and the full path was needed.

```bash
ssh arrakis 'readlink -f /etc/resolv.conf; head -3 /etc/resolv.conf'
```
`/etc/resolv.conf` holds which server translates names into addresses.
`readlink -f` follows any symbolic link to the real file. Result: Tailscale
writes this file and warns that edits are overwritten. Proxmox also wants to own
it. This is an open conflict.

### Checking the compiler cache

```bash
ssh arrakis 'ccache -s'
```
Prints cache statistics. **ccache** stores the result of each compile, keyed by
the source and the flags, so an unchanged file is not compiled twice.
Result: 0.34 percent hits out of 46430 calls. That is broken. See plan.md
section 11.

```bash
ssh arrakis 'ccache -p'
```
Prints the full configuration and marks each value `(default)` or names the file
that set it. Result: only `max_size` is set; everything else is default.



### Looking things up from the PC (not on arrakis)

```bash
gh api repos/opentofu/opentofu/releases/latest --jq '.tag_name, .published_at'
```
Asks GitHub directly for a project's newest release. **gh** is GitHub's command
line tool; **api** sends a raw request; **`--jq`** filters the JSON reply to just
the fields wanted. This was used instead of a web search because a search
returned three conflicting version numbers and one page was AI-written.
Result: OpenTofu **v1.13.9**, published 2026-11-05.

**Rule learnt: for a version number, ask the project's own release API. Do not
trust a blog or a search summary.**

```bash
gh api repos/bpg/terraform-provider-proxmox/contents/docs/index.md \
  --jq '.content' | base64 -d
```
Reads a file out of a GitHub repository without cloning it. The API returns file
contents base64-encoded, so **`base64 -d`** decodes it back to text. This was
needed because the OpenTofu registry website builds its pages with JavaScript,
which a plain fetch cannot run — so the registry page came back empty and the
provider's own repository had to be read instead. Result: the provider requires
Proxmox VE 9.x and an existing API endpoint, which answered Q3.

```bash
readlink -f ~/.claude
```
Follows a symbolic link to the real file it points at. Result:
`~/Github/dotfiles/claude`. This confirmed that editing `~/.claude/CLAUDE.md`
and editing the dotfiles repository touch the same bytes — and that the
repository is the correct place to edit.


### Checking whether Wi-Fi would survive a kernel swap

```bash
ssh arrakis 'lspci -nnk | grep -iA3 network'
```
See Q10. Identifies the card and the bound driver: Qualcomm Atheros QCA9377 on
`ath10k_pci`.

```bash
ssh arrakis 'dpkg -l | grep -i firmware'
```
Lists installed firmware packages. **Firmware** is code that runs on the device
itself, not on the CPU. The kernel loads it into the card at startup. It ships in
separate packages because its licence is usually not free software.

Result: `firmware-atheros` is installed. This is the good news for the Proxmox
question — firmware lives in a **package**, not in the kernel. Replacing the
kernel does not remove it.

```bash
ssh arrakis 'grep -rhoE "non-free[a-z-]*" /etc/apt/sources.list /etc/apt/sources.list.d/'
```
Checks which Debian software sections are enabled. Result: `non-free-firmware`.
This matters because the Wi-Fi firmware comes from that section. If it were not
enabled, a firmware reinstall after the kernel swap would fail.

```bash
ssh arrakis 'pgrep -c clang++-22; systemctl --user is-active clickhouse-master-build.service'
```
**`pgrep -c`** counts matching processes instead of printing them. Used to check
whether a reboot would interrupt the nightly build. A count of 0 with the
service still `activating` means the build is between stages, not finished — so
a reboot would still interrupt it.


### Checking what virtualisation already exists

```bash
ssh arrakis 'ls -l /dev/kvm'
```
Checks for the KVM device file. Linux exposes the hypervisor as a file at
`/dev/kvm`. If it exists, the kernel can run virtual machines. The `+` at the
end of the permissions means an access control list grants extra users access.

```bash
ssh arrakis 'lsmod | grep "^kvm"'
```
**lsmod** lists the kernel modules currently loaded. A **module** is a driver
the kernel can load and unload while running. Result: `kvm` and `kvm_intel` are
both loaded. The `0` in the last column is the use count — nothing is using KVM
yet, but it is ready.

```bash
ssh arrakis 'grep -oE "vmx|svm" /proc/cpuinfo | sort -u'
```
Checks whether the processor itself supports virtualisation. **vmx** is Intel's
name for the feature; **svm** is AMD's. `/proc/cpuinfo` is the kernel's report
of the CPU. **`-o`** prints only the matching text, and **`sort -u`** removes
the duplicates from the eight threads. Result: `vmx`.

Without this, KVM cannot work at all, no matter what is installed.

```bash
ssh arrakis 'for b in qemu-system-x86_64 virsh virt-install; do command -v $b; done'
```
Checks for the missing pieces. All three printed nothing, meaning none is
installed.

```bash
ssh arrakis 'apt-cache policy qemu-system-x86 libvirt-daemon-system virtinst'
```
Asks apt what version is available and what is installed, **without installing
anything**. **apt-cache** reads the local package list only; it makes no
changes. This is the correct way to check a version before committing to an
install.

Result, on 2026-11-08, all `Installed: (none)`:

```
qemu-system-x86         1:10.0.13+ds-0+deb13u1
libvirt-daemon-system   11.3.0-3+deb13u3
libvirt-clients         11.3.0-3+deb13u3
virtinst                1:5.0.0-5+deb13u1
dnsmasq-base            2.91-1+deb13u2
ovmf                    2025.02-8+deb13u1
```


### Building the first VM

```bash
sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients \
  virtinst dnsmasq-base ovmf
```
Installs the virtualisation stack. **`dnsmasq-base`, not `dnsmasq`** — the plain
package runs a DNS server on the host and conflicts with libvirt. The `-base`
package is only the libraries libvirt drives itself. **`ovmf`** is the UEFI
firmware, which turned out to be essential (Q14).

```bash
sudo usermod -aG libvirt,kvm "$USER"
exec newgrp libvirt
```
**`-a`** means *append* to the user's groups. Without `-a` you **replace** every
group the user has and lock them out of other things. `newgrp` starts a shell
that has the new group, so you do not have to log out and back in.

```bash
virsh pool-define-as arrakis-images dir --target /var/lib/libvirt/images
virsh pool-start arrakis-images
virsh pool-autostart arrakis-images
```
A **pool** is a directory libvirt manages for disk images. `dir` is the simplest
kind: one file per virtual disk. The three steps are separate on purpose:
**define** writes the configuration, **start** activates it now, and
**autostart** makes it come back after a reboot. Forgetting the third is a
common cause of VMs that will not start after a restart.

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```
Without this, `virsh` manages **your own user's** VMs, which is a separate set
from the system's. Commands then appear to do nothing, or report that a VM does
not exist. Setting it once avoids typing `--connect qemu:///system` every time.

```bash
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
echo "1207e6e3...fee4b  debian-13-generic-amd64.qcow2" | sha512sum -c
```
A **cloud image** is Debian already installed, with no installer and no
password. It reads its settings on first boot instead, which is what makes it
scriptable. **`sha512sum -c`** checks the file against the checksum published by
Debian; it must print `OK`. The checksum was taken from Debian's own `SHA512SUMS`
file, not from memory.

```bash
ssh-keygen -t ed25519 -C "arrakis-to-vms" -N "" -f ~/.ssh/id_ed25519
```
arrakis had **no key of its own**. It is logged into from the PC, but it had
never needed to log into anything, so none existed. **`-N ""`** sets an empty
passphrase, which is correct for a key a machine uses unattended.

```bash
cat > user-data <<EOF
...
      - $(cat ~/.ssh/id_ed25519.pub)
      - $(grep -m1 'sohail-omarchy' ~/.ssh/authorized_keys)
EOF
grep -c 'ssh-ed25519' user-data        # MUST print 2
```
The cloud-init configuration. Two keys are embedded: arrakis's own, and the PC's
(pulled out of arrakis's `authorized_keys`, which is where it already lives).

**`$(cat missing-file)` fails silently into an empty string.** The first attempt
produced a config with no key at all, which would have made the VM impossible to
log into, since cloud images have no password. **Rule: after substituting
anything into a file, count the result before using it.** That is what the
`grep -c` line is for.

```bash
cloud-localds /tmp/mentat-seed.iso user-data meta-data
```
Builds the tiny ISO that carries the configuration. cloud-init inside the guest
looks for a disk labelled `cidata` and reads it on first boot.

```bash
sudo qemu-img resize /var/lib/libvirt/images/mentat.qcow2 20G
```
Raises the disk's **limit** to 20 GB. The file itself stays small and grows as it
is used, because qcow2 allocates on write. The base image is copied first, not
used directly, so it stays pristine for the next VM.

```bash
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/mentat.qcow2
```
QEMU runs as the user `libvirt-qemu`, not as you. Without this the VM fails with
an error that reads like a missing file rather than a permission problem.

```bash
virt-install --name mentat --memory 3072 --vcpus 2 --boot uefi \
  --disk ...,bus=virtio --disk ...seed.iso,device=cdrom \
  --network network=arrakis-nat,mac=52:54:00:10:10:11 \
  --os-variant debian13 --import --graphics none --noautoconsole
```
**`--import`** means "this disk already has an operating system; do not run an
installer". **`--graphics none`** gives a serial console instead of a virtual
screen, which is what makes `virsh console` work. **`--noautoconsole`** returns
your prompt instead of attaching immediately. **`--boot uefi`** is the flag that
fixed Q14. The **`mac=`** matches the pinned entry in the network file, which is
what guarantees the address 10.10.10.11.

### Measuring what a VM actually costs

```bash
free -m | head -2                               # on the host
ps -o rss=,comm= -C qemu-system-x86_64          # what QEMU really holds
```

Measured 2026-11-08 with one 3 GB VM running:

```
host available   8758 MB
QEMU process     1023 MB      <- not 3072
guest sees       2894 MB total, 2554 available
```

**The important finding: a VM costs what it has touched, not what it was
promised.** QEMU hands memory to the guest lazily. So three VMs of 3 GB each do
not cost 9 GB. This is what makes the plan affordable on an 11 GB laptop.

```bash
ssh muaddib@10.10.10.11 'ping -c1 -W3 1.1.1.1 && echo "NAT: works"'
```
Proves the NAT path end to end: guest, software switch, address rewriting, Wi-Fi,
internet. It also cleared a worry — Docker sets the kernel's FORWARD policy to
DROP, which is known to break libvirt NAT. It did not here.


### Making the work reproducible

```bash
pacman -Ss '^opentofu$'
```
Searches the Arch package repositories **without installing**. The `^...$`
anchors make it an exact name match instead of a substring search.

Result: `extra/opentofu 1.12.1-1`. Worth noting against the earlier finding that
upstream's newest release is **1.13.9** (2026-11-05). Both facts are true: Arch
packages 1.12.1, upstream has 1.13.9. The configuration requires only `>= 1.6`,
so 1.12.1 is fine.

**Rule: the newest upstream release and the version your distribution ships are
different questions. Check the one you will actually install.**

```bash
ssh arrakis 'ls /usr/share/OVMF/'
```
Confirms the UEFI firmware file exists, and its exact name, before writing that
path into a configuration file. Result: `OVMF_CODE_4M.fd` and
`OVMF_VARS_4M.fd`, plus `secboot` and `snakeoil` variants.

The plain `OVMF_CODE_4M.fd` is the right one here. The `secboot` variants enforce
Secure Boot, and `snakeoil` uses a publicly known test key, which is useful for
testing signature handling and useless for security.

```bash
ssh arrakis 'ls -d /var/lib/libvirt/qemu/nvram/'
```
Checks the directory for UEFI settings files. It did **not** exist. A UEFI
virtual machine keeps its own small settings store, the equivalent of the
battery-backed memory on a real motherboard, and libvirt writes it here. The
directory has to exist before the first UEFI VM is created through the provider.

```bash
command -v tofu
```
Result: not installed on the PC. Checked before writing instructions that assume
it, rather than after.

### Fixing the lid (decision D6)

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
       org.freedesktop.login1.Manager HandleLidSwitch
```
Asks the login manager, over the system message bus, what value it is using for
one setting **right now**. **busctl** is the tool for talking to D-Bus, the bus
that systemd services use to answer questions about themselves. This is more
trustworthy than reading a config file, because it shows the value in effect
after all defaults and overrides are applied.

Before the fix it printed `s "suspend"`. After the fix: `s "ignore"`.

```bash
cat /proc/acpi/button/lid/*/state
```
Asks the firmware whether the lid is open or shut right now. Result: `open`.
This explained why the machine had not yet slept, despite the bad setting.

```bash
cat /sys/power/state
```
Lists the sleep modes the kernel supports. Result: `freeze mem`. **`mem`** is
suspend-to-RAM, the real sleep. Its presence proved the lid setting would
actually have taken effect — the risk was not theoretical.

```bash
journalctl --no-pager -b -g "Suspending system|Lid closed"
```
Searches the system log. **`-b`** limits it to the current boot. **`-g`** greps
for a pattern. **`--no-pager`** stops it opening a pager that waits for a
keypress. Result: no entries, meaning the lid had never been closed this boot.

```bash
ls /etc/systemd/logind.conf.d/ /run/systemd/logind.conf.d/ /usr/lib/systemd/logind.conf.d/
```
Checks all three override locations. systemd reads drop-ins from `/etc`
(your edits), `/run` (temporary, lost on reboot) and `/usr/lib` (shipped by
packages). Result: none of the three existed, so nothing was overriding the
default.

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
```
Creates the override directory. **`-p`** means "make parent directories too, and
do not complain if it already exists".

```bash
sudo tee /etc/systemd/logind.conf.d/10-server-no-sleep.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
```
Writes the file. **`tee`** reads text and writes it to a file. It is used here
instead of `>` because `sudo command > file` applies sudo to the command but
*not* to the redirect, so the write still happens as your own user and fails on
a root-owned directory. `tee` runs under sudo itself, so the write succeeds.
**`>/dev/null`** throws away the copy `tee` also prints to the screen.
**`<<'EOF'`** is a here-document: everything until the line `EOF` is fed in as
text. The quotes around `'EOF'` stop the shell from substituting variables
inside.

The filename starts with `10-` because systemd reads drop-ins in alphabetical
order. A number prefix gives you room to add a `20-` file later that wins.

```bash
sudo systemctl reload systemd-logind
```
Tells logind to re-read its configuration without restarting. **reload** is
chosen over **restart** because restarting the login manager can disturb active
login sessions, including your SSH session.

---

## 4. Open blockers

| # | Blocker | Why it matters |
|---|---|---|
| ~~B1~~ | ~~Lid close suspends the machine~~ | **FIXED 2026-11-08.** Verified: `busctl` now returns `s "ignore"`. See D6. |
| ~~B2~~ | ~~`hostname --ip-address` returns `127.0.1.1`~~ | **Not a blocker any more.** It was a Proxmox requirement only. Still worth tidying one day. |
| ~~B3~~ | ~~Tailscale and Proxmox fight over `/etc/resolv.conf`~~ | **Not a blocker any more.** libvirt does not manage host DNS. |
| B4 | ccache hit rate is 0.34 percent | Every build recompiles everything |
| ~~B5~~ | ~~Proxmox decision not taken~~ | **CLOSED 2026-11-08 by D8.** libvirt instead. B2 and B3 were Proxmox-only and are also closed. |

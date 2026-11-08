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
| D14 | 2026-11-08 | Never `pacman -Sy <pkg>` on this machine. Use `omarchy-update` then `omarchy-pkg-install`. | Omarchy pins a mirror snapshot. Refreshing the catalogue without upgrading the system is a partial upgrade, which links new packages against old libraries. |
| D15 | 2026-11-08 | Any remote command using `sudo` gets `ssh -t` | Without a terminal `sudo` cannot prompt for a password and refuses outright. |
| D16 | 2026-11-08 | Every VM gets autostart, set at creation | `mentat` was missed and stayed off after a reboot while the pool and network returned. See Q22. |
| D17 | 2026-11-08 | arrakis must stay on mains power | D6 removed the suspend safety net, so an unplugged arrakis runs its battery to zero. See Q21. |
| D18 | 2026-11-08 | Read the generated **Schema** section of a provider's docs, never its Example | The provider's own example used `boot_devices = ["hd"]`, which its schema rejects. Open issue #1243 confirms the examples are stale. |
| D19 | 2026-11-08 | With a remote provider, ask of every path: which machine is this on? | `libvirt_cloudinit_disk` builds its ISO on the PC; QEMU on arrakis cannot read that path. The ISO must be uploaded as a volume. |
| D20 | 2026-11-08 | `mentat` stays by hand for now, but is the odd one out | Everything else is described in a file. `mentat` is the only VM that can drift, and it already did (Q22, autostart). Convert it by **import**, never by re-creating. |
| D21 | 2026-11-08 | Always state `driver.type` on a disk. Never rely on the provider's default. | It defaults to `raw`, so a qcow2 file is read as raw bytes and the guest finds no partition table. See Q25. |
| D22 | 2026-11-08 | Every VM gets console logging to a file | `virsh console` needs a terminal, so a script cannot read a failed boot. The log file made Q25 diagnosable at all. |
| D23 | 2026-11-08 | When one thing works and a near-identical thing does not, **diff them before forming a theory** | An hour went into wrong theories while a working `mentat` sat beside the broken `windtrap`. The XML diff took thirty seconds. |
| D24 | 2026-11-08 | Name the third VM `sietch`, with no number. Three VMs is the plan and the ceiling. | 4 cores and 11 GB, with ClickHouse taking all four cores nightly. A numbered name implied a fleet that this hardware cannot run. |
| D25 | 2026-11-08 | Edit a live libvirt network with `net-update --live --config`, never `net-destroy` | Destroying the network disconnects every running VM. `net-update` changes one entry in place. |
| D26 | 2026-11-08 | Do the swap/zram/KSM proof of concept to learn it and to absorb spikes, **not** to run more VMs | Measured: three VMs hold 2628 MB of 11690, with 8466 MB available. RAM is not the binding limit; CPU is. Swap buys memory, never a core. |
| D27 | 2026-11-08 | Park the zram and KSM proof of concept. Kubernetes first. | RAM is not the binding limit: three VMs hold 2628 MB of 11690. The proof of concept teaches something but unblocks nothing. TODO T9 stays open. |
| D28 | 2026-11-08 | **Option B: all three VMs join the cluster.** windtrap becomes an agent and PostgreSQL runs as a pod. | The data is disposable test data, so protecting it was a weak argument and was dropped. B adds about 1.5 GB of workload room and teaches StatefulSets and PersistentVolumes, which are mainstream practice - CloudNativePG is a CNCF Landscape project. Overrules the earlier recommendation of A. See Q30, Q32. |
| D29 | 2026-11-08 | Use the default SQLite datastore. No datastore flags. | Documented default, and the one-server shape makes it valid: "SQLite cannot be used on clusters with multiple servers." Agents hold no datastore. See Q34. |
| D30 | 2026-11-08 | Install the server with `--disable=traefik,servicelb`. Keep coredns, local-storage and metrics-server. | Traefik routes outside HTTP traffic and nothing is exposed yet. ServiceLB assigns external addresses, which is meaningless behind NAT. `local-storage` is **required** by D28, because a PostgreSQL pod needs disk. See Q35. |
| D32 | 2026-11-08 | No fourth VM. Redis and PostgreSQL both run as pods on `windtrap`. | Redis needs about 50 MB; a whole VM for that is waste and adds CPU contention on 4 real cores. One node runs many pods. See Q38. |
| D33 | 2026-11-08 | `quarantine/server-plan.md` is **no longer authoritative** | The user stated it is being changed as the project goes. Treat it as history. Current decisions live in this file; current state in plan.md. |
| D35 | 2026-11-08 | Use `install.yaml` (non-HA), pinned to `v3.5.7`, not `stable` and not `v3.6.1` | HA runs multiple replicas this hardware cannot afford; Core has no UI. v3.6.0 was patched within a day of release, so v3.6 is still settling. See Q45. |
| D38 | 2026-11-08 | **Option B chosen:** NodePort 30080 plus Tailscale inside `mentat`. Not public. | Removes the SSH tunnel for about 30 MB. Keeps everything off the internet, and makes later node-sharing with one person possible. See Q43, Q47. |
| D39 | 2026-11-08 | Pin `nodePort: 30080` explicitly, never let Kubernetes choose | A random port in 30000-32767 changes if the Service is recreated, silently breaking saved commands and bookmarks. See Q46. |
| D41 | 2026-11-08 | **OpenBao on its own VM (`shieldwall`), not Sealed Secrets in the cluster.** | Sealed Secrets is a Kubernetes controller and cannot run outside a cluster. OpenBao outside the cluster breaks the circular dependency where rebuilding a dead cluster needs secrets stored in it. See Q48. |
| D42 | 2026-11-08 | Remove the ClickHouse build entirely: timer disabled, 126 GB deleted. | The user's instruction, reaffirmed after the loss of 7 uncommitted files on a PR branch was spelled out. A patch was saved to `~/clickhouse-wip-20261108.patch` first. See Q49. |
| D43 | 2026-11-08 | **D24 is overturned: four VMs, not three.** | D24 capped it at three because of CPU contention from the nightly build. That build is gone; load is now 0.50. `shieldwall` takes 1 vCPU. See Q50. |
| D45 | 2026-11-08 | Capture secrets with `-format=json` into a file. **Never read a credential off a terminal.** | A root token pasted from two nested `ssh -t` sessions was line-wrapped and silently corrupted, giving `permission denied`. See Q52. |
| D47 | 2026-11-08 | PostgreSQL runs as a StatefulSet **pinned to `windtrap`** with `nodeSelector` | `local-path` storage lives on one node's disk, so the pod is pinned either way. Choosing makes it deliberate. If windtrap is down, PostgreSQL is down. See Q53. |
| D48 | 2026-11-08 | OpenTofu manages Kubernetes resources **for now**; Argo CD manages nothing yet | Two managers of one resource fight. Moving PostgreSQL to Argo CD later needs `tofu state rm`, never `destroy`. See Q55. |
| D49 | 2026-11-08 | OpenBao is **not** managed by OpenTofu. No provider exists; the `bao` CLI is used. | `hashicorp/vault` would probably work against OpenBao's API, but neither project documents it. An undocumented assumption at the root of trust is wrong. See Q55. |
| D50 | 2026-11-08 | Separate OpenTofu state: `tofu/` for VMs, `tofu/k8s/` for cluster contents | Different lifetimes. A manifest mistake must not be able to destroy a VM. |
| D52 | 2026-11-08 | Redis runs as a StatefulSet with persistence, not a Deployment | Redis Streams are the job queue. Losing the queue loses jobs, which is not the same as a cache refilling. 1 GiB of 410 GiB. See Q56. |
| D53 | 2026-11-08 | **Redpanda is not deployed.** Its documented minimum is 3 brokers x 2.22 GiB = 6.7 GiB. Each node has 1.4 GB free; the host has 2.3 GB. | This re-reaches the original plan's conclusion from measured numbers. Redis Streams already provide consumer groups, acknowledgements and replay. Not a configuration problem - a hardware one. See Q57. |
| D55 | 2026-11-08 | Observability runs as pods on `sietch`, not in a new VM | A VM costs 200-250 MB just to exist; a pod costs nothing extra, and the host has 2343 MB free. It also needs to be inside the cluster to discover scrape targets. See Q58. |
| D56 | 2026-11-08 | **VictoriaMetrics, not Prometheus.** Single-node, which scrapes and stores in one pod. | It accepts Prometheus scrape configs and PromQL, so the knowledge transfers, at lower memory. Its docs state vmagent is unnecessary for single-node. See Q59. |
| D57 | 2026-11-08 | Always set an explicit in-process memory cap (`-memory.allowedBytes`) for a containerised service | A process in a container sees the **node's** memory, not its own limit, and sizes caches from that. The limit is enforced by the kernel killing it. See Q59. |
| D59 | 2026-11-08 | `count(up)` is the standard health check for the metrics stack | `up` is written per scrape target, 1 or 0. If it equals the target count, discovery, RBAC, scraping, storage and querying all work. One query covers the whole chain. |
| D61 | 2026-11-08 | Import an existing resource with an `import` **block** plus `-generate-config-out`, never a hand-written config | A hand-written config omits attributes, and OpenTofu removes whatever is omitted. The hand-written attempt scheduled the guest agent, clock timers and balloon for deletion from a running control plane. See Q62. |
| D62 | 2026-11-08 | **Read the plan's diff, not its summary line.** "0 to destroy" does not mean safe. | The dangerous plan said "will be updated in-place, 0 to destroy". The update was the removal of six devices. |
| D63 | 2026-11-08 | `mentat.tf` keeps Secure Boot firmware; the other VMs keep plain OVMF. Not normalised. | Changing a running machine's firmware is not cosmetic. Consistency is not worth rebooting the control plane. |
| D60 | 2026-11-08 | Empty output from `kubectl exec` means a missing tool, not a broken service | The VictoriaMetrics image has only busybox `wget`, which failed silently. Querying from the Grafana pod, which has real `curl`, worked. Check the image first. |
| D58 | 2026-11-08 | Grafana datasources are **provisioned from files**, never clicked in the UI | A clicked datasource lives only in Grafana's SQLite and vanishes when the pod is recreated. Anything configured by clicking is not reproducible. |
| D54 | 2026-11-08 | **D26 is overturned: RAM is now the binding limit.** TODO T9 (zram, KSM) is no longer optional. | D26 parked it because three VMs held 2628 MB of 11690. There are now four VMs, a cluster and two databases: 8704 MB allocated, 2298 MB free on the host. |
| D51 | 2026-11-08 | Pin container images to a full version, never `latest` or a major-only tag | `postgres:latest` would change major version on a restart, and PostgreSQL will not read a newer major's data directory. A data-loss bug inside a convenience. |
| D46 | 2026-11-08 | Secrets may be passed by command substitution on the remote host, never printed into the transcript | `$(jq -r .root_token file)` is evaluated on shieldwall, so the value never enters the agent's context. Pasting a token into chat is refused. |
| D44 | 2026-11-08 | Keep TLS enabled on OpenBao, unlike Argo CD (D40) | Argo CD is reached through an encrypted tunnel. OpenBao will be reached across the VM network by the cluster, which is not tunnelled. |
| D40 | 2026-11-08 | `server.insecure: true` is justified **only while access is tunnelled** | Tailscale and SSH both encrypt the transport. If Argo CD is ever exposed directly, TLS must come back. The condition is the justification. |
| D36 | 2026-11-08 | **Never put Argo CD behind Tailscale Funnel.** | Funnel is open to the whole internet, and the standard install has cluster-admin behind one password. Share the machine over Tailscale, or give an SSH key, instead. See Q44. |
| D37 | 2026-11-08 | Access = network layer **plus** identity layer. Another person gets a read-only Argo CD user, never the `admin` account. | Reaching the UI and being allowed to change the cluster are different problems. Only the first is usually considered. See Q44. |
| D34 | 2026-11-08 | Never pipe a remote installer into a shell. Download, then run with `< /dev/null`, and use `ssh -n`. | `curl \| sh` through a nested SSH installed nothing and printed nothing: `sh` and `ssh` both wanted stdin. See Q39. |
| D31 | 2026-11-08 | No high availability. One server. | HA needs three servers and embedded etcd. This hardware cannot afford it. If `mentat` stops, running pods continue but nothing can be scheduled or changed. |
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
   VM sietch 10.10.10.13 --+   (software   (rewrite  192.168.1.21
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
sietch   second node, later  10.10.10.13    (a settlement)
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


### Q19. Why did `yay -S opentofu` fail with a 404?

Three separate failures happened in one paste. Each has its own cause.

**Failure 1: the package download returned 404.**

```
opentofu-1.12.1-1-x86_64.pkg.tar.zst failed to download
error: failed retrieving file ... from stable-mirror.omarchy.org :
       The requested URL returned error: 404
```

The cause is a **stale package database**, not a broken mirror.

```bash
ls -l --time-style=+%F_%H:%M /var/lib/pacman/sync/extra.db
```
**pacman** keeps a local copy of each repository's index at
`/var/lib/pacman/sync/`. Every `pacman -S` looks there first to decide which
file to fetch. Result: the file was last written **2026-09-08** — two months
old.

```bash
pacman -Si opentofu | grep -E '^(Version|Repository)'
```
**`-Si`** shows what the **local database** believes about a package in a
repository, without touching the network. Result: `extra`, version `1.12.1-1`.

```bash
xh --print=hb HEAD "https://stable-mirror.omarchy.org/extra/os/x86_64/opentofu-1.12.1-1-x86_64.pkg.tar.zst"
```
Asks the mirror for that exact file, with **HEAD** so only the headers come back
and no 24 MB download starts. Result: `HTTP/2.0 404 Not Found`.

```bash
xh --print=b GET "https://archlinux.org/packages/search/json/?name=opentofu" | jq -r '.results[] | "\(.repo) \(.pkgver)-\(.pkgrel)"'
```
Asks Arch's own package API what version is current. Result: `extra 1.13.2-1`
and `extra-testing 1.13.9-1`.

**So the picture is:**

```
local db (September)  --asks for-->  opentofu-1.12.1-1
mirror   (November)   --has------>   opentofu-1.13.2-1
                                      404
```

Omarchy's `stable-mirror` is a **pinned snapshot** that is moved forward from
time to time. The snapshot advanced; the old file was removed; the stale local
database still asks for it. The URL was built correctly. The file is simply gone.

Everyday comparison: an old printed catalogue with last season's part numbers.
You phone the warehouse and quote a number that no longer exists. The phone line
works. The number does not.

**The wrong fix, and why it is wrong.** `sudo pacman -Sy opentofu` refreshes the
database and then installs one package. The rest of the system stays at the
September snapshot, so the new package links against two-month-old libraries.
Arch calls this a **partial upgrade**, and it breaks systems. Never do it.

**The right fix on Omarchy**, which moves the whole snapshot:

```bash
omarchy-update
omarchy-pkg-install opentofu
```

Found with:
```bash
ls /usr/share/omarchy/bin/ | grep -i omarchy
```

**The alternative that avoids a system upgrade:** OpenTofu publishes a static
binary, which is one file with no dependencies, so no package manager is
involved.

```bash
gh api repos/opentofu/opentofu/releases/latest --jq '.tag_name'   # v1.13.9
cd /tmp
xh -d https://github.com/opentofu/opentofu/releases/download/v1.13.9/tofu_1.13.9_linux_amd64.zip
unzip -o tofu_1.13.9_linux_amd64.zip tofu
mkdir -p ~/.local/bin && mv tofu ~/.local/bin/ && chmod +x ~/.local/bin/tofu
```

That gives 1.13.9, newer than either Arch repository. The trade: nothing updates
it for you later.

**Failure 2: `sudo` over SSH had nowhere to ask for a password.**

```
ssh arrakis 'sudo mkdir -p /var/lib/libvirt/qemu/nvram'
sudo: a terminal is required to read the password; either use the -S option
      to read from standard input or configure an askpass helper
```

`ssh host 'command'` runs the command with **no terminal attached**, because no
interactive shell was requested. `sudo` needs a terminal to turn off echo while
you type a password. With none, it refuses rather than show the password.

```
ssh host 'cmd'      ->  no terminal  ->  sudo cannot prompt
ssh -t host 'cmd'   ->  terminal     ->  sudo prompts normally
```

**`-t`** forces a terminal to be allocated. The fix:

```bash
ssh -t arrakis 'sudo mkdir -p /var/lib/libvirt/qemu/nvram'
```

**Rule: any remote command that uses `sudo` needs `ssh -t`.**

**Failure 3: `zsh: command not found: tofu`.** A consequence of failure 1, not a
separate problem. The install never completed, so the binary does not exist.

**The method note worth keeping:** three error messages arrived together and
looked like one tangled problem. They were independent. Reading them from the
top, one at a time, and testing each claim with its own command, separated them
in a few minutes. A 404 is a claim about a specific URL, so ask that URL with
`HEAD`. A stale database is a claim about a file's date, so look at the date.

### Q20. Why does an old package database break an install at all?

Because the database is a **catalogue**, not the goods.

```
pacman -S opentofu
     |
     v
read /var/lib/pacman/sync/extra.db        <- the local catalogue
     |
     +-- find the entry: opentofu 1.12.1-1
     |
     v
build the URL from that exact version
  https://<mirror>/extra/os/x86_64/opentofu-1.12.1-1-x86_64.pkg.tar.zst
     |
     v
download it
```

The version number is baked into the **file name**. So the catalogue does not
merely describe the package; it decides which file name is requested. An old
catalogue therefore requests a file name that no longer exists on the server.

This is why a repository mirror keeps only the current version of each package
by default. Old files are deleted when a new snapshot is published.

It also explains why `pacman -Sy` on its own is dangerous. It replaces the
catalogue but installs nothing, so the catalogue and the installed system then
disagree. The next single-package install pulls one new package into an old
system.


### Q21. How was it found that arrakis had run its own battery flat?

Two steps, each answering a different question. This is the method, not a lucky
guess.

**Step 1 — was the network broken, or the machine?**

```bash
tailscale status | grep arrakis
```
```
100.114.18.44  arrakis  ...  offline, last seen 8h ago
```

**"last seen" is the key phrase.** Tailscale records when each machine last
spoke to the coordination service. A broken network would leave arrakis running
and reconnecting. "Last seen 8h ago" means it **stopped talking**, and says when.

```bash
ping -c2 -W3 100.114.18.44
```
100 percent packet loss. Confirms it, independently of Tailscale's own report.

**Step 2 — after the restart, read the battery.**

```bash
cat /sys/class/power_supply/BAT0/status      # Charging
cat /sys/class/power_supply/BAT0/capacity    # 2
```

**2 percent.** That is the proof.

Linux exposes hardware as files. A battery is a directory under
`/sys/class/power_supply/`, and `capacity` holds the percentage. No tool is
needed; `cat` is enough.

**The reasoning:**

```
2% and charging  ->  it was at about 0% when powered on
                 ->  so it ran until the battery was empty
                 ->  it did NOT suspend, and was NOT shut down cleanly
```

A machine that slept, or that was shut down properly, keeps its charge. One that
died from empty comes back near zero.

Everyday comparison: a car on the hard shoulder with the fuel gauge at empty.
You do not need to have watched it run out.

**Why this was more than a guess: the evidence matched a change we had made.**
Decision D6 set `HandleLidSwitch=ignore`. Before that, a closed lid meant sleep,
which preserves the battery. After it, the machine keeps working. So an unplugged
arrakis was always going to drain. Cause and evidence agreed.

**The consequence, which D6 did not follow through on:**

```
before D6:  lid closed  ->  suspends      ->  battery preserved
after D6:   lid closed  ->  keeps running ->  battery drains to zero
```

A machine that never sleeps must be on mains power. That is blocker B7.

### Q22. Why did mentat not come back after the reboot?

**Because autostart was never set on it. That was a mistake in the build
recipe, not a fault of the machine.**

```bash
virsh dominfo mentat | grep -i autostart
```
```
Autostart:  disable
```

The network and the storage pool both came back, because `net-autostart` and
`pool-autostart` were run for them. The VM was missed.

```
pool     autostart yes   -> came back   ✓
network  autostart yes   -> came back   ✓
mentat   autostart no    -> stayed off  ✗
```

The `virt-install` command in Q14 has no `--autostart` flag. Added afterwards:

```bash
virsh autostart mentat
virsh start mentat
```
**autostart** marks it to start with the host. It does **not** start it now, so
`start` is a separate command. Verified: `Autostart: enable`, VM running, lease
10.10.10.11, reachable.

`tofu/windtrap.tf` already carries `autostart = true`, so the OpenTofu-built VM
would not have had this problem. Only the by-hand VM did. **A small argument in
favour of describing machines in a file rather than typing them: the file is a
checklist you cannot forget to read.**

`RUNBOOK.md` step 8 has been corrected to include `--autostart`.


### Q23. What went wrong writing the OpenTofu configuration, and what did each error teach?

**The first draft was wrong, and it was wrong for one reason: it was written
from convention instead of from the provider's documentation.** `tofu plan`
rejected it with ten errors at once.

This breaks the project's own rule — read the real source of truth first. It is
recorded here in full because the errors were all instructive.

**Why it was so wrong.** Version 0.9.9 of the provider was rewritten to follow
libvirt's own domain XML schema. The old style used **blocks**:

```hcl
disk { volume_id = ... }          # old, 0.7.x and 0.8.x
network_interface { ... }
console { ... }
```

The new style uses **attributes with `=`**, nested to mirror the XML:

```hcl
devices = {
  disks      = [{ source = { file = { file = "..." } }, target = { dev = "vda", bus = "virtio" } }]
  interfaces = [{ model = { type = "virtio" }, mac = { address = "..." } }]
  consoles   = [{ target = { type = "serial", port = 0 } }]
}
```

Every old-style block produced `Blocks of type "disk" are not expected here`.

**Then six more errors, one at a time. Each one is a real lesson.**

**Error 1 — the provider's own example is wrong.**

```
Inappropriate value for attribute "os": attribute "boot_devices":
element 0: object required, but have string.
```

The documentation's example says `boot_devices = ["hd"]`. The schema in the same
file says each element needs a `dev` field. The correct form is
`boot_devices = [{ dev = "hd" }]`.

There is an open issue about exactly this: **#1243, "Examples don't reflect
updated schema"**, found with:

```bash
gh api -X GET search/issues -f q='repo:dmacvicar/terraform-provider-libvirt readonly loader'
```

**Rule: read the Schema section, not the Example. The example may be stale; the
schema is generated from the code.**

**Error 2 — a field named like a boolean that is a string.**

```
XML error: Invalid value for attribute 'readonly' in element 'loader': 'true'.
```

`loader_readonly = true` was written. The schema says:

```
- `loader_readonly` (String) Configures whether the loader is mounted readonly or not.
```

**String, not Boolean.** HCL stringified `true` to `"true"`, but libvirt's XML
wants `yes` or `no`. The fix: `loader_readonly = "yes"`.

**Rule: check the declared type, even when the name reads like a boolean.**

**Error 3 — UEFI needs ACPI, and nothing adds it for you.**

```
unsupported configuration: UEFI requires ACPI on this architecture
```

`virt-install` adds ACPI and APIC silently. This provider does not. Added:

```hcl
features = {
  acpi = true
  apic = {}
}
```

**This is the cost of a lower-level tool.** `virt-install` is opinionated and
fills in sensible defaults. The provider mirrors the XML, so anything libvirt
requires must be stated.

**Error 4 — the local/remote split, which is the most important one.**

```
Cannot access storage file
'/tmp/terraform-provider-libvirt-cloudinit/cloudinit-be84044fbbac8260.iso':
No such file or directory
```

`libvirt_cloudinit_disk` builds the ISO **on the machine running tofu** — the
PC. Its `path` is a local temporary file. The VM runs on **arrakis**, which
cannot see it.

```
PC                                    arrakis
  libvirt_cloudinit_disk              QEMU
  writes /tmp/...iso    ------X----->  tries to open /tmp/...iso
                        no such file
```

The fix is in the documentation's own example, and was skipped the first time:
upload the ISO into the pool as a volume, then point the VM at **that**.

```hcl
resource "libvirt_volume" "windtrap_seed" {
  name   = "windtrap-seed.iso"
  pool   = var.image_pool
  create = { content = { url = libvirt_cloudinit_disk.windtrap.path } }
}
```

`create.content.url` accepts a local path as well as an http URL. It is the
bridge between "built on the PC" and "readable by QEMU on arrakis".

**Rule: with a remote provider, ask of every path: which machine is this on?**

**Error 5 — the provider corrected my format and then called it a bug.**

```
Provider produced inconsistent result after apply
.target.format.type: was cty.StringVal("raw"), but now cty.StringVal("iso")
```

`raw` was declared. The provider inspected the uploaded file, saw an ISO, and
reported `iso` back. OpenTofu compares what was asked for against what the
provider returned, and a mismatch is treated as a provider bug. Declaring
`format = { type = "iso" }` makes them agree.

**Error 6 — a half-created resource left an orphan behind.**

```
operation failed: domain 'windtrap' already exists with uuid 794d1fc4-...
```

An earlier attempt **defined** the domain in libvirt and then failed to start
it. OpenTofu saw the failure and did not record the resource in its state, but
libvirt kept the definition. State and reality disagreed.

Cleaned by hand on arrakis:

```bash
virsh undefine windtrap --nvram
```
**`--nvram`** also removes the UEFI settings file, which would otherwise be left
behind and reused.

**This is decision D11 in action, from the other direction.** A failed apply can
leave reality ahead of state. When that happens, the by-hand cleanup is correct
and necessary — but it must be the exception, done deliberately, not a habit.

**The result after six fixes:**

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
windtrap_disk_path = "/var/lib/libvirt/images/windtrap.qcow2"
```

### Q24. Was OpenTofu worth it for this VM?

Honest answer, now that it is done: **not for the first VM. Yes for the next
one.**

The by-hand `mentat` took four attempts, all of them about one thing: UEFI.
`windtrap` took six attempts, all of them about the provider's schema — and the
UEFI lesson from `mentat` transferred straight across and cost nothing.

```
mentat    4 attempts, learning libvirt
windtrap  6 attempts, learning the provider
sietch  expected: about 10 lines, no new attempts
```

**What was actually gained:**

1. `sietch` is now a copy of one file with three values changed.
2. `tofu plan` shows what will change before it changes. The by-hand path has no
   equivalent, and `Plan: 3 to add, 0 to change, 0 to destroy` proved it would
   not touch `mentat`, the pool or the network.
3. The configuration **is** the documentation. Every trap found above is a
   comment next to the line that fixes it.
4. `autostart = true` was in the file from the start. The by-hand `mentat`
   missed it and stayed off after a reboot (Q22). **A file is a checklist you
   cannot forget to read.**

**What it cost:** six rounds of schema archaeology, and a provider that is
pre-1.0 and whose examples do not match its own schema.

The earlier advice — do it by hand first, then describe it — was not wrong. But
the better framing is: **do the first one by hand to learn the domain, then
describe everything, including the first one.** `mentat` is still by hand and is
now the odd one out.


### Q25. windtrap booted into a UEFI shell. Why, and what was the method failure?

**The fix was one line. Finding it took an hour, and the hour was wasted for a
reason worth recording.**

**The symptom.** `virsh list` said `running`. No DHCP lease. Unreachable. CPU
time 9.5 seconds and barely rising — so it was **idle, not looping**. That alone
distinguished it from Q14's boot loop, where CPU time hit 188 seconds.

**Getting the evidence.** `virsh console` needs a controlling terminal, which a
script does not have:

```
error: Cannot run interactive console without a controlling TTY
```

So console logging was added to the domain instead, which the provider supports:

```hcl
consoles = [
  {
    target = { type = "serial", port = 0 }
    log    = { file = "/var/log/libvirt/qemu/windtrap-console.log", append = "on" }
  },
]
```

**That change is worth keeping forever.** A failed boot now leaves a readable
file instead of needing a human at a prompt.

The log said:

```
BdsDxe: failed to load Boot0001 "UEFI Misc Device" from
        PciRoot(0x0)/Pci(0x1,0x2)/Pci(0x0,0x0): Not Found
BdsDxe: starting Boot0002 "EFI Internal Shell"
UEFI Interactive Shell v2.2
Mapping table
     BLK0: Alias(s):
          PciRoot(0x0)/Pci(0x1,0x2)/Pci(0x0,0x0)
Shell>
```

**The key detail is what is missing.** UEFI lists `BLK0` — a block device — but
gives it **no `FS0:` alias**. A disk with a readable EFI System Partition always
gets an `FS:` alias. So UEFI could see the disk and could not find a filesystem
on it.

**Three theories, all wrong, all tested.**

1. *The backing store did not attach.* Tested with
   `virsh vol-dumpxml windtrap.qcow2 --pool arrakis-images`. The `<backingStore>`
   element was present and correct. **Wrong.**
2. *QEMU cannot read the root-owned base image; AppArmor or file permissions.*
   Tested with `qemu-img info -U --backing-chain`. Both layers readable, chain
   intact, `corrupt: false`. **Wrong.**
3. *The GPT backup header is missing because the overlay is 20 GiB over a 3 GiB
   base, and EDK2 rejects the partition table.* Plausible, but `mentat` has the
   identical mismatch — its own boot log says
   `GPT:Primary header thinks Alt. header is not at the end of the disk` — and
   it boots. **Wrong.**

**What actually found it: diffing the broken machine against the working one.**

```bash
virsh dumpxml mentat   | sed "s/mentat/VMNAME/g"   > /tmp/m.xml
virsh dumpxml windtrap | sed "s/windtrap/VMNAME/g" > /tmp/w.xml
diff /tmp/m.xml /tmp/w.xml
```

The `sed` normalises the names so only real differences appear. One line
mattered:

```
<       <driver name='qemu' type='qcow2'/>     mentat   (works)
>       <driver name='qemu' type='raw'/>       windtrap (broken)
```

**The cause.** `devices.disks[].driver` was never set, and the provider defaults
`type` to `raw`. So QEMU opened a qcow2 file and read it as raw bytes.

A qcow2 file begins with its own header and metadata. Read raw, the guest sees
that metadata at sector 0, where the GPT partition table should be.

```
what the guest should see          what it saw
+--------------------------+       +--------------------------+
| GPT partition table      |       | qcow2 magic + header     |
| ESP (FAT, bootloader)    |       | L1 table, refcounts      |
| root filesystem          |       | ...compressed clusters   |
+--------------------------+       +--------------------------+
   UEFI: FS0: found                   UEFI: BLK0, no filesystem
```

Everyday comparison: handing someone a sealed envelope and asking them to read
the letter. They read the envelope. The letter is in there, but they are looking
at the wrong layer.

**The fix:**

```hcl
driver = { name = "qemu", type = "qcow2" }
```

And on the cdrom, `type = "raw"`, because an ISO really is raw.

**Verified:**

```
hostname  windtrap
address   10.10.10.12      (the pinned MAC worked)
NAT       works
disk      /dev/vda1  20G  952M used  5%
```

**The method failure, which is the real lesson.** There was a working machine
sitting next to the broken one, built from the same base image, on the same
host, five hours earlier. **Comparing them should have been the first move. It
was the last.** An hour went into theorising about permissions, AppArmor, GPT
headers and Secure Boot; the diff took thirty seconds.

**Rule: when one thing works and a near-identical thing does not, diff them
before forming any theory. Normalise the names first so the diff is readable.**

This also explains why `virt-install` had no such problem: it inspects the image
and sets the driver type itself. The provider mirrors libvirt's XML and assumes
nothing. **A lower-level tool does not guess for you — including about things you
did not know were guesses.**

### Q26. What did two VMs actually cost?

Measured 2026-11-08 with both running:

```
host available        8941 MB of 11690
mentat  qemu process  1265 MB   (3072 MB allocated)
windtrap qemu process  834 MB   (2048 MB allocated)
```

**Promised 5120 MB. Holding 2099 MB.** About 41 percent.

This confirms the finding from one VM (Q14 commands section): QEMU hands memory
to a guest lazily, so a VM costs what it has touched, not what it was promised.

```
allocated   mentat 3072 + windtrap 2048 = 5120 MB
actual      mentat 1265 + windtrap  834 = 2099 MB
```

`sietch` is therefore affordable. The RAM budget in
`quarantine/server-plan.md` section 9 is pessimistic, because it adds up
allocations rather than measuring.

The overlay disk also worked as intended: `windtrap.qcow2` was 200 KiB at
creation and the guest still sees a 20 GB disk with 952 MB used, because
everything unchanged is read from the shared base image.


### Q27. Why rename `sietch-1` to `sietch`, and does the plan still mean three VMs?

**Yes. Three VMs. That never changed.**

The `-1` suffix was only a naming habit meaning "first of a series". It was read
as a commitment to build more, which it was not. Compare it to naming a child
"Junior": it leaves room for the idea, but promises nothing.

```
mentat      no number   there is only one control node
windtrap    no number   there is only one database
sietch      no number   dropped, because a fourth VM is not realistic here
```

**The hardware argument, which settles it.** 4 real cores and 11 GB of RAM, with
a ClickHouse build taking all four cores every midnight. Three VMs is the
ceiling on this machine, not a starting point. A name implying a fleet was
misleading.

**How the rename was applied without breaking anything.** The address
`10.10.10.13` is pinned by MAC address in the network's DHCP table. Changing the
hostname there would normally mean redefining the network — which would
disconnect the two running VMs. There is a live-edit command instead:

```bash
virsh net-update arrakis-nat delete ip-dhcp-host \
  '<host mac="52:54:00:10:10:13" name="sietch-1" ip="10.10.10.13"/>' --live --config
virsh net-update arrakis-nat add ip-dhcp-host \
  '<host mac="52:54:00:10:10:13" name="sietch" ip="10.10.10.13"/>' --live --config
```

**`--live`** changes the running network. **`--config`** changes the saved
definition so it survives a restart. **Both flags together, or the change is
lost at the next boot, or never takes effect now.**

The same command fixed a leftover from decision D9: `windtrap`'s DHCP entry was
still named `db`. That was TODO T7, now closed.

### Q28. Can disk space be used as RAM, to run more VMs?

**Partly. It is real, and it is not a substitute for RAM.** This is a proof of
concept still to be done - see TODO **T9**.

**What swap is.** The kernel moves memory pages it judges unused onto the disk,
freeing physical RAM. The program is not told. When it next touches that page,
the kernel fetches it back.

```
RAM full
   |
   v
kernel picks the least recently used pages
   |
   +--> writes them to swap on the SSD
   |
   v
RAM free again, and the program never knew
```

Everyday comparison: a small desk and a filing cabinet behind you. Papers you
have not touched go in the cabinet. The desk stays clear. But every time you
need one of those papers you must turn around and dig.

**The scale of the penalty, which is the whole point:**

```
read a page from RAM     about 100 nanoseconds
read a page from an SSD  about 100 microseconds        about 1000x slower
```

So swap is not slow RAM. It is a different thing that merely prevents a crash.

**arrakis already has it:** 11 GiB of swap on `/dev/nvme0n1p3`, with 59 MiB in
use when measured on 2026-11-08. It is already a safety net.

**Three ways to go further, in order of value:**

| Trick | What it does | Expected gain | Cost |
|---|---|---|---|
| **zram** | Compresses pages and keeps them **in RAM**. No disk at all. | 1 to 2 GiB effective | CPU time to compress |
| **KSM** | Finds identical memory pages across VMs and keeps one copy | hundreds of MB | a background scan |
| **SSD swap** | Already enabled. Prevents crashes. | unlimited, but slow | SSD wear, 1000x latency |

**zram is the interesting one here**, because it never touches the disk. Pages of
text and code typically compress 2 to 3 times. The trade is CPU for RAM — and
arrakis has 4 cores that are idle except at midnight.

**KSM should help more than usual on this machine.** All three VMs run the same
Debian 13 from the same base image, so large parts of their memory are
byte-identical. KSM means Kernel Samepage Merging: it scans, finds duplicate
pages, and keeps one physical copy shared between guests.

**Kubernetes complication, already checked:** Kubernetes can use swap with
`LimitedSwap`, but only on cgroup v2. arrakis is cgroup v2 (confirmed:
`stat -fc %T /sys/fs/cgroup` returns `cgroup2fs`), so this is available.

**Why this is not an excuse for a fourth VM.** The measured numbers say the
constraint is not RAM:

```
2026-11-08, three VMs running
RAM   allocated 7168 MB, actually held 2628 MB, 8466 MB still available
CPU   4 real cores, all four taken by the ClickHouse build every midnight
```

**RAM is not the binding limit. CPU is.** Swap, zram and KSM all buy memory.
None of them buy a core. A fourth VM would get memory and then queue for CPU.

So the honest framing: do the proof of concept because it is worth learning and
it protects against a spike. Do not do it expecting to run more VMs.


### Q29. How will Kubernetes work across these three VMs?

Read from the official k3s documentation on 2026-11-08:
`docs.k3s.io/installation/requirements`, `/architecture`, `/quick-start`.
Quotes below are from those pages.

**The assumption "Kubernetes runs on all three VMs combined" is correct. That is
exactly what Kubernetes is.** It is not a program you install on a machine. It is
a system spread across machines, which then behave as one pool.

```
  before                          after
  +--------+ +--------+           +------------------------+
  | mentat | | sietch |    -->    |   one cluster          |
  +--------+ +--------+           |  "run 3 copies of X"   |
   separate machines              +------------------------+
                                   it chooses which machine
```

You declare **what** should exist. It decides **where** to run it, and restarts
anything that dies.

Everyday comparison: you tell a staffing agency "I need three people on this
shift". You do not choose the individuals. If one calls in sick, the agency sends
a replacement. You never manage people, only the requirement.

**Two roles. From `/architecture`:**

> "A server node is defined as a host running the `k3s server` command, with
> control-plane and datastore components managed by K3s."

> "An agent node is defined as a host running the `k3s agent` command, without
> any datastore or control-plane components."

> "Both servers and agents run the kubelet, container runtime, and CNI."

In plain words:

```
server   the brain.  Holds the record of what should exist. Decides placement.
agent    the muscle. Runs containers. Holds no record and makes no decisions.
```

Both run the **kubelet** (the agent process that starts and stops containers),
a container runtime, and the **CNI** (the plugin that gives each container an
address).

**The documented minimums**, from `/installation/requirements`:

| Role | CPU | RAM |
|---|---|---|
| Server | 2 cores | 2 GB |
| Agent | 1 core | 512 MB |

The page is explicit about what that figure excludes:

> "baseline for K3s and its packaged components, and do not include resources
> consumed by the workload itself."

**Against the VMs that exist** (measured 2026-11-08):

| VM | Allocated | k3s baseline | Left for workloads |
|---|---|---|---|
| mentat | 2 vCPU, 3072 MB | 2 cores, 2 GB | about 1 GB |
| sietch | 2 vCPU, 2048 MB | 1 core, 512 MB | about 1.5 GB |
| windtrap | 2 vCPU, 2048 MB | - | not in the cluster, if option A |

**mentat has about 1 GB of real headroom.** That is tight:
`quarantine/server-plan.md` section 9 budgets 1000 MB for Argo CD alone. Expect
to either raise mentat's memory or run Argo CD with its optional components
disabled.

**The datastore.** `/architecture` shows SQLite for a single-server cluster and
embedded etcd for a three-server high-availability cluster. **The page never uses
the word "default"**, and does not say what happens when no datastore flag is
passed. Treat "single server uses SQLite" as strongly implied, not as documented
fact, until the `/datastore` page is read.

One server means **no high availability**: if `mentat` stops, the cluster stops
making decisions. Containers already running on `sietch` keep running. This is
correct for learning and wrong for a service that must stay up.

**Ports that must be open between the VMs**, from `/installation/requirements`:

```
TCP 6443        server, reachable by ALL nodes  (the API)
UDP 8472        Flannel VXLAN, the pod network
TCP 10250       metrics server, between all nodes
TCP 2379-2380   embedded etcd, only for multi-server HA
```

All three VMs sit on `10.10.10.0/24` behind `virbr-arrakis` with no firewall, so
this should need no work. **Verify rather than assume.**

**A Debian warning worth recording**, from the same page:

> "Older Debian releases may suffer from a known iptables bug."

The VMs run Debian 13, which is current, so this probably does not apply. The
linked `/known-issues#iptables` page has not been read.

### Q30. Does windtrap join the cluster? The two plans disagree.

**This is a real conflict between two documents in this project, not a detail.**

`quarantine/server-plan.md` section 5.4.1 puts PostgreSQL, Redis and ClickHouse
**inside** Kubernetes. The later pasted plan says "db VM: PostgreSQL, Redis,
Garage (**with Ansible**)", which means outside it.

```
Option A: a 2-node cluster            Option B: a 3-node cluster
  mentat    server                      mentat    server
  sietch    agent                       sietch    agent
  windtrap  plain VM, Ansible           windtrap  agent, databases as pods
```

**Option A is recommended, for three reasons:**

1. **The cluster will be broken on purpose.** Chaos practice is the last phase of
   the plan. With A, the database survives the experiment. With B, breaking the
   cluster destroys the data store too.
2. **Databases in Kubernetes mean StatefulSets and PersistentVolumes**, which is
   a second large subject. Learning it at the same time as the basics will stall
   progress.
3. **A teaches two skills**: Kubernetes, and classic server configuration with
   Ansible. B teaches one.

**The cost of A, stated honestly:** `windtrap`'s 2 GB is not available to the
cluster, leaving about 2.5 GB of workload room across two nodes.

**Option B is not wrong.** It is the better choice if the goal is specifically to
learn how stateful workloads behave in Kubernetes. It is the worse choice for
getting a working system first.

This decision is **not yet taken**. See TODO T10.

### Q31. What is the install sequence, and where does each file live?

From `/quick-start`. These are the documented commands; **no flags have been
chosen yet** and the quick-start page does not give server flags.

**On mentat, the server:**

```bash
curl -sfL https://get.k3s.io | sh -
```

The page says this installs a service that restarts automatically, plus
`kubectl`, `crictl`, `ctr`, `k3s-killall.sh` and `k3s-uninstall.sh`.

> "A kubeconfig file will be written to `/etc/rancher/k3s/k3s.yaml` and the
> kubectl installed by K3s will automatically use it."

**The join token, on the server:**

> "The value to use for `K3S_TOKEN` is stored at
> `/var/lib/rancher/k3s/server/node-token` on your server node."

**On sietch, the agent:**

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.11:6443 K3S_TOKEN=<token> sh -
```

> "Setting the `K3S_URL` parameter causes the installer to configure K3s as an
> agent, instead of a server."

**A requirement that matters here:** the page says each machine "must have a
unique hostname", and to use `K3S_NODE_NAME` otherwise. The three VMs are named
`mentat`, `windtrap` and `sietch`, so this is satisfied.

**How a node proves who it is**, from `/architecture`:

```
agent                         cluster
  /etc/rancher/node/password  -->  secret <node-name>.node-password.k3s
  (stored locally)                 in the kube-system namespace (a hash)
```

> "If `/etc/rancher/node` is removed, the node should be deleted from the
> cluster."

**That is a trap worth remembering.** Rebuild an agent VM without deleting its
node object first, and it cannot rejoin: the cluster holds a hash of a password
the new VM does not have.

Since `sietch` is built by OpenTofu, a `tofu destroy` and re-create will hit
exactly this. The fix is to run `kubectl delete node sietch` first.

**File paths to remember:**

```
/etc/rancher/k3s/k3s.yaml                 kubeconfig, on the server
/var/lib/rancher/k3s/server/node-token    the join token, on the server
/etc/rancher/node/password                the node's own password, on each agent
```

**Not yet read, and needed before installing:**

1. `docs.k3s.io/datastore` - to confirm what the default datastore actually is.
2. `docs.k3s.io/known-issues#iptables` - to confirm the Debian bug does not apply.
3. `docs.k3s.io/installation/configuration` - for the server flags, which the
   quick-start does not give. In particular whether to disable the bundled
   Traefik and ServiceLB, which the RAM budget may require.


### Q32. Do people really run databases in Kubernetes?

**Yes. It is normal practice, not a hack.** But the official Kubernetes
documentation is notably neutral about it, which is worth knowing.

**The evidence for it.** CloudNativePG, checked 2026-11-08 from its own
repository:

```bash
gh api repos/cloudnative-pg/cloudnative-pg --jq '"stars: \(.stargazers_count)  pushed: \(.pushed_at)"'
gh api repos/cloudnative-pg/cloudnative-pg/releases/latest --jq '.tag_name'
```
```
CNCF Landscape project    9561 stars
last pushed 2026-11-07    latest v1.30.1 (2026-09-23)
```

Its README describes itself as an operator to "manage PostgreSQL databases in
Kubernetes". A CNCF Landscape project with that much activity is evidence that
the practice is mainstream.

**The evidence for caution.** The Kubernetes documentation itself:

- The **StatefulSet** page describes it as "the workload API object used to
  manage stateful applications", giving "Stable, persistent storage" and
  "Stable, unique network identifiers". **It never names a database as a use
  case.**
- The official **stateful tutorial** deploys **NGINX, not a database**, and
  warns: "the administration of stateful applications and distributed systems on
  Kubernetes is a broad, complex topic" and "Ideally, practice in a cluster that
  doesn't run any real workloads."

Two StatefulSet warnings worth remembering:

> "Deleting and/or scaling a StatefulSet down will not delete the volumes
> associated with the StatefulSet."

> "When using Rolling Updates with the default Pod Management Policy
> (OrderedReady), it's possible to get into a broken state that requires manual
> intervention to repair."

**So: the tooling is mature, and the failure modes are real and manual.**

### Q33. A terminology correction: a VM is not "in" Kubernetes

The question "do we keep db VMs in Kubernetes" mixes two layers.

```
windtrap   is a NODE   -> a machine the cluster may use
postgres   is a POD    -> a program the cluster runs on some node
```

A VM never goes "into" Kubernetes. It **joins the cluster as a node**, which
means it offers its CPU and memory to the pool. Kubernetes then decides which
pods run on it.

Everyday comparison: a node is a kitchen that joins a restaurant group. A pod is
a dish being cooked. The kitchen does not go into the menu.

So the real question was: **does windtrap offer its 2 GB to the cluster?**
Answer: yes. See decision D28.

### Q34. The three k3s pages that were outstanding (TODO T11)

Read 2026-11-08: `docs.k3s.io/datastore`, `/known-issues`,
`/installation/configuration`, plus `/installation/packaged-components`, which
had to be read because the configuration page did not answer the question.

**1. The default datastore is SQLite, and the page says so explicitly.**

> "SQLite is the default datastore, and will be used if no other datastore
> configuration is present, and no embedded etcd database files are present on
> disk."

This closes the uncertainty recorded in Q31, where the architecture page only
implied it.

**The limit that matters:**

> "SQLite cannot be used on clusters with multiple servers."

This cluster has **one server** (`mentat`) and **two agents** (`windtrap`,
`sietch`). Agents hold no datastore. **So SQLite is correct here and needs no
flags.**

Alternatives, for reference: embedded etcd (selected with `--cluster-init`), or
an external etcd, MySQL, MariaDB or PostgreSQL via `--datastore-endpoint`. The
page recommends environment variables over command-line flags for credentials,
"rather than command line arguments", because arguments are visible in the
process list.

**2. The iptables warning does not apply. Measured, not assumed.**

The `/known-issues` page says:

> "If your node uses iptables v1.6.1 or older in nftables mode you might
> encounter issues."

> "Iptables versions 1.8.0-1.8.4 also have known issues that can cause K3s to
> fail. Several popular Linux distributions ship with these versions by default."

**The page names no Debian or Ubuntu release at all**, and never mentions Debian
13. So it was checked directly on each VM:

```bash
ssh muaddib@10.10.10.11 'iptables --version'
```

**iptables is not installed on any of the three VMs.** Debian's cloud image is
minimal and does not include it. The same page gives the resolution:

> "K3s includes a known-good version of iptables (v1.8.8)... You can tell K3s to
> use its bundled version of iptables by starting K3s with the
> `--prefer-bundled-bin` option, or by uninstalling the iptables/nftables
> packages from your operating system."

Nothing is installed to conflict, so k3s will use its own bundled copy.
**No action needed.** If iptables is ever installed on these VMs, revisit this.

**3. How to pass flags, and how to disable bundled components.**

Config file path:

```
/etc/rancher/k3s/config.yaml            the main file
/etc/rancher/k3s/config.yaml.d/*.yaml   drop-ins, read in alphabetical order
```

Three ways to pass options, and command-line flags win over the file:

```bash
K3S_KUBECONFIG_MODE="644" k3s server      # environment variable
k3s server --write-kubeconfig-mode=644    # command-line flag
# or write-kubeconfig-mode: "0644" in config.yaml
```

A flag name maps to a YAML key by dropping the leading dashes. Booleans are
written `true` and `false`.

For the install script, arguments go in `INSTALL_K3S_EXEC`.

**The bundled components**, from `/installation/packaged-components`:

> "`coredns`, `traefik`, `local-storage`, and `metrics-server`."

ServiceLB is `servicelb` and "does not have a manifest file, but can be disabled
as if it were an AddOn for historical reasons."

> "start K3s with `--disable=traefik`. Multiple items can be disabled by
> separating their names with commas, or by repeating the flag."

> "Disabled AddOns are actively uninstalled from the cluster, and the source
> files deleted from the `manifests` directory."

**A trap:** the configuration page warns that `--disable servicelb` "must be set
identically on all server nodes or nodes fail to join", with a "critical
configuration value mismatch" error. Only relevant with more than one server, so
not an issue here, but it explains a confusing failure if a second server is
ever added.

**`--disable` applies to server nodes only.** The pages read say nothing about
reducing an agent's memory use.

**Not read, and still unverified:** `docs.k3s.io/cli/server`, the full
server-flag reference. The `--disable` values above come from the
packaged-components page, which does not present a complete allowed-values list
in one place.

### Q35. What to disable, and what to keep

Decided from the above, with reasons. **This is a plan, not yet measured.**

| Component | Keep? | Reason |
|---|---|---|
| `coredns` | **keep** | Cluster DNS. Pods find each other by name. Nothing works sensibly without it. |
| `local-storage` | **keep** | Provides the storage for PersistentVolumes. **Required by decision D28**, because PostgreSQL will run as a pod and needs disk. |
| `metrics-server` | **keep** | Provides `kubectl top`. The whole project is about measuring. |
| `traefik` | **disable** | An ingress controller: it routes outside HTTP traffic to pods. Nothing is exposed yet, and it costs memory. Add it when something needs a public address. |
| `servicelb` | **disable** | Assigns external addresses to services. Meaningless on a single host behind NAT. |

So the server flag is:

```
--disable=traefik,servicelb
```

**Measure the free RAM before and after the install, and write both numbers into
this file with the date.** The figures below are the documented baseline, not a
measurement:

```
server  2 cores, 2 GB     mentat has 2 vCPU, 2894 MB usable
agent   1 core, 512 MB    windtrap and sietch each 2 vCPU, 1967 MB usable
```

Note that `mentat` reports **2894 MB**, not the 3072 MB allocated. Firmware and
the kernel take the difference. Measured 2026-11-08 inside the VM with
`free -m`.

### Q36. The planned cluster shape

Decision D28: all three VMs join. One server, two agents.

```
                    +------------------------------+
                    |         the cluster          |
                    |                              |
   mentat   ------>  |  SERVER   control plane      |   10.10.10.11
   10.10.10.11       |           SQLite datastore   |   2 vCPU, 2894 MB
                    |           kubelet, CNI       |
                    |                              |
   windtrap ------>  |  AGENT    kubelet, CNI       |   10.10.10.12
   10.10.10.12       |           PostgreSQL pod     |   2 vCPU, 1967 MB
                    |           Redis pod          |
                    |                              |
   sietch   ------>  |  AGENT    kubelet, CNI       |   10.10.10.13
   10.10.10.13       |           application pods   |   2 vCPU, 1967 MB
                    +------------------------------+
```

**No high availability.** One server means that if `mentat` stops, nothing new
can be scheduled and no changes can be made. Pods already running on the agents
keep running. This is correct for learning and wrong for a service that must stay
up. Adding high availability needs three servers and embedded etcd, which this
hardware cannot afford.

**Ports required between the VMs**, from `/installation/requirements`:

```
TCP 6443      the API, reachable by ALL nodes
UDP 8472      Flannel VXLAN, the pod network
TCP 10250     metrics server, between all nodes
```

All three VMs are on `10.10.10.0/24` behind `virbr-arrakis` with no firewall
installed, so this should need no work. **Verify after the install rather than
assume.**

**All three VMs confirmed ready**, measured 2026-11-08:

```
                 cgroups     cores   usable RAM   iptables
mentat           cgroup2fs     2       2894 MB    not installed
windtrap         cgroup2fs     2       1967 MB    not installed
sietch           cgroup2fs     2       1967 MB    not installed
```

cgroup v2 on all three, which Kubernetes needs for swap support and for proper
resource limits.


### Q37. What are traefik, servicelb and local-storage, and why switch two off?

k3s ships five optional pieces already installed. Three are kept and two are
switched off. **This entry explains what each one actually does**, because
decision D30 named them without teaching them.

#### traefik - the doorway from outside

An **ingress controller**. It is the single front door that takes a request
arriving from outside the cluster and sends it to the right pod.

```
a browser on your PC
      |
      |  http://judge.example.com/submit
      v
  +---------+
  | traefik |   reads the hostname and the path
  +---------+
      |
      +--> pod "judge-api"      (for /submit)
      +--> pod "grafana"        (for /dashboards)
```

Without it, a pod has no name or address that anything outside can use.

**Everyday comparison:** the receptionist in an office building. One entrance,
one desk, and they direct each visitor to the right room. Without a
receptionist, visitors cannot find anyone, even though everyone is at their desk.

**Why switch it off now:** nothing in this cluster is exposed to the outside yet.
A receptionist for a building with no visitors costs memory and gives nothing.
Switch it on in the phase that publishes the judge API.

#### servicelb - handing out external addresses

A **load balancer** for the cluster. When a service asks for an address the
outside world can reach, servicelb finds one and assigns it.

```
service "judge-api" asks: give me an external address
      |
      v
  servicelb  -->  assigns a real address from the host's network
```

**Why switch it off now:** there is no outside network to take an address from.
All three VMs sit on `10.10.10.0/24` behind NAT, which means nothing outside
arrakis can start a connection inward at all (see Q6). servicelb would be
handing out addresses that nobody can dial.

**Everyday comparison:** a telephone extension allocator in an office whose
phone line only makes outgoing calls. The extensions are real and no one can
ring them.

#### local-storage - KEPT, and this one is required

This provides **disk that outlives a pod**.

A pod is disposable by design. Kubernetes stops it, starts a new one elsewhere,
and anything written inside it is gone. That is correct for a web server and
fatal for a database.

```
WITHOUT local-storage              WITH local-storage
  pod writes to its own space        pod writes to a PersistentVolume
  pod dies                           pod dies
  new pod starts, EMPTY              new pod starts, data still there
```

**Everyday comparison:** a hot-desk office. Without a locker, everything you
leave on the desk is thrown away each night. The locker is the
PersistentVolume - the desk changes, the locker does not.

**Why it is required here:** decision D28 chose option B, so PostgreSQL runs as a
pod. **A database pod with no persistent disk loses the database on every
restart.** `local-storage` is the piece that provides that disk, by carving it
out of the node's own filesystem.

#### coredns and metrics-server - also kept

**coredns** is the cluster's phone book. A pod reaches another by name, such as
`postgres.default.svc.cluster.local`, instead of by an address that changes every
restart. Almost nothing works sensibly without it.

**metrics-server** collects CPU and memory use per pod and per node, which is
what makes `kubectl top` work. This whole project is about measuring, so it
stays.

#### The summary table

| Component | Decision | One-line reason |
|---|---|---|
| `coredns` | keep | pods find each other by name |
| `local-storage` | **keep, required** | a database pod needs disk that survives a restart |
| `metrics-server` | keep | `kubectl top`; the project is about measuring |
| `traefik` | **disable** | a front door, and nothing is exposed yet |
| `servicelb` | **disable** | hands out external addresses, meaningless behind NAT |

So:

```
--disable=traefik,servicelb
```

**Both will be needed later.** When the judge API is published (phase 13a of
`quarantine/server-plan.md`), traefik comes back. The documentation notes that
disabling actively uninstalls a component:

> "Disabled AddOns are actively uninstalled from the cluster, and the source
> files deleted from the `manifests` directory."

So re-enabling means re-running the server without the flag, not just changing a
setting.


### Q38. Can Redis, PostgreSQL and other databases all live on one node?

**Yes, and that is the normal way.** One node runs many pods.

```
        windtrap (one node, 1967 MB)
        +----------------------------+
        |  postgres pod    ~300 MB   |
        |  redis pod        ~50 MB   |
        |  room left      ~1600 MB   |
        +----------------------------+
```

A node is not "the PostgreSQL machine". It is a machine with spare CPU and
memory, and Kubernetes packs as many pods onto it as fit.

**Everyday comparison:** an office floor does not hold one employee. It holds as
many desks as fit.

**Why a separate VM for Redis was rejected.** A fourth VM named `thopter` was
considered and dropped:

```
                      4th VM            both pods on windtrap
extra RAM used        about 500 MB      0
extra vCPU            +1 or 2           0
VMs to manage         4                 3
what Redis needs      about 50 MB       about 50 MB
```

Redis needs roughly 50 MB. **A whole virtual machine for 50 MB is waste**, and it
adds CPU contention: arrakis has 4 real cores and three VMs already claim 6
vCPU. Decision D24 stands - three VMs.

**A correction this also removed.** Thinking in VMs ("windtrap is the Postgres
machine") does not match how Kubernetes works. By default the **scheduler**
chooses the node, not you:

```
what you might expect            what happens by default
windtrap -> postgres             the scheduler picks any node with room
thopter  -> redis                either could land anywhere
```

Pinning a pod to a node needs a **label** on the node and a **nodeSelector** on
the pod. Since both databases now share one node deliberately, none of that is
needed. The topic is still worth learning later.

### Q39. Installing k3s: what went wrong and what it taught

**Three attempts. The first two failed for reasons that had nothing to do with
k3s.**

**Attempt 1 - silence.** This produced no output at all and installed nothing:

```bash
ssh arrakis 'ssh muaddib@10.10.10.11 "curl -sfL https://get.k3s.io | sh -"'
```

**The cause: `sh` reads the script from standard input, and SSH had already
claimed standard input.** With a nested SSH there are two processes competing
for the same stream, and the script body never reached `sh`.

```
curl --> pipe --> sh      sh reads the script from stdin
                   ^
                   |
                 ssh also owns stdin  -> the script is lost
```

**The fix: download to a file first, and give the installer no stdin.**

```bash
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
sudo INSTALL_K3S_EXEC=--disable=traefik,servicelb /tmp/k3s-install.sh < /dev/null
```

**`< /dev/null`** hands the script an empty input so nothing can block on it.

**Rule: never pipe a script into a shell through a nested SSH. Download it, then
run it, with stdin closed.** This is also safer: the file can be read before it
is run.

**Attempt 2 - "Job for k3s.service failed".** The installer finished and then
reported:

```
Job for k3s.service failed because the control process exited with error code.
```

This looks fatal. **It was not.** The journal showed a normal startup:

```
level=info msg="containerd is now running"
level=info msg="Running kubelet --cloud-provider=external ... --node-ip=10.10.10.11"
I1108 storage_scheduling.go:205] all system priority classes are created successfully
```

And these, which look alarming and are not:

```
E1108 controller.go:208] "Failed to ensure lease exists, will retry"
     err="namespaces \"kube-system\" not found" interval="200ms"
E1108 controller.go:95] Unable to perform initial Kubernetes service
     initialization: namespaces "default" not found
```

**Those are first-boot race conditions.** On a brand new cluster the namespaces
do not exist yet, so components that want them retry until the API server
creates them. The word `retry` in the message is the clue.

**What really happened: systemd gave up waiting before k3s finished starting.**
These are 2 vCPU virtual machines; k3s needs longer than systemd's default
patience. The service reached `active` by itself shortly afterwards.

**Rule: on slow hardware, a systemd start timeout is not the same as a failure.
Wait, then check `systemctl is-active`, before believing the error.**

The waiting loop used:

```bash
n=0; until sudo k3s kubectl get nodes >/dev/null 2>&1 || [ $n -ge 30 ]; do sleep 5; n=$((n+1)); done
```
An **until-loop with a counter**, so it stops either when the cluster answers or
after 150 seconds. Never an unbounded wait.

**Attempt 3, for the agents - shell quoting.** Passing the join token inline
through two levels of SSH meant three layers of quoting, and it broke silently:
the install never ran and `systemctl is-active k3s-agent` said `inactive`.

**The fix: stop quoting. Move the token as a file.**

```bash
ssh -n muaddib@10.10.10.11 'sudo cat /var/lib/rancher/k3s/server/node-token' > /tmp/k3s-token
scp /tmp/k3s-token muaddib@10.10.10.12:/tmp/k3s-token
ssh -n muaddib@10.10.10.12 'sudo env K3S_URL=https://10.10.10.11:6443 K3S_TOKEN=$(cat /tmp/k3s-token) /tmp/k3s-install.sh < /dev/null'
```

Two details that matter:

- **`ssh -n`** redirects standard input from `/dev/null`, so the remote command
  cannot consume the local stream. The same class of bug as attempt 1.
- **`sudo env VAR=value command`** is how an environment variable survives
  `sudo`. Plain `sudo VAR=value command` is rejected, because `sudo` treats the
  assignment as the command name.

**Rule: a secret or a long value crossing two SSH hops goes in a file, not in a
quoted string.** The token is 108 characters of base64 with colons in it, which
is exactly the shape that breaks quoting.

### Q40. The server flags, and proof they worked

```bash
sudo INSTALL_K3S_EXEC=--disable=traefik,servicelb /tmp/k3s-install.sh
```

**`INSTALL_K3S_EXEC`** is how the install script passes arguments to the k3s
server. It is documented on `docs.k3s.io/installation/configuration`.

**Proof the disables took effect**, on a fresh cluster:

```bash
sudo k3s kubectl get pods -A | grep -ciE "traefik|svclb"
```
```
0
```

And what remains is exactly the three that were kept (decision D30):

```
kube-system   coredns-577d995dff-7b28c
kube-system   local-path-provisioner-56c6584955-d25w5
kube-system   metrics-server-778c4649b4-w8n2l
kube-system   helm-install-gateway-api-crd-n977m
```

`local-path-provisioner` is the pod that `local-storage` actually runs. It is the
one that will give the PostgreSQL pod its disk, which is why decision D30 kept
it.

`helm-install-gateway-api-crd` was not expected and was not in the documented
list of packaged components. It installs the Gateway API custom resource
definitions. **Unexplained - worth looking into rather than ignoring.**

**The versions installed**, read from the node rather than assumed:

```
k3s                v1.37.2+k3s1
container runtime  containerd://2.3.7-k3s1
guest OS           Debian GNU/Linux 13 (trixie)
guest kernel       6.12.115+deb13.1-amd64
```

### Q41. The memory cost of k3s, measured before and after

Measured 2026-11-08 immediately before the install, so the cost can be compared
afterwards. **Written down first, because a baseline taken after the fact is a
guess.**

```
arrakis    11690 MB total,  7998 MB available
mentat      2894 MB total,  2546 MB available
windtrap    1967 MB total,  1730 MB available
sietch      1967 MB total,  1728 MB available
```

**And after, measured once all three nodes reported `Ready`:**

```
             before          after      cost of k3s
arrakis      7998 MB avail   5556 MB    -2442 MB
mentat       2546 MB avail   1681 MB     -865 MB   (server)
windtrap     1730 MB avail   1640 MB      -90 MB   (agent)
sietch       1728 MB avail   1619 MB     -109 MB   (agent)
```

**Compare against the documented minimums** from
`docs.k3s.io/installation/requirements`:

```
             documented      actual
server       2048 MB         865 MB
agent         512 MB          90 MB and 109 MB
```

**The real cost is well under the documented figures.** The docs give a baseline
sized for a cluster doing real work; an idle cluster with three add-ons costs far
less. That is reassuring but **not a licence to plan against the measured
number** - the figure will rise as pods are added.

What `kubectl top` reports, which is the cluster's own view:

```
NAME       CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
mentat     73m          3%       817Mi           28%
sietch     10m          0%       182Mi            9%
windtrap   17m          0%       193Mi            9%
```

**`73m` means 73 millicores**, that is 0.073 of one CPU. The unit matters: `m` is
thousandths of a core, not megabytes. An idle control plane still works
constantly - leases, health checks, reconciliation - which is why it is 3 percent
rather than 0.

Note arrakis lost 2442 MB while the three guests together account for about
1064 MB. The difference is host-side: QEMU's own growth as the guests touched
more memory, plus host page cache. **Guest memory and host cost are not the same
number**, which is the same lesson as Q26.

**Blocker B9 revisited.** It said `mentat` had only about 1 GB of headroom after
k3s's documented 2 GB baseline. The measurement says k3s actually took 865 MB,
leaving **1681 MB available** on mentat. Argo CD at the budgeted 1000 MB now
fits. **B9 is downgraded from a blocker to a watch item**, on the measurement -
not resolved, because Argo CD has not been installed yet.


### Q42. What is a LoadBalancer service, and why is it unavailable here?

Kubernetes has three ways to expose something. Think of three kinds of door.

```
ClusterIP     (default)  a door only other pods can open
NodePort                 a door in the wall of every machine, on a high port
LoadBalancer             Kubernetes ASKS SOMEONE ELSE for a real address
```

**LoadBalancer is a request, not a thing.** Kubernetes announces "this service
needs a public address" and then waits for something to answer. On AWS or Google
their platform hears it and provides one.

**Everyday comparison:** ordering a taxi. On a phone app, a taxi arrives. Shout
"taxi!" in an empty field and nothing happens. The request was fine; nobody was
listening.

There is no cloud here, and `servicelb` - the small k3s component that answers
those requests on bare metal - was switched off by decision D30. A LoadBalancer
service would therefore sit forever showing:

```
EXTERNAL-IP   <pending>
```

The Argo CD getting-started page assumes a cloud: "your cloud provider will
assign an external IP address." That assumption does not hold here.

### Q43. Why is Traefik overkill for one service? And a correction.

The instinct that "a config change beats a tunnel" is right. **The flaw is that
Traefik does not remove the tunnel.**

Traefik would listen on `10.10.10.11:443`. That address is behind NAT (Q6), so a
separate PC still cannot reach it. The result would be Traefik **and** a tunnel.

It is also not a one-line change:

```
re-enable traefik      edit the k3s config and restart k3s
  but traefik's own Service is type LoadBalancer
    -> servicelb must be re-enabled too        (Q42)
needs a hostname       there is no DNS here; /etc/hosts edits on every client
Argo CD needs a CRD    not a plain Ingress
```

The last point is from the Argo CD ingress page. Its Traefik section uses a
`traefik.io/v1alpha1` **IngressRoute**, not a standard Kubernetes Ingress,
because:

> "Argo CD API server runs both a gRPC server (used by the CLI), as well as an
> HTTP/HTTPS server (used by the UI)."

So the route needs a second rule matching `Header('Content-Type',
'application/grpc')` with `scheme: h2c`. Traefik is chosen in their docs
precisely because it "can terminate both TCP and HTTP connections on the same
port meaning you do not require multiple hosts or paths" - NGINX needs two
Ingress objects or SSL passthrough.

**Total: four changes, about 150 MB, and a tunnel anyway.**

**The correction.** An earlier comparison in this session dismissed "Tailscale
inside mentat" as teaching "nothing new". **That was wrong.** It is the only
option that removes the tunnel, because it makes `mentat` a member of the
private network directly, so NAT stops applying.

```
without:   PC --ssh--> arrakis --> mentat      a tunnel is required
with:      PC ------------------> mentat       no tunnel, ever
```

**When Traefik does earn its cost:** when several services need one front door.
With one service a front door is just a door. Revisit it at the phase that
publishes the judge API.

### Q44. Giving someone else access: two problems, not one

```
1. can they REACH it?      a network problem
2. what can they DO?       an identity problem
```

**Almost everyone thinks about the first. The second is the one that matters.**

The Argo CD installation page describes the standard manifest as "Standard Argo
CD installation with **cluster-admin** access."

So "give someone access to Argo CD" means **give someone full control of the
cluster**. The default install has one account, `admin`, holding everything.
Sharing that password shares the whole cluster.

#### The network options

Read from the Tailscale documentation on 2026-11-08.

| Method | They need Tailscale? | Exposed to | Ports |
|---|---|---|---|
| Tailscale node sharing | **yes**, and admin of their own tailnet | only that one machine | ACL-controlled |
| Tailscale Funnel | no | **the entire internet** | only 443, 8443, 10000 |
| An SSH key on arrakis | no | nobody; they tunnel | any |

**Node sharing** (`tailscale.com/kb/1084/sharing`):

> "Sharing gives the recipient access to only the shared machine in your tailnet,
> and nothing else."

> "A recipient needs to be an Owner, Admin, or IT admin of a tailnet to accept a
> shared machine invitation."

**That second line is a real catch.** The other person cannot simply click a
link - they need their own tailnet and admin rights on it.

Other documented facts:

- A shared machine is quarantined: "can receive incoming connections ... but
  cannot start connections."
- It is reachable only by its full name, `<hostname>.<tailnet-name>.ts.net`.
- "Unused invite links expire after 30 days"; reusable links work "up to 1,000
  times"; "Treat the invite link the way you would a password."
- "Sharing is available for all plans." The page does **not** state a share limit
  on the free plan, and does not state default port restrictions for a shared
  user.

**Funnel** (`tailscale.com/kb/1223/funnel`) needs nothing on their side:

> "share a local service, like a web app, for anyone to access-even if they don't
> use Tailscale"

But two hard limits apply here:

> "Funnel can only listen on ports 443, 8443, and 10000."

> "only `http://127.0.0.1` is supported for proxies"

Argo CD will be on port **30080 on mentat**. So Tailscale would have to run
**on mentat itself**, and the documentation does not show how to map 30080 onto
public port 443. Funnel also requires MagicDNS, HTTPS certificates, a `funnel`
node attribute in the policy file, and Tailscale v1.38.3 or later. It is marked
beta, and "Traffic sent over a Funnel is subject to non-configurable bandwidth
limits" with no numbers given.

#### The recommendation, and the reason it is a refusal

**Do not put Argo CD behind Funnel.** Funnel means "anyone on the internet who
learns the URL". Behind that URL is cluster-admin protected by one password.
That is not a convenience trade worth making.

**Two layers instead:**

```
network    Tailscale node sharing of mentat    one machine, nothing else
identity   a second Argo CD user, read-only    never the admin account
```

Argo CD has built-in local users and RBAC for exactly this. Create a `viewer`
account with read permissions and share that. They see the applications; they
cannot change the cluster.

**If they cannot run Tailscale:** give them an SSH key on arrakis and let them
tunnel, the same way the primary PC does. Still nothing public.

**Not yet read, and needed before doing this:** the Argo CD RBAC and local-users
pages. The claim that local users plus RBAC can produce a read-only account is
from the structure of the product, **not yet verified against its
documentation.** See TODO T16.

### Q45. Argo CD: which manifest, and which version

From `argo-cd.readthedocs.io/en/stable/operator-manual/installation/`:

```
install.yaml             "Standard Argo CD installation with cluster-admin access"
ha/install.yaml          "the same as install.yaml but with multiple replicas"
core-install.yaml        headless; "does not include the API server or UI"
namespace-install.yaml   CRDs NOT included; install them separately
```

**`install.yaml` is the choice.** HA runs multiple replicas of every component,
which this hardware cannot afford. Core has no UI at all, which defeats the
purpose. The page notes non-HA is "Not recommended for production use" - accepted
for a learning cluster.

**The page gives no CPU or memory figures for any manifest.** So the cost must be
measured after installing, as was done for k3s in Q41.

**Version.** The getting-started page says "Using a pinned version (like
`v3.2.0`) is recommended for production." Releases checked 2026-11-08 with
`gh api repos/argoproj/argo-cd/releases`:

```
v3.6.1   2026-11-04   newest, but 4 days old - and v3.6.0 was patched one day after release
v3.5.7   2026-11-02   the settled line
```

**A `.1` patch one day after a `.0` release is a signal that the new minor is
still shaking out.** `v3.5.7` is the safer pin for a learning cluster that should
not be debugging someone else's regression.

**The install commands**, from the getting-started page:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**`--server-side`** makes the API server, not kubectl, merge the changes, which
matters for the large CRDs in this manifest. **`--force-conflicts`** lets it take
ownership of fields another tool previously managed.

Replace `stable` with a tag to pin the version.

**The initial password:**

> the password is "stored as clear text in the field `password` in a secret named
> `argocd-initial-admin-secret`"

```bash
argocd admin initial-password -n argocd
```

The page warns to delete that secret after changing the password. The page does
not give a `kubectl` command to read it directly.

**TLS.** The default install "will have a self-signed certificate and cannot be
accessed without a bit of extra work." Three documented options: configure a real
certificate, trust the self-signed one, or "Use the `--insecure` flag on all Argo
CD CLI operations."

The ingress page gives the server-side equivalent: run with `--insecure`, or set
`server.insecure: "true"` in the `argocd-cmd-params-cm` ConfigMap.

**Reasoning for this cluster:** if access arrives through an SSH tunnel or
Tailscale, that transport is already encrypted. Serving plain HTTP inside avoids
a browser certificate warning without weakening anything on the wire.
**This reasoning holds only while access is through an encrypted tunnel.** If
Argo CD is ever exposed directly, TLS must come back.


### Q46. Installing Argo CD: what was done, and what it cost

Installed 2026-11-08. Version **v3.5.7**, pinned, per decision D35.

```bash
sudo k3s kubectl create namespace argocd
sudo k3s kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.7/manifests/install.yaml
```

The URL was checked with `xh --print=hb HEAD` first: HTTP 200, 105163 bytes.
**Checking a pinned URL before applying it costs nothing and catches a typo in
the tag.**

**Then two settings, each with a reason.**

**1. Plain HTTP inside the cluster:**

```bash
sudo k3s kubectl -n argocd patch configmap argocd-cmd-params-cm \
  --type merge -p '{"data":{"server.insecure":"true"}}'
sudo k3s kubectl -n argocd rollout restart deploy/argocd-server
```

Documented on the Argo CD ingress page. Without it, Argo CD serves HTTPS with a
self-signed certificate and every browser warns.

**The reasoning, which has a limit.** Access arrives over Tailscale or SSH, and
both encrypt the transport. Serving plain HTTP behind an encrypted tunnel removes
the warning without weakening anything on the wire. **If Argo CD is ever exposed
directly, TLS must come back.** That condition is the whole justification.

`rollout restart` is needed because the ConfigMap is read at startup. Patching it
alone changes nothing.

**2. A NodePort on a fixed port:**

```bash
sudo k3s kubectl -n argocd patch svc argocd-server --type merge -p \
  '{"spec":{"type":"NodePort","ports":[
     {"name":"http","port":80,"targetPort":8080,"nodePort":30080},
     {"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'
```

Result:

```
NAME            TYPE       CLUSTER-IP     PORT(S)
argocd-server   NodePort   10.43.165.19   80:30080/TCP,443:30443/TCP
```

**Why NodePort and not port-forward.** `kubectl port-forward` is a process that
must stay alive; close the terminal and the UI dies. A NodePort is a permanent
property of the Service and survives reboots. Argo CD's own documentation does
not mention NodePort at all - it lists only LoadBalancer, Ingress and
port-forward - but NodePort is standard Kubernetes and is the right fit here.

**The fixed `nodePort: 30080` matters.** Without it Kubernetes picks a random
port in 30000-32767, and the port changes if the Service is ever recreated -
which would silently break every saved tunnel command and bookmark.

#### Where the scheduler put things

```
argocd-application-controller-0        sietch
argocd-applicationset-controller       windtrap
argocd-dex-server                      sietch
argocd-notifications-controller        windtrap
argocd-redis                           sietch
argocd-repo-server                     mentat
argocd-server                          mentat
```

**Nobody chose this. The scheduler did.** Seven pods, spread across three
machines, placed by available room. This is the thing a single-node cluster
cannot demonstrate, and the reason the three VMs exist (Q29).

#### Verification, not assumption

```bash
curl -s -o /dev/null -w "%{http_code}" http://10.10.10.11:30080/   # 200
curl -s http://10.10.10.11:30080/api/version                       # {"Version":"v3.5.7"}
```

The version endpoint confirms the pin actually took effect, rather than trusting
that the URL was right.

#### The measured cost

The Argo CD installation page gives **no CPU or memory figures for any
manifest**, so the only way to know is to measure.

```
             before argocd   after      cost
arrakis      5545 MB avail   3438 MB    -2107 MB
mentat       1819 MB avail   1463 MB     -356 MB
windtrap     1633 MB avail   1475 MB     -158 MB
sietch       1628 MB avail   1462 MB     -166 MB
```

**Inside the VMs, Argo CD cost about 680 MB in total** - well under the 1000 MB
that `quarantine/server-plan.md` budgeted for it, and spread across three
machines instead of landing on one.

**arrakis lost 2107 MB, which is three times the guests' own figure.** Same
lesson as Q26 and Q41: QEMU grows as a guest touches more memory, and the host
also caches the guests' disk activity. **Guest cost and host cost are different
numbers. Always measure the host too.**

**A new watch item.** arrakis is now at 3438 MB available, and the nightly
ClickHouse build wants 2 to 4 GB. It should fit, but the margin has gone from
comfortable to thin, and swap may start being used at midnight. See TODO T17.

**Blocker B9 is now closed.** It warned that `mentat` had only about 1 GB of
headroom and that Argo CD's 1000 MB budget might not fit. Measured: Argo CD cost
mentat 356 MB, and mentat still has 1463 MB available.

### Q47. Tailscale on mentat: what it does and why it ends the tunnel

Installed 2026-11-08: Tailscale **1.104.5**, daemon `active` and `enabled`.

```bash
curl -fsSL https://tailscale.com/install.sh -o /tmp/ts-install.sh
chmod +x /tmp/ts-install.sh
sudo /tmp/ts-install.sh < /dev/null
```

Downloaded, then run - the same rule as D34. Never piped into a shell.

**What this changes.** `mentat` becomes a member of the private Tailscale network
in its own right, so NAT stops applying to it.

```
before:   PC --ssh--> arrakis --> mentat:30080      a tunnel every time
after:    PC -----------------> mentat:30080        direct, permanent
```

**How it gets past NAT.** Tailscale builds a direct encrypted connection between
two machines even when both sit behind routers that block inbound connections.
Both ends make an **outbound** connection to a coordination service, which
introduces them to each other; they then talk directly. If that fails, traffic
goes through a relay.

**Everyday comparison:** two people who cannot receive calls both ring the same
switchboard, which then connects them to each other. Neither had to accept an
incoming call.

**The remaining step needs a human.** `sudo tailscale status` reports
`Logged out.` Authentication opens a URL that must be visited in a browser and
approved in the Tailscale account. An agent cannot do that, and should not: it is
the step that proves a person authorised the machine to join their network.

**A note recorded from reading the sharing documentation (Q44):** once `mentat`
is on the tailnet, it can be **shared** with one other person, who then reaches
only that machine - "access to only the shared machine in your tailnet, and
nothing else." That is the groundwork for giving someone else access without
exposing anything publicly.

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


### Diagnosing the package manager

```bash
grep -rhv '^#' /etc/pacman.d/mirrorlist | grep -v '^$'
```
Prints the configured mirrors with comments and blank lines removed.
**`-r`** searches recursively, **`-h`** hides the file name, **`-v`** inverts the
match so commented lines are dropped. Result: one mirror,
`https://stable-mirror.omarchy.org/$repo/os/$arch`. A single pinned mirror is
the clue that explains Q19: there is no second mirror to fall back to.

```bash
ls -l --time-style=+%F_%H:%M /var/lib/pacman/sync/extra.db
```
Shows when the local package catalogue was last refreshed.
**`--time-style`** forces a fixed, sortable date format instead of the locale
default, which hides the year for recent files and so hides exactly the problem
being looked for. Result: 2026-09-08, two months stale.

```bash
pacman -Si opentofu
```
**`-S`** is the sync database, **`-i`** means info. Together they report what the
**local catalogue** says about a package in a repository. It touches no network,
so it shows what pacman is about to ask for, not what is available.

```bash
pacman -Ss '^opentofu$'
```
Searches the catalogue. The **`^...$`** anchors make it an exact name match
rather than a substring search, which otherwise returns every package whose
description mentions the word.

```bash
xh --print=hb HEAD "<url>"
```
Asks a server about one file without downloading it. **HEAD** requests the
headers only. **`--print=hb`** shows the response **h**eaders and **b**ody.
This is the correct way to test a 404 claim: it costs nothing and answers
exactly the question asked.

```bash
xh --print=b GET "https://archlinux.org/packages/search/json/?name=opentofu" \
  | jq -r '.results[] | "\(.repo) \(.pkgver)-\(.pkgrel)"'
```
Asks Arch's own package API for the current version. This is the authoritative
source for "what is current", as opposed to the local catalogue, which only says
"what I last heard". **`jq -r`** prints raw strings instead of quoted JSON.

```bash
ls /usr/share/omarchy/bin/ | grep -i omarchy
```
Finds the distribution's own tooling before reaching for generic Arch commands.
Result: `omarchy-update` and `omarchy-pkg-install`. On a distribution that pins a
mirror snapshot, its own updater is the correct tool, because it moves the whole
snapshot and avoids a partial upgrade.

**Rule: check for distribution-specific tooling before using the generic
command. A pinned-snapshot distribution has different rules from plain Arch.**

```bash
ssh -t arrakis 'sudo <anything>'
```
**`-t`** allocates a terminal on the remote side. Without it `sudo` has nowhere
to prompt for a password and refuses with "a terminal is required". See Q19,
failure 2.


### Finding out why a machine went down

```bash
tailscale status | grep arrakis
```
Lists every machine on your Tailscale network with its last contact time.
"offline, last seen 8h ago" separates a network fault from a machine fault: a
network fault leaves the machine running. See Q21.

```bash
cat /sys/class/power_supply/BAT0/status
cat /sys/class/power_supply/BAT0/capacity
```
Reads the battery. Linux presents hardware as files under `/sys`, so no tool is
required. `status` is `Charging`, `Discharging` or `Full`. `capacity` is the
percentage. A machine that comes back at 2 percent while charging ran itself
flat.

```bash
uptime -p; uptime -s
```
**`-p`** prints how long it has been up in words. **`-s`** prints the exact time
it booted, which is what you compare against "last seen".

```bash
ssh-add -l
systemctl --user is-active ssh-agent.socket
```
Run on the PC after its own reboot, when `ssh` suddenly failed with
`ssh_askpass: exec(/usr/lib/ssh/ssh-askpass): No such file or directory`.

That error is misleading. It does not mean a missing program is the problem. It
means **ssh had no key to offer**, so it fell back to asking for a passphrase,
and then found no graphical dialog to ask with. The real fault is one level up.

Result: `The agent has no identities` and the socket `inactive`. The PC's reboot
emptied the agent.

```bash
systemctl --user enable --now ssh-agent.socket
ssh-add ~/.ssh/sohail-omarchy
```
**`enable`** makes it start at login, **`--now`** also starts it immediately.
Without `enable` the same failure returns after every reboot.

Note the key name: arrakis authorises **`sohail-omarchy`**, not `id_ed25519`.
The PC holds both. Adding the wrong one looks like success and still fails to
connect.

```bash
virsh autostart <vm>
```
Marks a VM to start with the host. It does **not** start it now. See Q22.


### Running OpenTofu

```bash
tofu init
```
Downloads the provider named in `versions.tf` and writes `.terraform/` plus
`.terraform.lock.hcl`. The lock file records the exact version and its
checksums, and **is** committed, so another machine gets the same provider.

Note the warning it printed: "Signature validation was skipped due to the
registry not containing GPG keys for this provider." The download was not
cryptographically verified against the author's key, because this provider does
not publish one to the OpenTofu registry. Accepted here; worth knowing.

```bash
tofu validate
```
Checks the configuration for syntax and schema errors **without touching
anything remote**. Much faster than `plan` when fixing field names, which is
most of what Q23 was.

```bash
tofu plan
```
Connects to the real libvirt on arrakis, reads what exists, and prints what it
would change. Changes nothing. Result: `Plan: 3 to add, 0 to change, 0 to
destroy` — the "0 to destroy" is the line that proved it would not touch
`mentat`, the pool or the network.

```bash
tofu apply -auto-approve
```
Does it. **`-auto-approve`** skips the interactive "yes" prompt, which is
required when running non-interactively, and is the flag to be careful with: it
removes the last chance to read the plan.

```bash
gh api -X GET search/issues -f q='repo:dmacvicar/terraform-provider-libvirt readonly loader'
```
Searches a project's issue tracker from the command line. Used to confirm that
the documentation example really is stale rather than misread. It found issue
**#1243, "Examples don't reflect updated schema"**.

**Rule: when a tool's documentation and its behaviour disagree, search its issue
tracker before assuming the mistake is yours.**

```bash
gh api repos/<owner>/<repo>/contents/docs/resources/domain.md --jq '.content' | base64 -d
```
Reads a documentation file straight out of the repository. Needed because the
OpenTofu registry website renders its pages with JavaScript, so a plain fetch
returns an empty page. The repository's `docs/` directory is generated from the
provider's code, which makes it the authoritative schema.

```bash
sed -n '/### Nested Schema for `os.boot_devices`/,/^<a id/p' domain-doc.md
```
Extracts one nested schema from a 12430-line generated document. **`sed -n`**
with a `/start/,/end/p` range prints only the lines between two patterns. This
is how each field name above was confirmed rather than guessed.

```bash
virsh undefine <vm> --nvram
```
Removes a domain definition, and with **`--nvram`** also its UEFI settings
file. Needed when a failed `tofu apply` leaves a defined-but-unstarted domain
that OpenTofu did not record in its state. See Q23, error 6.


### Diagnosing a VM that runs but does nothing

```bash
virsh dominfo <vm> | grep -i "cpu time"
```
The single most useful number. Compare it against the VM's age:

```
188 s in 2 minutes   -> spinning: a boot loop (Q14)
9.5 s and barely rising -> idle: stuck waiting for something (Q25)
```
Two different failures with the same outward symptom, told apart by one number.

```bash
virsh console <vm>
```
Fails from a script: `Cannot run interactive console without a controlling TTY`.
It needs a terminal. Use console logging instead, set in the domain definition:

```hcl
log = { file = "/var/log/libvirt/qemu/<vm>-console.log", append = "on" }
```
Then the boot output is a file any tool can read. Add this to every VM.

```bash
virsh vol-dumpxml <volume> --pool <pool>
```
Prints a storage volume's definition, including its `<backingStore>` element.
Needs no root, unlike reading the image file. The way to check whether an
overlay really points at its base.

```bash
qemu-img info -U --backing-chain <file>
```
Walks a qcow2 file down through every layer to its base and prints each one.
**`--backing-chain`** is what makes it show the whole stack rather than the top
file. **`-U`** means "unsafe": read it even though a running VM holds a lock. It
reports `corrupt: true/false` per layer.

```bash
virsh dumpxml a | sed "s/a/VMNAME/g" > /tmp/a.xml
virsh dumpxml b | sed "s/b/VMNAME/g" > /tmp/b.xml
diff /tmp/a.xml /tmp/b.xml
```
**The command that should have been run first.** When one machine works and a
near-identical one does not, the difference is the cause. The `sed` normalises
the names so the diff shows real differences instead of every occurrence of the
name.

It found `type='raw'` against `type='qcow2'` in thirty seconds, after an hour of
theories about permissions, AppArmor and GPT headers.

```bash
ps -o rss=,comm= -C qemu-system-x86_64 | awk '{printf "%.0f MB\n", $1/1024}'
```
**`rss`** is resident set size: the physical memory a process actually holds.
**`-C`** selects by command name. Dividing by 1024 converts KiB to MiB.

This is how "allocated" and "actual" were compared in Q26. Reading the
allocation from the VM definition would have given 5120 MB; the truth was
2099 MB.


### Renaming a VM's DHCP entry without restarting the network

```bash
virsh net-update <network> delete ip-dhcp-host '<host mac="..." name="old" ip="..."/>' --live --config
virsh net-update <network> add    ip-dhcp-host '<host mac="..." name="new" ip="..."/>' --live --config
```
Edits one entry in a live network. **`--live`** applies it to the running
network; **`--config`** writes it to the saved definition. Pass both, or the
change either disappears at the next boot or does not take effect now.

The alternative - `net-destroy` then `net-define` - would disconnect every
running VM. This does not.

```bash
virsh net-dumpxml <network> | grep host
```
Confirms the result. Used after each edit above.

### Building the third VM

```bash
tofu validate
```
Caught the first problem immediately: `A local value named "mac" was already
defined`. **`locals` are module-wide, not per-file.** Copying a `.tf` file that
declares `local.name` into the same directory collides. Both files were changed
to use a named map - `local.windtrap.name`, `local.sietch.name` - which also
reads better.

Renaming a local changes nothing about a resource's address, so no VM was
destroyed by the edit.

```bash
tofu plan
```
```
Plan: 4 to add, 0 to change, 0 to destroy.
```
The **"0 to change, 0 to destroy"** is the line that matters: it proved `mentat`
and `windtrap` would not be touched.

```bash
tofu apply -auto-approve
```
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

**`sietch` booted correctly on the first attempt.** `windtrap` took seven. Every
trap from Q23 and Q25 was already a comment in the file that was copied:
`driver.type = "qcow2"`, the uploaded seed volume, `features.acpi`,
`loader_readonly = "yes"`, `boot_devices = [{ dev = "hd" }]`, console logging and
`autostart`.

**That is the return on the IaC work, stated plainly: seven attempts, then one.**


### Checking the VMs are fit for Kubernetes

```bash
ssh muaddib@10.10.10.11 'stat -fc %T /sys/fs/cgroup; nproc; free -m | sed -n 2p; iptables --version'
```
Four checks in one line, run against each VM.

**`stat -fc %T`** prints a filesystem's type. On `/sys/fs/cgroup` it answers
which cgroup version the kernel uses: `cgroup2fs` means version 2. Kubernetes
needs v2 for swap support and for reliable memory limits.

**`sed -n 2p`** prints only line 2 of the output, which is the `Mem:` row.
Shorter than `grep Mem` and it cannot match the wrong line.

**`iptables --version`** printed nothing at all, which was the useful result:
the package is not installed. Debian's cloud image is minimal. k3s then uses its
own bundled copy and the documented iptables bugs cannot apply. **A command that
produces no output can be the answer.**

```bash
gh api repos/cloudnative-pg/cloudnative-pg --jq '"stars: \(.stargazers_count)  pushed: \(.pushed_at)"'
gh api repos/<owner>/<repo>/readme --jq '.content' | base64 -d | grep -iE 'cncf|operator'
```
Used to judge whether a project is real and maintained, rather than trusting a
recollection. `pushed_at` is the honest signal: a project last touched years ago
is not maintained, whatever its star count says.

This was needed because the CloudNativePG documentation site returned an empty
page to a plain fetch, so the repository had to be read instead - the same
problem as the OpenTofu registry in Q3.


### Installing k3s

```bash
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
sudo INSTALL_K3S_EXEC=--disable=traefik,servicelb /tmp/k3s-install.sh < /dev/null
```
Downloads the installer, then runs it. **Not** `curl | sh`, because `sh` reads the
script from stdin and a nested SSH has already claimed that stream. See Q39.
**`< /dev/null`** guarantees the script cannot block waiting for input.

**`INSTALL_K3S_EXEC`** carries arguments through to the k3s server itself.

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```
Prints the token an agent needs to join. 108 characters, base64, containing
colons - the shape that breaks shell quoting, which is why it was moved as a
file.

```bash
sudo env K3S_URL=https://10.10.10.11:6443 K3S_TOKEN=$(cat /tmp/k3s-token) /tmp/k3s-install.sh < /dev/null
```
Installs an agent instead of a server. **Setting `K3S_URL` is what makes it an
agent** - documented on `docs.k3s.io/quick-start`.

**`sudo env VAR=value cmd`** is required. Plain `sudo VAR=value cmd` fails,
because sudo reads the assignment as the command name.

```bash
ssh -n <host> '<command>'
```
**`-n`** redirects the remote command's standard input from `/dev/null`. Without
it, a remote command that reads stdin eats the local stream, which silently
breaks loops and piped installers. Used on every remote call after Q39.

```bash
sudo systemctl is-active k3s          # on the server
sudo systemctl is-active k3s-agent    # on an agent
```
**Different unit names.** The server unit is `k3s`; the agent unit is
`k3s-agent`. Checking the wrong one reports `inactive` and looks like a failure.

```bash
sudo journalctl -u k3s --no-pager -n 40 | grep -viE "^--|Started|Stopping|Consumed"
```
Reads the service log. The `grep -v` removes systemd's own framing lines so the
application's own messages are visible. **`--no-pager`** is essential: without it
journalctl opens a pager and waits for a keypress, and an agent hangs.

```bash
sudo k3s kubectl get nodes -o wide
```
Lists the cluster's machines. **`-o wide`** adds the internal address, the OS,
the kernel and the container runtime - the facts worth recording rather than
assuming.

```bash
sudo k3s kubectl get pods -A | grep -ciE "traefik|svclb"
```
**`-A`** means all namespaces. **`-c`** counts matching lines instead of printing
them. Returning `0` is the proof that `--disable` worked, rather than trusting
that the flag was accepted.

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
| ~~B4~~ | ~~ccache hit rate is 0.34 percent~~ | **MOOT 2026-11-08.** The build, the cache and the source were deleted (D42). Nothing was learned about ccache; if the build returns, so does this. |
| B6 | The PC's pacman catalogue is two months stale (2026-09-08) | Every new package install fails with a 404 until `omarchy-update` runs. Blocks installing OpenTofu from the repositories. |
| ~~B5~~ | ~~Proxmox decision not taken~~ | **CLOSED 2026-11-08 by D8.** libvirt instead. B2 and B3 were Proxmox-only and are also closed. |

### Q48. Sealed Secrets or OpenBao? And where does a secrets manager live?

**Two different products solving the same problem in opposite ways.**

```
Sealed Secrets   a Kubernetes CONTROLLER    must live inside a cluster
OpenBao          a real SERVER with an API  can live anywhere
```

**Sealed Secrets cannot run on its own VM.** It is a controller: a program that
watches the cluster's API for `SealedSecret` objects and converts them into
ordinary Secrets. Outside a cluster there is nothing for it to watch. So
"a VM for the secret manager" necessarily means OpenBao.

**Why Vault was not considered.** HashiCorp changed Vault's licence from MPL-2.0
to BSL in 2023, which restricts commercial use. **OpenBao is the fork of the last
open version.** Confirmed from the repository on 2026-11-08: licence `MPL-2.0`,
8926 stars, last pushed 2026-11-06, latest `v2.7.2`.

#### Where real teams put a secrets manager

Three patterns, in order of how common they are:

1. **A managed service** - AWS Secrets Manager, Google Secret Manager, Azure Key
   Vault. Nothing is installed; you call an API. Most companies. Not available
   here.
2. **Vault or OpenBao on dedicated machines, outside Kubernetes** - larger
   organisations, and the pattern chosen here.
3. **Vault or OpenBao inside Kubernetes** - single-cluster setups, via a Helm
   chart.

**The reason pattern 2 exists is a circular dependency:**

```
secrets manager INSIDE the cluster
      |
      v
the cluster dies
      |
      v
rebuilding it needs secrets  --> which live in the dead cluster
```

The secrets manager is the **root of trust**. If it depends on the thing it
serves, one bad day becomes a very bad day. Keeping it outside breaks the circle.

**Everyday comparison:** you do not keep the only key to the building inside the
building.

**Sealed Secrets avoids this differently**, and it is worth understanding the
difference. It is not queried at runtime - it decrypts once, when a manifest is
applied, then gets out of the way. But it has the **same root problem in another
shape**: lose its private key and every SealedSecret ever committed to Git becomes
permanently unreadable. The backup requirement does not disappear; it moves.

#### A mental-model correction, recorded because it recurred

The VMs were named after intentions - "windtrap is the database machine",
"sietch is the app machine". **That separation does not exist.** Kubernetes sees
three machines with free capacity:

```
what was pictured              what Kubernetes sees
windtrap = the db machine      a node with 1475 MB free
sietch   = the app machine     a node with 1462 MB free
mentat   = control plane       a node with 1463 MB free
```

Argo CD proved it: the scheduler put two of its seven pods on `mentat` and the
rest wherever there was room. Nobody instructed it.

Making the intended separation real needs **node labels** with `nodeSelector`, or
**taints** to keep workloads off the control plane. That remains to be learnt.

`shieldwall` is different: it is **not a cluster node at all**, so nothing can be
scheduled onto it. That is the point.

### Q49. Removing the ClickHouse build

Done 2026-11-08 at the user's instruction, after the cost was stated twice.

**What was measured first:**

```
worktree build output   40 GB
ccache                 5.1 GB
ClickHouse source       82 GB
                       ------
                       127 GB of 150 GB used
```

**What the check found, which changed the order of work:**

```bash
git --no-pager for-each-ref --format='%(refname:short) %(upstream:short) %(upstream:track)' refs/heads
git --no-pager status --short
git --no-pager stash list
```

Seven uncommitted files on the branch `fix-duplicate-storage-namespaces`, and no
stashes. **Work that existed nowhere else.**

```
 M src/Disks/DiskSelector.cpp
 M src/Disks/StoragePolicy.cpp
 D tests/queries/0_stateless/05444_duplicate_storage_namespace_rejected.sh
 ... 7 files in total
```

**The lesson is the order, not the deletion.** The instruction was "delete it".
The right first move was still to look at what would be lost and say so. The
decision stayed the user's; the facts were theirs to have.

An 18916-byte patch was saved to `~/clickhouse-wip-20261108.patch` before
deleting - two seconds, and it does not change the outcome asked for.

**The timer.** Disabling it printed something worth understanding:

```
Removed '/home/muaddib/.config/systemd/user/clickhouse-master-build.timer'.
```

`systemctl disable` **removed the symlink itself**, because the unit was a link
into the dotfiles repository. The real files survive at
`~/Github/dotfiles/systemd/user/`, so re-linking restores it. **Checked before
deleting, not after.**

**The result:**

```
before   150 GB used, 283 GB free
after     24 GB used, 410 GB free
```

126 GB freed, and all four cores free at midnight.

**Two items became moot.** TODO T1 and blocker B4 were about ccache missing
99.66 percent of its lookups. There is no longer a build, a cache, or a problem.
**The best fix for a problem is sometimes the removal of the thing that had it** -
but note that nothing was *learned* about ccache. If the build ever returns, so
does T1.

### Q50. shieldwall: the fourth VM, and why D24 changed

**Decision D24 said three VMs was the ceiling**, on the grounds that arrakis has
4 real cores and three VMs already claimed 6 vCPU.

**Removing the ClickHouse build changed the fact that decision rested on.** The
build took all four cores for hours every night. With it gone, load sits at 0.50.

```
before:  4 cores, 6 vCPU allocated, plus a 4-hour nightly build on all 4
after:   4 cores, 7 vCPU allocated, load 0.50
```

So `shieldwall` was given **1 vCPU, not 2** - OpenBao is a single light process,
not a container host.

**Built with OpenTofu**, as a near-copy of `sietch.tf`:

```bash
sed -e 's/sietch/shieldwall/g' \
    -e 's/52:54:00:10:10:13/52:54:00:10:10:14/' \
    -e 's/10\.10\.10\.13/10.10.10.14/g' \
    tofu/sietch.tf > tofu/shieldwall.tf
```

**It booted first time.** Every trap from Q23 and Q25 was already a comment in
the file being copied. That is the third VM in a row to work immediately, against
`windtrap`'s seven attempts.

The DHCP entry was added **live**, with no network restart, so the three running
VMs kept their connections (decision D25):

```bash
virsh net-update arrakis-nat add ip-dhcp-host \
  '<host mac="52:54:00:10:10:14" name="shieldwall" ip="10.10.10.14"/>' --live --config
```

**Verified:** `hostname` = shieldwall, NAT works, 1 vCPU, 1463 MB total with
1174 MB available, autostart enabled.

### Q51. Installing OpenBao, and what "sealed" means

**The package.** OpenBao ships a Debian package, so nothing is built from source.

```bash
curl -fsSLO https://github.com/openbao/openbao/releases/download/v2.7.2/openbao_2.7.2_linux_amd64.deb
curl -fsSLO https://github.com/openbao/openbao/releases/download/v2.7.2/checksums.txt
grep 'openbao_2.7.2_linux_amd64.deb$' checksums.txt | sha256sum -c -
```
```
openbao_2.7.2_linux_amd64.deb: OK
```

**The checksum came from the project's own `checksums.txt`, downloaded next to
the package.** The release also ships `.gpgsig` and `.sigstore.json` for each
asset, which is stronger verification and was not used here - a checksum from the
same server proves integrity, not provenance. Worth upgrading to if this ever
matters.

```bash
sudo apt-get install -y /tmp/openbao_2.7.2_linux_amd64.deb
```

**Installing a `.deb` through `apt-get install /path/to/file.deb`** rather than
`dpkg -i` matters: apt resolves and installs dependencies, dpkg does not.

**What the package shipped**, read rather than assumed:

```
/usr/bin/bao
/etc/openbao/openbao.hcl
/etc/openbao/openbao.env
/usr/lib/systemd/system/openbao.service
```

It also generated a self-signed certificate at install time, into
`/opt/openbao/tls/`.

**The default configuration needed no changes:**

```hcl
ui = true
storage "pebbledb" {
  path = "/opt/openbao/data"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/openbao/tls/tls.crt"
  tls_key_file  = "/opt/openbao/tls/tls.key"
}
```

**Note that TLS stays on here**, unlike Argo CD (decision D40). The difference:
Argo CD is reached through an encrypted tunnel; OpenBao will be reached across
the VM network by the cluster, which is not tunnelled.

**After starting it:**

```
Seal Type      shamir
Initialized    false
Sealed         true
Storage Type   pebbledb
```

And from arrakis, `curl https://10.10.10.14:8200/v1/sys/health` returned
**HTTP 501**. That is the documented response for an uninitialized vault, **not
an error**.

#### What "sealed" means, and why it is the whole design

OpenBao encrypts everything it stores. The key that decrypts the storage is
itself encrypted, and **the key to that is never kept on disk**.

```
sealed      the data is there, and unreadable - even to the process itself
unsealed    the decryption key is in memory, and the service can answer
```

Every restart begins sealed. A human must unseal it. **That is deliberate:** if
someone steals the disk, or the VM, they get ciphertext.

**Shamir** is the method. On initialisation it produces several key shares and
requires a threshold of them to unseal - for example 5 shares, any 3 of which
work.

**Everyday comparison:** a bank vault needing three of five managers to turn
their keys at once. No single person can open it, and two can be on holiday.

#### Why the initialisation was handed to the user

`bao operator init` prints the unseal key shares and the root token **once, and
never again**. Those are the credentials to everything the vault will ever hold.

An agent should not see them, and the environment correctly blocked an earlier
attempt to read Argo CD's admin password for the same reason. **The person who
owns the secrets does the step that creates them.**


### Q52. "permission denied" on bao login, and what actually caused it

**The symptom.** `bao login`, with the root token pasted from the init output:

```
Error authenticating: error looking up token: Error making API request.
URL: GET https://127.0.0.1:8200/v1/auth/token/lookup-self
Code: 403. Errors:
* permission denied
```

**The first theory, and why it was wrong.** The obvious guess was that an unseal
key had been pasted instead of the root token - the init output contains five
unseal keys and one root token, and they look alike. The user confirmed they were
using the root token, so that was out.

**The checks that narrowed it down.**

```bash
bao status | grep Sealed            # Sealed false - so unsealing had worked
ls -l ~/.bao-token ~/.vault-token   # (no cached token file) - no stale token
```

```bash
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:8200/v1/sys/health        # 200
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:8200/v1/sys/seal-status   # 200
```

**The API was healthy.** Unauthenticated endpoints answered normally, so the
server was fine and the token specifically was being rejected.

The server log confirmed the token had genuinely been created:

```bash
sudo journalctl -u openbao --no-pager -n 400 | grep -iE "error|denied|token|unseal"
```
```
08:13:34  core: root token generated        <- the init
08:19:18  core: vault is unsealed           <- the manual unseal, successful
```

**The cause: the token was mangled on screen.**

The init had been run through two nested terminals:

```bash
ssh -t arrakis 'ssh -t muaddib@10.10.10.14 "... bao operator init ..."'
```

A root token is a long string. Through two nested TTYs it **line-wraps**, and
copying a wrapped line silently drops or adds characters. The value pasted was
not the value printed.

**Why the unseal keys worked anyway:** they were pasted one at a time into a
prompt, and only three of five had to be correct. The root token has no such
margin - one wrong character and it is simply wrong.

```
unseal   5 shares, any 3 needed       tolerant of one bad paste
token    exactly one value            no tolerance at all
```

#### The fix: never read a secret off a terminal

The vault was empty, so re-initialising cost nothing. The important change was
not the re-init - it was **removing the terminal from the path**:

```bash
sudo systemctl stop openbao
sudo rm -rf /opt/openbao/data/*
sudo systemctl start openbao

bao operator init -format=json > ~/bao-init.json
chmod 600 ~/bao-init.json
```

**`-format=json`** writes machine-readable output. Redirected to a file, nothing
is ever wrapped, displayed, selected or pasted.

Then every use reads from that file:

```bash
for i in 0 1 2; do
  bao operator unseal "$(jq -r \".unseal_keys_b64[$i]\" ~/bao-init.json)"
done
export BAO_TOKEN="$(jq -r .root_token ~/bao-init.json)"
```

**Rule: a credential should travel from a file to a program and never through a
screen or a clipboard.** Every hop through a display is a chance to corrupt it,
and a chance for it to be seen.

#### A note on what an agent may and may not do

Reading Argo CD's admin password earlier was blocked by this environment as
"Credential Materialization", correctly.

**These commands were different, and the distinction is worth stating.** The
literal text sent was `$(jq -r .root_token ~/bao-init.json)` - a command
substitution that is evaluated **on shieldwall**. The secret's value never
entered the agent's context, was never printed, and was never logged. The agent
orchestrated a secret it could not read.

**The right answer to "shall I paste the token in the chat?" is no**, and it
stays no. A chat transcript is a display. See the rule above.

#### The result

```
policies: root                     the token works
Success! Enabled the kv-v2 secrets engine at: secret/
hello    world                     written and read back
note     proof the vault works
```

Engines now mounted: `cubbyhole/`, `identity/`, `secret/` (kv), `sys/`.

**What this proved, which was the whole point of doing it first:** the unseal
keys are correct, the `pebbledb` storage persists, and the root token works -
all verified before anything depends on them.


### Q53. PostgreSQL on Kubernetes: why a StatefulSet, and why it is pinned

#### The problem in one sentence

**Kubernetes is built to move things. A database cannot move, because its data
is on a disk.**

```
a stateless program on windtrap
windtrap dies
Kubernetes starts it on sietch        fine - nothing was carried

a database on windtrap
its data is on windtrap's disk
windtrap dies
Kubernetes tries sietch
   -> sietch has no data
   -> empty, or will not start
```

**Everyday comparison:** a waiter can be replaced mid-shift; they carry nothing.
A filing cabinet cannot - the papers are inside it. Swap the cabinet and the
papers are gone. A database is a filing cabinet; Kubernetes expects waiters.

#### What the storage actually is here

Measured 2026-11-08 with `kubectl get storageclass`:

```
local-path (default)   provisioner rancher.io/local-path
reclaimPolicy          Delete
volumeBindingMode      WaitForFirstConsumer
ALLOWVOLUMEEXPANSION   false
data path              /var/lib/rancher/k3s/storage
```

**Four consequences, each one a trap:**

| Property | What it means |
|---|---|
| `local-path` | The volume is a directory on **one node's own disk**. It does not follow a pod. |
| `reclaimPolicy: Delete` | Delete the PersistentVolumeClaim and **the data is deleted with it**. |
| `ALLOWVOLUMEEXPANSION: false` | The volume **cannot be grown later**. Size it correctly now. |
| `WaitForFirstConsumer` | The volume is not created until a pod needs it, so it lands on the node the pod lands on. |

Real clusters avoid the first one with network storage - Ceph, NFS, a cloud disk -
which any node can mount. **One laptop cannot have that.** Accept the pinning and
be explicit about it.

#### Deployment versus StatefulSet

```
Deployment    pods are interchangeable; no storage of their own
StatefulSet   each pod gets a stable NAME and its OWN volume
```

The volume comes from `volume_claim_template`, and the Kubernetes docs are
explicit that it outlives the pod:

> "Deleting and/or scaling a StatefulSet down will not delete the volumes
> associated with the StatefulSet."

A StatefulSet also requires a **headless Service** - `cluster_ip = "None"`:

> "StatefulSets currently require a Headless Service to be responsible for the
> network identity of the Pods."

A normal Service load-balances across pods. A headless one instead gives each pod
its own DNS name, which is what "stable identity" means in practice:

```
postgres-0.postgres.data.svc.cluster.local:5432
~~~~~~~~~~ ~~~~~~~~ ~~~~
pod name   service   namespace
```

#### Deliberate pinning, rather than accidental

```hcl
node_selector = {
  "kubernetes.io/hostname" = var.pg_node   # windtrap
}
```

**The pod would be pinned either way.** Without the selector the scheduler picks
a node, the volume is created there, and the pod can never leave it. The
selector only makes the choice visible and intentional.

This is the `nodeSelector` that Q48 said would eventually be needed. This was
eventually.

#### Two details that would have caused failures

**1. File ownership.**

```hcl
security_context {
  fs_group = 999
}
```

The `postgres` image runs as uid 999. A freshly provisioned volume is owned by
root, so `initdb` fails with a permission error. `fs_group` makes Kubernetes set
group ownership of the mount to 999 so the database can write.

**2. The readiness probe must ask the database, not the socket.**

```hcl
readiness_probe {
  exec { command = ["pg_isready", "-U", "quarantine", "-d", "quarantine"] }
}
```

A TCP check passes as soon as the port is open - which happens while PostgreSQL
is still running recovery and rejecting queries. `pg_isready` asks whether the
server will actually accept connections. **The difference shows up as
intermittent connection errors from clients, which is a miserable thing to
debug.**

#### Two things pinned on purpose

```hcl
image = "postgres:17.6-trixie"   # not :latest, not :17
```

Verified against Docker Hub before use: `17.6-trixie` returns HTTP 200.
**`latest` would silently change the major version on a pod restart**, and
PostgreSQL does not read a newer major version's data directory. That is a
data-loss shaped bug hiding in a convenience.

```hcl
resource "random_password" "pg" { length = 32, special = false }
```

Generated, never typed, so it is never in a shell history or on a screen -
decision D45. `special = false` avoids quoting problems inside connection
strings. **OpenTofu records it in state**, which is why `tofu/*.tfstate` is
gitignored (D13).

#### The proof that matters

Writing a manifest proves nothing. The question is whether the data survives.

```bash
kubectl -n data exec postgres-0 -- psql -U quarantine -d quarantine -c \
  "CREATE TABLE proof(...); INSERT INTO proof(note) VALUES ('written before the pod was deleted');"

kubectl -n data delete pod postgres-0          # on purpose
kubectl -n data wait --for=condition=Ready pod/postgres-0 --timeout=150s

kubectl -n data exec postgres-0 -- psql -U quarantine -d quarantine -c "SELECT * FROM proof;"
```

```
 id |                note                |              at
----+------------------------------------+-------------------------------
  1 | written before the pod was deleted | 2026-11-08 08:39:18.477432+00
```

Same row, **same timestamp**, same PVC UID
(`pvc-445a7fc9-667b-4f5a-ad76-a8e568c5b19d`), same node. So it is genuinely the
original data and not a fresh database that happens to look similar.

**Rule: a storage claim is only proven by destroying the thing that wrote the
data and finding it still there.**

### Q54. Reaching the cluster from the PC, without a tunnel

The Kubernetes OpenTofu provider runs on the PC and needs to reach the API. The
VMs are behind NAT, so normally that means a tunnel.

**Tailscale on mentat removed the need** - but the certificate was the question.

```bash
openssl s_client -connect 100.106.247.90:6443 </dev/null 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName
```
```
DNS:kubernetes, DNS:kubernetes.default, ..., DNS:localhost, DNS:mentat,
IP Address:10.10.10.11, IP Address:10.43.0.1, IP Address:127.0.0.1
```

**The Tailscale address `100.106.247.90` is NOT in the certificate.** Connecting
by address fails TLS verification.

**But `DNS:mentat` is there**, and Tailscale MagicDNS resolves it:

```bash
getent hosts mentat
# 100.106.247.90  mentat.tailed9083.ts.net
```

So using the **name** rather than the address makes TLS verify with no changes
to k3s at all:

```bash
ssh arrakis 'ssh -n muaddib@10.10.10.11 "sudo cat /etc/rancher/k3s/k3s.yaml"' > ~/.kube/arrakis.yaml
chmod 600 ~/.kube/arrakis.yaml
sd 'server: https://127.0.0.1:6443' 'server: https://mentat:6443' ~/.kube/arrakis.yaml
```

```
kubectl get nodes   ->  mentat, sietch, windtrap all Ready
```

**The alternative, avoided:** adding `tls-san: 100.106.247.90` to the k3s config
and restarting the server to reissue its certificate. That would have worked and
was unnecessary. **Read the certificate before changing the server.**

**A note on the kubeconfig.** It contains client certificates - it is a
credential. It was written straight to a file with mode 600 and never printed,
and `kubeconfig*` was added to `.gitignore`.

### Q55. OpenTofu or Argo CD? They cannot both manage the same thing

The instruction was: use OpenTofu for everything possible. That creates a
conflict worth naming.

```
Argo CD     watches Git,   makes the cluster match GIT
OpenTofu    holds state,   makes the cluster match its STATE
```

**If both manage one resource, they fight.** Argo CD reverts what OpenTofu did;
the next `tofu apply` puts it back. This is decision D11 one level up.

**The conventional split:**

```
OpenTofu    infrastructure and cluster bootstrap
Argo CD     applications, from Git
```

**What was chosen, and why:** PostgreSQL is managed by **OpenTofu** for now.
Argo CD currently manages nothing, so there is no conflict today, and iterating
with `tofu apply` is faster than commit-push-wait.

**The cost, stated plainly:** when PostgreSQL moves to Argo CD later, it must be
removed from OpenTofu's state first with `tofu state rm`, **not** destroyed. Get
that wrong and the database is deleted.

#### What OpenTofu could not do

| Thing | Provider | Decision |
|---|---|---|
| VMs | `dmacvicar/libvirt` 0.9.9 | already used |
| Kubernetes resources | `hashicorp/kubernetes` 3.5.0, **MPL-2.0** | used |
| Random password | `hashicorp/random` 3.9.1 | used |
| **OpenBao configuration** | **none exists** | the `bao` CLI instead |

**A licence check that mattered.** Decision D2 rejected Terraform because
HashiCorp relicensed it to BUSL. So `hashicorp/kubernetes` needed checking:

```bash
gh api repos/hashicorp/terraform-provider-kubernetes --jq '.license.spdx_id'
# MPL-2.0
```

**HashiCorp relicensed Terraform core, not its providers.** So this is
consistent with D2. Worth knowing rather than assuming either way.

**On OpenBao:** there is no `openbao` provider in the OpenTofu registry, and no
Terraform provider in the `openbao` GitHub organisation. The only candidate was
`hashicorp/vault` (MPL-2.0, v5.13.0), which would probably work because OpenBao
is a fork of Vault and keeps its API. **Neither project documents that
compatibility**, so it was rejected. **An undocumented assumption at the root of
trust is the wrong place to save time.**

#### Separate state, on purpose

```
tofu/          the VMs
tofu/k8s/      the cluster contents
```

Different lifetimes and different failure modes. A mistake in a Kubernetes
manifest must not be able to destroy a virtual machine.


### Q56. Redis: why a StatefulSet for "just a cache"

**Because it is not just a cache here.** The design uses **Redis Streams** as the
job queue. A queue that loses its contents on restart loses submitted jobs,
which is a different failure from a cache that has to refill.

So persistence was built in from the start. Cost: 1 GiB of a 410 GiB disk.
Cost of the alternative: recreating the resource later, under a name something
already depends on.

#### The configuration, and why each line is there

```
appendonly yes
appendfsync everysec
```
**The append-only file.** Every write is journalled, and a restart replays the
journal. Without it, Redis only snapshots periodically, so a crash loses
everything since the last snapshot. `everysec` flushes once a second - the
compromise between losing a second of writes and paying a disk sync per command.

```
maxmemory 192mb
```
**A hard ceiling, deliberately LOWER than the pod's 256Mi limit.** The ordering
matters:

```
maxmemory 192mb reached   ->  Redis evicts, under its own control
pod limit 256Mi reached   ->  the kernel kills the container, no warning
```
Leaving `maxmemory` unset means Redis grows until Kubernetes kills it. Setting it
below the pod limit means Redis handles the pressure itself.

```
maxmemory-policy allkeys-lru
```
**This one is a trap, written down because it will matter.** When the ceiling is
reached, `allkeys-lru` discards the least recently used key - **and a stream is a
key.** For a cache that is correct. **For a job queue it silently drops jobs.**

**If this Redis becomes the real queue, change it to `noeviction`,** so writes
fail loudly instead of data vanishing quietly. A loud failure can be handled; a
silent one cannot.

#### A Kubernetes behaviour worth knowing

```hcl
annotations = {
  "config-hash" = sha256(kubernetes_config_map_v1.redis.data["redis.conf"])
}
```

**Changing a ConfigMap does not restart the pods that use it.** Edit the config,
apply it, and nothing happens - the file on disk updates eventually, but the
running process never re-reads it.

Putting a hash of the config into the pod template means the template changes
when the config changes, which makes the StatefulSet roll the pod. **Without
this, a config edit appears to work and does nothing.**

#### Probes, again asking the service rather than the socket

```hcl
readiness_probe { exec { command = ["redis-cli", "ping"] } }
```

A TCP check passes as soon as the port is open. Redis opens its port **while
still loading the append-only file into memory**, and during that time it
rejects commands. On a large file that window is long. `redis-cli ping` asks the
server whether it is actually ready.

Same principle as `pg_isready` in Q53. **The pattern: a probe should ask the
application, never the socket.**

#### The proof

A stream entry, not just a key, because the stream is the part that matters:

```bash
kubectl -n data exec redis-0 -- redis-cli XADD jobs '*' task compile lang cpp
# 1794127825817-0
kubectl -n data exec redis-0 -- redis-cli BGREWRITEAOF
kubectl -n data delete pod redis-0
kubectl -n data wait --for=condition=Ready pod/redis-0 --timeout=120s
kubectl -n data exec redis-0 -- redis-cli XRANGE jobs - +
```
```
1794127825817-0
task compile lang cpp
```

**The same entry ID**, so it is the original data and not a coincidence.

`BGREWRITEAOF` was run first to force the journal to disk rather than trusting
the one-second window.

### Q57. Redpanda does not fit. The numbers, from its own documentation.

Read 2026-11-08 from `docs.redpanda.com`.

**What it requires:**

> "Each Redpanda broker must have at least 2 GB of memory per core."

> "Each Redpanda Pod requires at least 2 GiB of memory per core." And:
> "Request a minimum of 2.22 GiB per core to meet Redpanda's memory allocation
> strategy."

> "Deploy at least three Pod replicas."

> "A default StorageClass that can provision PersistentVolumes with at least
> 20Gi of storage."

> "Each production node must have at least two physical CPU cores." With
> "Four physical cores for each node are strongly recommended."

**What is available, measured the same day:**

```
free on each worker VM    about 1.4 GB
free on arrakis itself    2298 MB
real CPU cores            4
```

**The arithmetic:**

```
documented minimum   3 brokers x 2.22 GiB  =  6.7 GiB
available                                     1.4 GB per node, 2.3 GB on the host
```

**A single broker at the documented minimum does not fit in one node**, let
alone three. And the host has less free memory than one broker needs.

**The only reduced mode the docs describe** is in the quickstart, which says
plainly: "This quickstart uses Docker to run Redpanda, which is only for
development and testing purposes." Its flags are:

```
--mode dev-container
--smp 1
```

And the quickstart still states: "Make sure your machine has at least 4 GB of
free memory before starting the containers."

**The docs do not state what `dev-container` mode trades away, and do not state
its memory footprint.** So there is no documented basis for claiming it fits.

#### The conclusion, and that it was already reached once

**Redpanda is not deployed.** This is the same conclusion the original plan
reached, for the same reason - and that plan's alternative is already running:

```
Redis Streams   consumer groups, acknowledgements, replay   ~50 MB, deployed
Redpanda        the same job                                ~6.7 GiB, does not fit
```

Redis Streams were chosen because they cost nothing extra. `XADD` and `XLEN` were
exercised in Q56; consumer groups via `XGROUP` are the part still unproven.

**What would change this:**

| Change | Cost |
|---|---|
| More RAM in arrakis | hardware; 11690 MB is the current total |
| One broker, dev-container mode | undocumented footprint, "development and testing" only, and it still needs more than a node has |
| Give a VM 3 GB and run one broker | takes memory from the cluster; the host has 2298 MB free |

**The honest version: this machine is at its limit.** Three VMs plus a fourth for
OpenBao plus a cluster plus two databases is already 8704 MB of allocated guest
memory on an 11690 MB host. Redpanda is not a configuration problem; it is a
hardware one.

**This is where TODO T9 stops being optional.** zram and KSM were parked by
decision D26 on the grounds that RAM was not the binding limit. **It is now.**


### Q58. Where does observability live, and why not a new VM?

**In the cluster, as pods, on `sietch`.**

Measured 2026-11-08 before deciding:

```
mentat     1553Mi / 2894   (53%)   control plane - leave it alone
sietch      564Mi / 1967   (28%)   about 1.4 GB free  <- chosen
windtrap    537Mi / 1967   (27%)   holds postgres and redis
arrakis                            2343 MB available
```

**Why not a fifth VM.** A VM costs memory simply for being a VM - its own
kernel, systemd, sshd - roughly 200 to 250 MB before any software runs. A pod
costs nothing extra.

```
a new VM:   250 MB overhead  +  VictoriaMetrics + Grafana
pods:         0 MB overhead  +  VictoriaMetrics + Grafana
```

With 2343 MB free on the host, paying 250 MB for nothing is the wrong trade.

**And it needs to be inside to work.** VictoriaMetrics discovers what to scrape
by querying the Kubernetes API. From outside the cluster that means exposing the
kubelet and cAdvisor endpoints; from inside it is ordinary service discovery.

**This finally produces the separation that Q48 said did not exist** - and it is
produced by `nodeSelector`, not by naming:

```
mentat      control plane
windtrap    postgres, redis            (data)
sietch      victoriametrics, grafana   (observability, and apps later)
```

### Q59. VictoriaMetrics and Grafana: what each one does

**They are not alternatives. They do different jobs, and you need both.**

```
VictoriaMetrics   COLLECTS and STORES numbers over time
Grafana           DRAWS pictures from stored numbers. Stores nothing.
```

**Everyday comparison:** VictoriaMetrics is the electricity meter - it records
usage every minute and keeps the history. Grafana is the app on your phone that
shows the usage chart. The app holds no readings; delete it and the meter keeps
recording.

| | VictoriaMetrics | Grafana |
|---|---|---|
| Collects data | yes | no |
| Stores data | yes | **no** |
| Draws graphs | poorly, a debug UI | yes, that is the job |

#### Why VictoriaMetrics and not Prometheus

They do the same job. VictoriaMetrics **accepts Prometheus scrape configs and
answers PromQL queries**, so the knowledge transfers, and it uses less memory.
On a node with 1.4 GB free, that is the deciding factor.

The proof that the compatibility is real is in the Grafana datasource:

```yaml
- name: VictoriaMetrics
  type: prometheus          # <- declared as Prometheus
  url: http://victoria-metrics.observability.svc.cluster.local:8428
```

Grafana is told "this is a Prometheus" and it works, because VictoriaMetrics
speaks that API.

#### One pod, not two

From the VictoriaMetrics documentation:

> "If you use single-node VictoriaMetrics, then you can discover and scrape
> Prometheus-compatible targets directly from VictoriaMetrics without the need
> to use `vmagent`."

So no separate scraper. `vmagent` is only needed to buffer when storage is
unreachable, to relabel or filter before storing, or to send to several
backends. None apply here.

#### The flag that prevents an OOM kill

```
-memory.allowedBytes=192MB
```

**This is the most important line in the configuration.** Without it,
VictoriaMetrics sizes its internal caches from the **total system memory it can
see** - which inside a container is the **node's** memory, not the pod's limit.
It therefore allocates caches far larger than its limit allows and gets
OOM-killed.

The docs recommend leaving "50% of free RAM for reducing the probability of OOM
(out of memory) crashes". This flag is the lever that enforces that.

**The general lesson, which applies to every JVM and Go service in a
container:** a process in a container sees the host's memory unless told
otherwise. A memory limit is not a memory *setting* - the limit is enforced by
the kernel killing you, not by the program behaving.

```
-promscrape.config.strictParse=false
```
Unsupported Prometheus config keys are ignored rather than refusing to start.
Without it one unknown key stops the whole service.

```
-retentionPeriod=14d
```
The documented default is one month. Shorter here because
`ALLOWVOLUMEEXPANSION` is `false` on this storage class - the 4 GiB volume
cannot be grown, so the retention has to fit it.

#### What gets scraped, and why each job exists

| Job | What it gives |
|---|---|
| `victoria-metrics` | Itself. **Always monitor the monitor**: if this series stops, the gap in every other graph is explained. |
| `kubelet` | Per-node CPU, memory, disk, pod counts. |
| `cadvisor` | **Per-container** CPU and memory. The job that answers "which pod is eating the memory". |
| `annotated-pods` | Any pod carrying `prometheus.io/scrape: "true"`. The judge API will be picked up later with no change here. |

#### RBAC is not optional, and its absence is silent

```hcl
resources = ["nodes", "nodes/metrics", "nodes/proxy", "services", "endpoints", "pods"]
verbs     = ["get", "list", "watch"]
```

VictoriaMetrics finds targets by **asking the Kubernetes API what exists**.
Without read permission the pod starts, reports healthy, and scrapes nothing.

**That failure looks like a configuration problem and is a permissions problem.**
It is read-only and limited to the kinds discovery needs.

#### Provisioning instead of clicking

Grafana's datasource is a file in a ConfigMap, not something configured in the
UI. A datasource added by clicking lives only in Grafana's own SQLite database
and disappears if the pod is recreated. **Anything configured by clicking is
not reproducible.**

Two settings also turned off, for a private cluster:

```
GF_ANALYTICS_REPORTING_ENABLED    false
GF_ANALYTICS_CHECK_FOR_UPDATES    false
```

Grafana phones home for version and plugin news by default.

#### Versions, verified rather than assumed

```bash
curl .../v2/victoriametrics/victoria-metrics/tags/list  ->  v1.154.1 chosen
curl .../v2/grafana/grafana/tags/list                   ->  13.2.5 chosen
```

In both cases a newer tag existed (`v1.155.0`, `13.3.0`) and the one below was
taken, on the same reasoning as Argo CD in Q45: the newest release of anything
is where the regressions are found.

### Q60. An apply that was blocked, and why that was correct

`tofu apply` for this was refused by the environment:

```
Permission for this action was denied ... Reason: [Protected-Scope IaC Apply]
```

Earlier applies - the VMs, PostgreSQL, Redis - went through. **The difference is
that this plan contains cluster-scoped RBAC:**

```hcl
resource "kubernetes_cluster_role_v1" "vm"         { ... }
resource "kubernetes_cluster_role_binding_v1" "vm" { ... }
```

A `ClusterRole` grants permission across the **whole** cluster, not one
namespace. Everything applied before was namespace-scoped.

**This is a reasonable thing to stop an agent doing unattended**, and the right
response is to hand the command over rather than look for a way round it:

```bash
cd ~/Github/arrakis/tofu/k8s
tofu apply
```

`tofu plan` had already printed the full list, so nothing is hidden by handing
it over - the human types `yes` having seen the same 12 resources.

**The pattern worth keeping: write it, validate it, plan it, then hand over the
one step that needs authority.** The work is not reduced by the block; only the
final keystroke moves.


### Q61. Verifying observability actually works, and what it immediately revealed

**A pod can be `Running` and collecting nothing.** That is the failure mode RBAC
causes, so `Running` proves nothing on its own.

#### A small obstacle worth recording

The first verification attempt produced **empty output** from every command:

```bash
kubectl -n observability exec victoria-metrics-0 -- wget -qO- 'http://localhost:8428/api/v1/targets'
```

The cause was not the service. **The image has no useful HTTP client.**

```bash
kubectl -n observability exec <pod> -- sh -c 'for b in curl wget nc busybox; do command -v $b; done'
```
```
victoria-metrics-0   wget nc busybox       (busybox wget, which failed silently)
grafana-0            curl wget nc busybox
```

The fix was to query **from the Grafana pod**, which has a real `curl`, across
the cluster network:

```bash
kubectl -n observability exec grafana-0 -- curl -s \
  "http://victoria-metrics.observability.svc.cluster.local:8428/api/v1/targets?state=active"
```

**Lesson: empty output from `exec` is usually a missing tool, not a broken
service.** Container images are deliberately minimal. Check what is in the image
before concluding anything about the application. A second pod in the same
namespace is a usable client.

#### The verification that counts

```bash
VM=http://victoria-metrics.observability.svc.cluster.local:8428
kubectl -n observability exec grafana-0 -- curl -s "$VM/api/v1/targets?state=active" \
  | jq -r '.data.activeTargets[] | "\(.labels.job)\t\(.health)"' | sort | uniq -c
```
```
3 cadvisor          up
3 kubelet           up
1 victoria-metrics  up
```

Three of each, one per node, plus itself. And a query actually returning data:

```bash
kubectl -n observability exec grafana-0 -- curl -s --get \
  --data-urlencode 'query=count(up)' "$VM/api/v1/query"
# 7
```

**`count(up)` is the single most useful health check for a metrics stack.** `up`
is a series VictoriaMetrics writes for every target it scrapes: 1 for success, 0
for failure. If it returns 7 when seven targets exist, discovery, RBAC, scraping,
storage and querying are all working end to end.

#### What the first real query revealed

```promql
sum(container_memory_working_set_bytes{pod!=""}) by (namespace)
```
```
argocd           772 MiB
observability    735 MiB
kube-system      110 MiB
data              62 MiB      <- postgres AND redis together
```

**Argo CD is the single largest consumer in the cluster - more than ten times
both databases combined.** Seven pods: a server, a repo server, an application
controller, a redis, a dex server, a notifications controller and an
applicationset controller.

**And it currently manages zero applications.**

That is worth stating plainly, because it was not obvious before measuring:
`server-plan.md` budgeted 1000 MB for Argo CD and 350 MB for PostgreSQL plus
Redis. The real numbers are 772 MiB and 62 MiB. **The database estimate was
nearly 6x too high; the Argo CD estimate was about right.**

**This is the value of observability arriving before the applications.** It is
measuring its own infrastructure, and the first thing it found was that the
deployment tool costs more than everything it is meant to deploy.

#### The measured cost of observability itself

```
             before      after     cost
arrakis      2343 MB     2751 MB   (host figures move with page cache; see below)
sietch        564Mi      1059Mi    +495Mi
```

`sietch` went from 28% to 53% memory use. **Both nodes carrying workloads are
now at 53%**, with `windtrap` at 27%.

The host figure went *up* rather than down, which looks wrong and is not: host
`available` includes reclaimable page cache, and `buff/cache` rose from 2346 MB
to 2882 MB over the same period. **Host memory is not a reliable instantaneous
measure of guest cost** - the same caution as Q26 and Q41.

#### Reachable from the PC with no tunnel

```bash
curl -s -o /dev/null -w '%{http_code}' http://mentat:30300/api/health
# 200
curl -s http://mentat:30300/api/health
# {"database":"ok","version":"13.2.5","commit":"3ab9ef..."}
```

Straight from the PC's browser, over Tailscale, no port-forward and no SSH
tunnel - the payoff of decision D38 and Q54.

`"database":"ok"` is Grafana reporting that its own SQLite migrations finished,
which is what its readiness probe waits for. A TCP check would have passed
before that.


### Q62. Importing a VM that already existed, and the trap that nearly broke it

**TODO T5: bring `mentat` under OpenTofu.** It was the only VM built by hand, so
the only one that could drift - and it already had (Q22: `autostart` was never
set).

**The stakes.** `mentat`'s disk holds the k3s server, the SQLite datastore, every
Argo CD object and the cluster's certificate authority. **There is no backup.** A
plan that proposes to *replace* this resource deletes the cluster.

#### Finding the import id

```bash
tofu import libvirt_domain.mentat mentat
# the provider detected that no object exists with the given id
```

The name is not the id. The format was found by reading an existing resource:

```bash
tofu state show libvirt_domain.windtrap | grep -E '^\s+(id|name)\s+='
# id   = 5
# name = "windtrap"
```

`id = 5` is libvirt's **runtime domain number** - the one `virsh list` shows,
which changes on every restart. Not usable. The UUID worked:

```bash
tofu import libvirt_domain.mentat 26b20a4b-f903-4987-a06e-f63e4a94ae7b
# Import successful!
```

**The provider's documentation has no Import section**, so this was found by
trying the UUID after the name failed. **An import writes only state, not the
real object, so trying is safe** - and `tofu state rm` undoes it.

#### The trap: a hand-written config schedules devices for deletion

A careful hand-written `mentat.tf` was produced first, matching the live XML's
important parts - firmware, disks, interface, memory, vcpu, `smm`. The plan said:

```
# libvirt_domain.mentat will be updated in-place
Plan: 0 to add, 1 to change, 0 to destroy.
```

**"0 to destroy" looked safe. It was not.** The diff showed what the change was:

```
- clock = { offset = "utc", timer = [ rtc/catchup, pit/delay, hpet/no ] } -> null
- current_memory = 3145728 -> null
- devices.audios = [...] -> null
- devices.channels = [ org.qemu.guest_agent.0 ] -> null
- cpu.check = "none" -> null
- cpu.migratable = false -> null
```

**OpenTofu treats an omitted attribute as "this should not exist".** Everything
`virt-install` had added and the file did not mention was scheduled for removal:
the guest-agent channel, the clock timers, the audio device, the balloon.

Applying that would have stripped devices from a running control plane. **An
"update in place" can still be destructive - read the diff, not the summary
line.**

#### The right tool: generated configuration

OpenTofu can write the configuration from the live object.

```bash
tofu state rm libvirt_domain.mentat     # undo the manual attempt
rm mentat.tf

cat > mentat-import.tf <<'EOF'
import {
  to = libvirt_domain.mentat
  id = "26b20a4b-f903-4987-a06e-f63e4a94ae7b"
}
EOF

tofu plan -generate-config-out=mentat-generated.tf
```
```
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
OpenTofu has generated configuration and written it to mentat-generated.tf.
```

**`0 to change` is the number that matters.** An `import` **block** differs from
the `tofu import` **command**: the command only writes state, while the block is
part of the plan, so it can generate matching configuration first.

The result is 1212 lines, most of them `null`.

**That verbosity is not untidiness and must not be cleaned up.** Every `null` is
an explicit statement that an attribute is unset. Delete a line and OpenTofu goes
back to wanting to remove that device. **Deleting a line here does not simplify
the file; it schedules a device for removal from a running control plane.** A
header saying exactly that was put at the top of the file.

#### The result

```bash
tofu apply
# libvirt_domain.mentat: Import complete
# Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.

tofu plan
# No changes. Your infrastructure matches the configuration.
```

All four VMs are now in state, `mentat` is still running, and `autostart` is
still enabled.

#### Differences left in place deliberately

`virt-install` chose **Secure Boot** firmware - `OVMF_CODE_4M.ms.fd` with
enrolled keys, which also requires `smm`. The three OpenTofu-built VMs use the
plain `OVMF_CODE_4M.fd`.

Both work. The difference is **recorded rather than normalised**, because
changing a running machine's firmware is not a cosmetic edit. Consistency is not
worth a reboot of the control plane.

#### Two things noticed along the way

**`cp` on this PC is not `cp`.** An attempt to back up the state file produced:

```
clang++: error: no such file or directory: '/tmp/.../tfstate-before-mentat-import.json'
```

Something in the shell configuration aliases or shadows `cp`. **Worth
investigating separately** - a shell where a core command does something else is
a trap waiting for a worse moment. OpenTofu's own `terraform.tfstate.backup`
covered the gap this time.

**The import block was deleted afterwards.** Once the import is recorded in
state the block is a no-op, and `tofu plan` still reports no changes without it.


---

## 5. Documentation read, with links

Every page that produced a fact in this file. **The date is part of the
reference**: a page read on one date may say something different later.

Entries marked **(unreadable)** are recorded because the failure is itself worth
knowing - a page that cannot be fetched sends you to a different source.

### Proxmox

| Page | Read | What it gave |
|---|---|---|
| https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_13_Trixie | 2026-11-08 | Debian-on-top is a how-to, not the supported path. The Debian kernel **must** be removed. Proxmox takes over DNS. Not supported with systemd-boot plus Secure Boot. See plan.md section 7. |

### OpenTofu and its providers

| Page | Read | What it gave |
|---|---|---|
| https://opentofu.org/docs/intro/ | 2026-11-08 | "OpenTofu creates and manages resources on cloud platforms and other services through their application programming interfaces (APIs)." Proved it cannot install a hypervisor. Q3. |
| https://search.opentofu.org/provider/bpg/proxmox/latest | 2026-11-08 | **(unreadable)** - the registry builds pages with JavaScript, so a plain fetch returns only the title. Forced reading the provider's repository instead. Q3. |
| https://github.com/bpg/terraform-provider-proxmox `docs/index.md` | 2026-11-08 | Requires "Proxmox VE 9.x" and an existing API endpoint. Its example password comment reads "the-password-set-during-installation-of-proxmox-ve". Q3. |
| https://github.com/dmacvicar/terraform-provider-libvirt `docs/resources/domain.md` | 2026-11-08 | The whole v0.9.9 schema: `os`, `devices.disks`, `devices.interfaces`, `devices.consoles`, `features`, `cpu`. 12430 lines. Q23, Q25. |
| https://github.com/dmacvicar/terraform-provider-libvirt `docs/resources/volume.md` | 2026-11-08 | `backing_store`, `target.format`, `create.content.url`. Q23. |
| https://github.com/dmacvicar/terraform-provider-libvirt `docs/resources/cloudinit_disk.md` | 2026-11-08 | Builds the ISO locally and exposes `path`; must be uploaded as a volume for a remote host. Q23 error 4. |
| https://github.com/opentofu/opentofu/releases | 2026-11-08 | v1.13.9, published 2026-11-05. The project's own release API, used after a web search returned three conflicting numbers. Q19. |

**Reading these needed a workaround.** Both registries render with JavaScript, so
the authoritative text lives in the repositories:

```bash
gh api repos/<owner>/<repo>/contents/docs/resources/domain.md --jq '.content' | base64 -d
```

### Debian cloud images

| Page | Read | What it gave |
|---|---|---|
| https://cloud.debian.org/images/cloud/trixie/latest/ | 2026-11-08 | `debian-13-generic-amd64.qcow2`, 418 MB. |
| https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS | 2026-11-08 | The checksum used to verify the download. **Never take a checksum from memory.** |

### k3s

| Page | Read | What it gave |
|---|---|---|
| https://docs.k3s.io/installation/requirements | 2026-11-08 | Server 2 cores / 2 GB, agent 1 core / 512 MB, "do not include resources consumed by the workload itself". Ports 6443, 8472/UDP, 10250. Q29. |
| https://docs.k3s.io/architecture | 2026-11-08 | server vs agent definitions; node-password secret `<node-name>.node-password.k3s`; "If `/etc/rancher/node` is removed, the node should be deleted from the cluster." Q29, Q31. |
| https://docs.k3s.io/quick-start | 2026-11-08 | Install commands; `K3S_URL` makes an agent; token at `/var/lib/rancher/k3s/server/node-token`; kubeconfig at `/etc/rancher/k3s/k3s.yaml`. Q31. |
| https://docs.k3s.io/datastore | 2026-11-08 | "SQLite is the default datastore"; "SQLite cannot be used on clusters with multiple servers." Closed the uncertainty left by the architecture page. Q34. |
| https://docs.k3s.io/known-issues | 2026-11-08 | iptables 1.6.1 and 1.8.0-1.8.4 bugs; `--prefer-bundled-bin`; bundled v1.8.8. **Names no Debian release.** Q34. |
| https://docs.k3s.io/installation/configuration | 2026-11-08 | Config at `/etc/rancher/k3s/config.yaml`, drop-ins in `config.yaml.d/`; `INSTALL_K3S_EXEC`; CLI flags beat the file. Q34, Q40. |
| https://docs.k3s.io/installation/packaged-components | 2026-11-08 | The AddOns: `coredns`, `traefik`, `local-storage`, `metrics-server`, plus `servicelb`. `--disable=traefik`, comma-separated. Q34, Q37. |
| https://docs.k3s.io/cli/server | **NOT READ** | The full server-flag reference. Still outstanding. |

### Kubernetes

| Page | Read | What it gave |
|---|---|---|
| https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ | 2026-11-08 | "the workload API object used to manage stateful applications"; stable storage and identity. **Never names a database as a use case.** Q32. |
| https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/ | 2026-11-08 | Deploys **NGINX, not a database**. "Ideally, practice in a cluster that doesn't run any real workloads." Q32. |

### PostgreSQL on Kubernetes

| Page | Read | What it gave |
|---|---|---|
| https://cloudnative-pg.io/docs/current | 2026-11-08 | **(unreadable)** - returned 0 bytes. The old `/documentation/current` URL redirects here. Forced reading the repository. Q32. |
| https://github.com/cloudnative-pg/cloudnative-pg | 2026-11-08 | CNCF Landscape project, 9561 stars, v1.30.1 (2026-09-23), "manage PostgreSQL databases in Kubernetes". Q32. |

### Argo CD

| Page | Read | What it gave |
|---|---|---|
| https://argo-cd.readthedocs.io/en/stable/getting_started/ | 2026-11-08 | Install commands; "Using a pinned version ... is recommended"; secret `argocd-initial-admin-secret`; the three access methods - **NodePort is not among them**. Q45. |
| https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/ | 2026-11-08 | `install.yaml` "with cluster-admin access"; HA "multiple replicas"; Core "does not include the API server or UI". **No CPU or memory figures at all.** Q45. |
| https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/ | 2026-11-08 | gRPC and HTTP on one server; `server.insecure: "true"` in `argocd-cmd-params-cm`; the Traefik example uses an **IngressRoute CRD** with `scheme: h2c`. Also: "ingress-nginx is retired, and was archived on March 24, 2026." Q43, Q46. |
| https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/ | **NOT READ** | Local users. Needed before sharing access. TODO T16. |
| https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/ | **NOT READ** | RBAC. Needed to build a read-only account. TODO T16. |
| https://github.com/argoproj/argo-cd/releases | 2026-11-08 | v3.6.1 (2026-11-04) and v3.5.7 (2026-11-02). v3.6.0 was patched within a day, which is why v3.5.7 was pinned. Q45. |

### Tailscale

| Page | Read | What it gave |
|---|---|---|
| https://tailscale.com/kb/1084/sharing | 2026-11-08 | "access to only the shared machine in your tailnet, and nothing else"; the recipient must be "an Owner, Admin, or IT admin of a tailnet"; invites expire after 30 days. Q44. |
| https://tailscale.com/kb/1223/funnel | 2026-11-08 | "anyone to access-even if they don't use Tailscale"; **"Funnel can only listen on ports 443, 8443, and 10000"**; needs MagicDNS, HTTPS certs and a `funnel` node attribute. Q44. |
| https://tailscale.com/kb/1242/tailscale-serve | 2026-11-08 | serve is tailnet-only, funnel is public; **"only `http://127.0.0.1` is supported for proxies"**; `--bg` survives a reboot. Q44. |

### Lessons about reading documentation

1. **Read the Schema section, not the Example.** The libvirt provider's example
   used `boot_devices = ["hd"]`, which its own schema rejects. Open issue #1243:
   "Examples don't reflect updated schema". D18.
2. **Registry and documentation sites often render with JavaScript.** A plain
   fetch returns an empty page. The repository's `docs/` directory is generated
   from the code and is authoritative. This hit OpenTofu's registry *and*
   CloudNativePG.
3. **For a version number, ask the project's release API.** A web search for the
   OpenTofu version returned three conflicting answers, one of them from an
   AI-written page. Q19.
4. **The newest upstream release and what your distribution ships are different
   questions.** OpenTofu upstream was 1.13.9 while Arch packaged 1.12.1. Q19.
5. **Record what a page does NOT say.** The k3s architecture page never used the
   word "default" for SQLite; the iptables page names no Debian release; the Argo
   CD installation page gives no memory figures. Each of those gaps changed what
   had to be measured instead of assumed.

# arrakis: infrastructure plan

This repository holds the infrastructure for the host `arrakis`. The application
lives in the `quarantine` repository. This document is the single source of truth
for the host.

This document uses Simplified Technical English (ASD-STE100). Keep sentences
short. Use active voice. Write one idea in one sentence.

Last change: 2026-11-08.

## 0. Read this first: two plans disagree

Two plans exist for arrakis. They contradict each other. You must choose one
before any work starts.

| Subject | Plan A: `quarantine/server-plan.md` (2026-10-31) | Plan B: the new plan |
|---|---|---|
| Virtualisation | None. One host. | Proxmox, with 3 VMs |
| Where the sandbox runs | systemd service on the host | k3s pod with gVisor |
| Metrics store | ClickHouse + OpenTelemetry Collector | VictoriaMetrics + VictoriaLogs |
| Object storage | Cloudflare R2 (free, off-site) | Garage (on the same disk) |
| Queue | Redis Streams | Redis, with Redpanda later |
| Secrets | not decided | Sealed Secrets |

Plan A is measured. It records real tests on the real machine on 2026-10-31:
cgroup v2 delegation, user namespaces, seccomp support, and the missing `io`
controller. Plan B is a shopping list. It has no measurements.

**Recommendation: keep Plan A as the design. Take only three items from Plan B.**

Take these three:

1. `zram` and KSM. They give RAM back. They cost nothing. (KSM only helps with VMs.)
2. NetworkPolicy and RBAC. Plan A already wants network policy in phase 16.
3. Trivy in CI. It runs on your PC, not on arrakis. It costs arrakis no RAM.

Reject these, and the reason for each:

| Item | Reason to reject |
|---|---|
| Proxmox and 3 VMs | Costs about 1.2 GB of RAM for no new ability. See section 1. |
| gVisor | Adds 15 to 50 percent to each system call. Plan A section 5.5 has a 1 ms hot path. |
| VictoriaMetrics, VictoriaLogs | A second metrics store. ClickHouse already does this job. |
| Garage | Puts the backup on the same disk as the data. A backup must be off-site. R2 is free. |
| Redpanda, Kafka | Redis Streams already give consumer groups and replay. |
| OpenBao | Sealed Secrets is enough. OpenBao costs RAM. |

### Why Proxmox is the expensive choice

Proxmox splits one machine into several. You pay RAM for each split.

```
Today (Plan A):                    With Proxmox (Plan B):

+---------------------------+      +---------------------------------+
| Debian 13   kernel 6.12   |      | Proxmox host      600-800 MB    |
|                           |      |  +---------+ +------+ +-------+ |
|  k3s, postgres, redis,    |      |  | mentat  | | windtrap | |sietch | |
|  clickhouse, sandbox      |      |  | kernel  | |kernel| |kernel | |
|                           |      |  | 200 MB  | |200MB | |200 MB | |
|  usable RAM: ~10.5 GB     |      |  +---------+ +------+ +-------+ |
+---------------------------+      |  usable RAM: ~9.2 GB           |
                                   +---------------------------------+
         lost to virtualisation: about 1.2-1.5 GB
```

Plan A section 9 gives a peak of 6.25 to 8.25 GB in 11 GB. The margin is already
small. Proxmox removes most of that margin.

Proxmox buys you one real thing: a VM you can destroy and rebuild without
touching the host. You can get that with LXC containers on plain Debian, or with
k3s itself, at a fraction of the RAM.

**What Proxmox teaches you** is real and is a valid reason to want it. If you
want to learn Proxmox, say so, and we run it as a separate exercise on a
different machine or at a different time. Do not run your service on it.

### The decision

Write your choice here, then date it. Nothing below starts until this is filled.

```
Decision:  [ ] A - no virtualisation, follow server-plan.md
           [ ] B - Proxmox with 3 VMs, accept the RAM cost
Date:
```

## 1. What this repository holds

```
arrakis/
├── plan.md        this file: the decision record and the order of work
├── network/       Wi-Fi, bridges, NAT, Tailscale
├── proxmox/       only used if the decision is B
├── ansible/       configure the host: packages, users, sysctl, zram
├── bootstrap/     install k3s, Argo CD, Sealed Secrets
└── tofu/          OpenTofu, if any resource is ever declarative
```

The seam with the other repository: `bootstrap/` installs Argo CD and points it
at `github.com/<user>/quarantine`. That URL is the only shared fact.

## 2. Access: working

Verified 2026-11-08. This PC reaches arrakis over Tailscale.

```
ssh-agent   /run/user/1000/ssh-agent.socket   (systemd user agent)
key         sohail-omarchy (ED25519)
host        arrakis -> 100.114.18.44
test        ssh arrakis 'hostname' -> arrakis
```

The agent is the systemd user unit, not a shell-started one. It survives a
terminal close and a reboot, and a non-interactive shell inherits it. No change
is needed.

## 3. Your stated knowledge gap: the network

You named three things you do not know. Here is each one, short.

**wpa_supplicant** — The program that joins the laptop to Wi-Fi. It holds the
network name and the password. It talks to the Wi-Fi chip.

**vmbr0** — A network switch made of software. It lives inside the host. Virtual
machines plug into it, the same way real computers plug into a real switch.

**NAT** (Network Address Translation) — One real address, shared by many private
ones. The host rewrites the sender address on the way out, and rewrites the
receiver address on the way back.

```
  VM 10.0.0.5 --+
                |                     +---------+
  VM 10.0.0.6 --+--> vmbr0 --> NAT -->| Wi-Fi   |--> internet
                |     (switch)   (rewrite)      |
  VM 10.0.0.7 --+                     +---------+
                                   one real address
```

Everyday comparison: an office with one phone line. Each desk has an extension.
The switchboard sends every outgoing call on the one line, and remembers which
extension made it, so it can connect the answer back.

Note: `vmbr0` and NAT are needed **only for decision B**. Decision A needs
neither. Do not learn them as a blocker; learn them because you want to.

## 4. Public access with no domain

You have no domain name. Two free paths exist.

| Path | Address you get | Good for |
|---|---|---|
| Cloudflare Quick Tunnel | random `*.trycloudflare.com` | tests only; the name changes |
| Tailscale Funnel | stable `*.ts.net` | real use; you already run Tailscale |

Choose Tailscale Funnel. The address is stable and you already have the account.
Plan A section 5.4.4 names a Cloudflare Tunnel. A Cloudflare Tunnel needs a
domain in your Cloudflare account for a stable name. Funnel does not.

To check before use: Funnel exposes ports 443, 8443 and 10000 only. Confirm the
current limits in the Tailscale documentation before phase 13a.

## 5. zram and KSM: the RAM you get back

These two are the only items from the new plan that give a clear win.

**zram** — A compressed block of memory used as swap. The kernel compresses a
page instead of writing it to the disk. Text and code compress about 3 times.
Gain: about 1 to 2 GB of effective RAM.

**KSM** (Kernel Samepage Merging) — It finds identical memory pages and keeps
one copy. It helps when several guests run the same operating system. **With
decision A there is one system, so KSM gains almost nothing.** It is a
decision-B item.

Swap on the SSD stays as a safety net only. A page read from the SSD is about
100,000 times slower than a page read from RAM. Heavy swapping also wears the
drive. Kubernetes can use swap with `LimitedSwap` on cgroup v2, and Debian 13
uses cgroup v2, so this works. Treat it as a cushion for a short peak, not as
extra RAM.

## 6. The order of work

Phases 0 to 16 live in `quarantine/server-plan.md` section 11. Do not copy them
here; two copies will disagree. This repository adds only the host phases below.

| Phase | Work | Status |
|---|---|---|
| H0 | Fix SSH access from this PC to arrakis | **Done** 2026-11-08 |
| H1 | Record the decision in section 0 | Not started |
| H2 | Write the Ansible inventory and a connectivity check | Not started |
| H3 | Enable zram, measure the free RAM before and after | Not started |
| H4 | Set the lid-close behaviour. **Highest risk.** See section 10. | Not started |
| H5 | Only if decision B: install Proxmox. See section 7. | Blocked by H1 |
| H6 | Find why ccache misses 99.66 percent. See section 11. | Not started |

Phase H4 is Plan A open question 3. It is still open. A laptop that sleeps stops
the cluster. Set `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf`, or
accept the sleep.

## 7. If the decision is B: the Proxmox facts

Read before you start. Source: the Proxmox wiki page "Install Proxmox VE on
Debian 13 Trixie", last edited 2025-08-25, read on 2026-11-08.

The page says the supported path is the bare-metal ISO installer. Installing on
top of a running Debian is a documented how-to, not the supported path.

The risks, in the page's own terms:

1. **You must remove the Debian kernel.** The page: "keeping the Debian default
   kernel can lead to trouble on upgrades... Therefore, you must remove the
   default Debian kernel." arrakis runs kernel 6.12 today. You will replace it
   with `proxmox-default-kernel` and reboot.
2. **The hostname must resolve to a non-loopback address.** Check with
   `hostname --ip-address`.
3. **Proxmox takes over DNS.** The page: "The Proxmox VE GUI expects to control
   DNS management and will no longer take its DNS settings from
   /etc/network/interfaces." A package that rewrites `/etc/resolv.conf`, such as
   `resolvconf`, will break DNS. Tailscale also writes DNS settings. Check this
   interaction before you start.
4. **Not supported with systemd-boot plus Secure Boot.** Confirm which
   bootloader arrakis uses first.
5. **A ClickHouse build is in progress.** A kernel change and a reboot will
   interrupt it. Finish or stop it first.

The commands, in order, from that page:

```bash
# key
wget https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
  -O /usr/share/keyrings/proxmox-archive-keyring.gpg
# verify: sha256 136673be77aba35dcce385b28737689ad64fd785a797e57897589aed08db6e45

# repository: /etc/apt/sources.list.d/pve-install-repo.sources
# Types: deb
# URIs: http://download.proxmox.com/debian/pve
# Suites: trixie
# Components: pve-no-subscription
# Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

apt update && apt full-upgrade
apt install proxmox-default-kernel
systemctl reboot
apt install proxmox-ve postfix open-iscsi chrony
apt remove linux-image-amd64 'linux-image-6.12*'
update-grub
apt remove os-prober
```

Do not run these until section 0 holds a decision and section 7 risk 3 is
checked.

## 8. Tools

| Job | Tool | Note |
|---|---|---|
| Declarative infrastructure | OpenTofu (`tofu`) | Not Terraform. See below. |
| Host configuration | Ansible | Runs from this PC |
| Container images | Docker | Runs on this PC |
| Image scanning | Trivy | Runs in CI, not on arrakis |

OpenTofu replaces Terraform. Terraform was not dropped; HashiCorp changed its
licence from MPL-2.0 to BUSL in August 2023. OpenTofu is the fork of the last
MPL version, under the Linux Foundation. Latest release checked on 2026-11-08:
**v1.13.9** (published 2026-11-05).

`tofu` is not installed on this PC. Install it when a phase needs it:
`yay -S opentofu`.

Honest note: with one laptop and no cloud account, OpenTofu has almost nothing
to declare. The `tofu/` directory stays empty until a real resource exists. Do
not write state files for a machine you configure by hand.

## 10. Measured state of arrakis

Measured on 2026-11-08 at 01:15 IST, during a full ClickHouse build. These
numbers replace the 2026-10-31 numbers in `quarantine/server-plan.md` where they
disagree.

```
Hostname      arrakis          Debian 13 (trixie), kernel 6.12.111+deb13-amd64
CPU           i5-1135G7        4 cores, 8 threads
RAM           11690 MB total   2.4 GiB used, 9.0 GiB available DURING a build
Swap          11 GiB           on /dev/nvme0n1p3, 59 MiB used
zram          not present
Disk          456 GB           291 GB free  (was 345 GB on 2026-10-31)
cgroups       cgroup2fs        v2 confirmed
Firmware      EFI              GRUB; systemd-boot NOT installed
Temperature   52 C package     idle-to-moderate, far from the 100 C limit
Tailscale     up               100.114.18.44
```

### What is already installed

| Tool | State |
|---|---|
| Docker | 26.1.5, enabled, containerd up 23 h, 0 containers, 1 image |
| Tailscale | installed and up |
| k3s | **not installed** |
| kubectl | **not installed** |
| Ansible | **not installed** |
| Proxmox | **not installed** |

Only port 22 listens on the real interface. Nothing is exposed.

### Corrections to server-plan.md

1. **The build timer is daily, not every 15 minutes.** The unit is a *user*
   timer, `clickhouse-master-build.timer`, `OnCalendar=*-*-* 00:00:00`, with
   `Persistent=true` and a 10 minute random delay. Section 3 of server-plan.md
   and its phase 1 ("change the build timer to hourly") are already done, and
   better than planned.

2. **Open question 1 is already solved.** The build service already yields CPU
   and disk:

   ```
   Nice=19                  lowest normal priority
   CPUSchedulingPolicy=batch
   CPUWeight=20             20 against a default of 100
   IOWeight=20
   IOSchedulingClass=idle
   ```

   Under contention the build gets about one sixth of the CPU. The sandbox
   service will win. Remove open question 1.

3. **RAM is healthier than planned.** 9.0 GiB is available while four `clang++`
   processes run at 100 percent each. The plan feared a peak of 8.25 GB in
   11 GB. The margin is real.

4. **The Proxmox systemd-boot exclusion does not apply.** arrakis boots EFI with
   GRUB. `bootctl is-installed` reports no systemd-boot. Section 7 risk 4 is
   cleared. The other four risks in section 7 stand.

5. **Lid close is still unsolved and is the largest risk.** Every setting in
   `/etc/systemd/logind.conf` is still commented out:

   ```
   #HandleLidSwitch=suspend
   ```

   A commented line means the default applies, and the default is `suspend`.
   Close the lid and the whole machine stops: the build, the cluster, Tailscale,
   your SSH session. Fix this in phase H4 before anything else is deployed.

## 11. Problem found: ccache is not working

The build uses ccache. It is giving you almost nothing.

```
Cacheable calls   46430
Hits                158  ( 0.34 %)
Misses            46272  (99.66 %)
Cache size        5.4 GB of 100 GB
Cleanups           3216
```

A 0.34 percent hit rate means the cache is close to useless. ClickHouse has
about 30000 translation units in `contrib` that almost never change. Those
should hit near 100 percent. They do not.

**What ccache is:** it stores the output of each compile, with a key made from
the source, the compiler, and the flags. On the next build it returns the stored
object file instead of compiling again.

```
compile request
     |
     v
  make a key = hash(source + compiler + flags + ...)
     |
     +-- key found  --> copy the stored .o           (milliseconds)
     |
     +-- key absent --> run clang, store the .o      (seconds)
```

Everyday comparison: a photocopier with a memory. Ask for the same page twice
and it hands you the second copy instantly. Change one letter and it must scan
the page again.

**The configuration is almost entirely default.** Only `max_size` is set.

```
max_size        = 100.0 GB            (set)
base_dir        = <empty>             (default)
hash_dir        = true                (default)
compiler_check  = mtime               (default)
sloppiness      = <empty>             (default)
```

Three defaults are wrong for this build. Each one is a suspect, not yet proved.

| Setting | What it does now | Why it probably breaks the cache |
|---|---|---|
| `compiler_check = mtime` | The key includes the compiler file timestamp | Every `clang` package update invalidates the whole cache at once |
| `base_dir` empty | Absolute paths go into the key unchanged | The build runs in `~/Github/worktrees/latest-build/build_master`. If that worktree path is recreated, every key changes |
| `hash_dir = true` | The build directory path goes into the key | Same cause as above, for debug info |
| `sloppiness` empty | Maximum strictness | `__TIME__`, `__DATE__` and `__FILE__` in any header make a miss on every build |

`Cleanups = 3216` at 5 percent full is the second signal. A cleanup should not
happen in an almost-empty cache. It suggests `max_size` was raised recently,
after the cache had already thrashed at a smaller size.

### How to find the real cause

Do not change four settings at once. You will not learn which one mattered. Run
this instead, on arrakis:

```bash
# 1. is the worktree path stable between builds?
cat ~/.local/bin/ch-master-build        # read what it does to the worktree

# 2. which specific files miss, and why
CCACHE_DEBUG=1 CCACHE_DEBUGDIR=/tmp/ccdbg ccache clang++-22 -c <one file>
grep -r "Result:" /tmp/ccdbg | head

# 3. the per-reason counters
ccache -s -v | grep -iE "miss|cache hit|invalid|unsupported|preprocess"
```

Step 1 is the most likely answer. If `ch-master-build` deletes and recreates the
worktree, the absolute path changes and no key can ever match. The fix is then
one line, `base_dir = /home/muaddib/Github`, plus `hash_dir = false`.

This is the item in memory: you approved the ccache configuration on trust and
asked to be reminded to study it. This is the reminder, with evidence.

## 9. Open questions for you

1. Decision A or B. Section 0. Everything waits on this.
2. The ClickHouse build is running now, since 00:12. A reboot interrupts it.
   The timer is daily at midnight, so the next safe window is after it finishes.
3. Lid-close behaviour. Phase H4. **Answered by nothing yet; still `suspend`.**
4. Answered: SSH works. Phase H0 is done.
5. Tailscale writes DNS settings. Proxmox wants to own DNS. If the decision is
   B, this conflict needs a test.

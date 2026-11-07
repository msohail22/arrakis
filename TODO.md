# TODO

Work that is known, agreed and not yet done. Each item says why it matters and
what "done" looks like.

Order is by risk, not by size.

---

## T1. ccache misses 99.66 percent of the time

**Status:** open. Deferred by decision on 2026-11-08, to be fixed later.
**Cost of leaving it:** every midnight build recompiles ~46000 files from
scratch. Hours of CPU and SSD wear, every night, for nothing.

Measured 2026-11-08:

```
Cacheable calls   46430
Hits                158   ( 0.34 %)
Misses            46272   (99.66 %)
Cache size        5.4 GB of 100 GB
Cleanups           3216        <- should not happen in an almost-empty cache
```

Only `max_size` is configured. Everything else is default, and four defaults are
wrong for this build.

| Setting | Current | Suspected problem |
|---|---|---|
| `compiler_check` | `mtime` | Any clang package update invalidates the whole cache |
| `base_dir` | empty | Absolute paths enter the cache key unchanged |
| `hash_dir` | `true` | The build directory path enters the key |
| `sloppiness` | empty | One `__DATE__` or `__TIME__` in a header means a miss every build |

**Prime suspect:** the build runs in `~/Github/worktrees/latest-build/build_master`.
If `~/.local/bin/ch-master-build` deletes and recreates that worktree, the
absolute path changes every night and **no cache key can ever match**.

**First step when picked up** — read the build script, do not guess:

```bash
ssh arrakis 'cat ~/.local/bin/ch-master-build'
```

**Then** find which reason causes the misses, one change at a time:

```bash
ssh arrakis 'ccache -s -v | grep -iE "miss|hit|invalid|unsupported|preprocess"'
```

**Done means:** the hit rate on a second build of the same commit is above
90 percent, measured and written here with the date.

**Do not** change four settings at once. You will not learn which one mattered.

---

## T2. Fix the loopback hostname (blocker B2)

**Status:** open. Blocks a Proxmox install.

```
$ hostname --ip-address
127.0.1.1
```

Proxmox refuses to install when the machine's own name resolves to a loopback
address. The cause is the Debian default line in `/etc/hosts`.

**Prerequisite:** reserve `192.168.1.21` for arrakis in the router, or give
`wlp3s0` a static address. The current address comes from DHCP and can change.
Never write a changing address into `/etc/hosts`.

**Done means:** `hostname --ip-address` prints a non-loopback address, and the
address is reserved so it will not move.

---

## T3. Resolve the Tailscale / Proxmox DNS conflict (blocker B3)

**Status:** open. Blocks a Proxmox install.

Both want to own `/etc/resolv.conf`. Two writers, one file.

**Test, before the install, while you can still log in:**

```bash
ssh arrakis 'sudo tailscale set --accept-dns=false'
ssh arrakis 'cat /etc/resolv.conf; getent hosts github.com'
```

If name lookups still work, the conflict is gone and you keep Tailscale
addresses. You lose MagicDNS short names.

**Done means:** `/etc/resolv.conf` has one owner, and name lookups work after a
reboot.

---

## T4. Decide Proxmox, or no Proxmox (blocker B5)

**Status:** open. Everything downstream depends on it. See plan.md section 0.

---

## Done

| # | Item | Date | Proof |
|---|---|---|---|
| B1 | Lid close suspended the machine | 2026-11-08 | `busctl ... HandleLidSwitch` returns `s "ignore"` |
| H0 | SSH from the PC to arrakis | 2026-11-08 | `ssh arrakis hostname` returns `arrakis` |
| N1 | Cable or Wi-Fi decided | 2026-11-08 | Ethernet port does not work. NAT is the design. |

---
title: CPU Power Management
description: Switching the Proxmox nodes from the performance governor to powersave + balance_performance to cut idle power draw.
tags:
  - proxmox
  - power
  - hardware
---

# CPU Power Management

!!! info "Summary"
    Both Proxmox nodes shipped running the `performance` CPU governor, which kept the
    i5-13500T at ~2.3 GHz and ~18–19 W while almost idle. Switching to `powersave` with
    the `balance_performance` energy preference cut combined package power by **~15 W**
    with no loss of peak performance.

| | |
|---|---|
| **Applies to** | `pvenode1` (Dell OptiPlex Micro 7010), `pvemaster1` / `master1` (HP Pro Mini 400 G9) |
| **CPU** | Intel Core i5-13500T (14C/20T, 35 W, Tjmax 100 °C) |
| **Driver** | `intel_pstate` (active mode) |
| **Date applied** | 2026-10-15 |

---

## Background

### Governor vs. energy preference

With the `intel_pstate` driver, the CPU picks its own clock speed in hardware (HWP). Linux
controls it through two settings per thread:

| Setting | File | Values | Role |
|---|---|---|---|
| Governor | `cpufreq/scaling_governor` | `performance`, `powersave` | Whether the hardware is allowed to scale clocks down |
| Energy Performance Preference (EPP) | `cpufreq/energy_performance_preference` | `performance`, `balance_performance`, `balance_power`, `power` | How the hardware biases speed vs. efficiency |

!!! warning "`powersave` is not a speed cap"
    Under `intel_pstate`, `powersave` is a dynamic governor. Max turbo (4.6 GHz) and
    sustained throughput are unchanged; the CPU only stops holding high clocks when idle.
    The only cost is a ramp-up of a few milliseconds when work arrives.

With the `performance` governor the EPP is locked to `performance` and cannot be changed.

### Check available values

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences
```

---

## Baseline (before)

Both nodes were nearly idle (~1.5% busy) but drawing high package power. Proxmox defaults to `performance`.

```bash
turbostat --quiet --show Busy%,Bzy_MHz,PkgTmp,PkgWatt --interval 5
```

| Node | Governor | Busy% | Clocks (busy) | Package power | Package temp |
|---|---|---|---|---|---|
| `pvenode1` | `performance` | ~1.5% | ~2.3 GHz | ~18 W | 71–72 °C |
| `master1` | `performance` | ~1.7% | ~2.4 GHz | ~19 W | 56–62 °C |

---

## Change

### Apply live (resets on reboot)

```bash
echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo balance_performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
```

!!! danger "Don't mix up the files"
    `balance_performance` goes in `energy_performance_preference`, **not**
    `scaling_governor`. Writing it to the governor fails with
    `tee: ... scaling_governor: Invalid argument` (harmless, nothing changes).

### Persist with systemd

`/sys` is rebuilt on every boot, so a oneshot unit re-applies the settings.

```bash
cat > /etc/systemd/system/cpu-powersave.service <<'EOF'
[Unit]
Description=Set CPU governor to powersave

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; echo balance_performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now cpu-powersave.service
```

!!! note "`RemainAfterExit=yes`"
    Without it, `systemctl status` shows `inactive (dead)` after the unit runs. That is
    still a success (check for `status=0/SUCCESS`); the line just makes the status read
    `active (exited)` for clarity. To add it to an existing unit:

    ```bash
    sed -i '/^Type=oneshot/a RemainAfterExit=yes' /etc/systemd/system/cpu-powersave.service
    systemctl daemon-reload && systemctl restart cpu-powersave.service
    ```

---

## Results (after)

| Node | Before | After | Saved | Temp after |
|---|---|---|---|---|
| `pvenode1` | ~18 W | ~11.5 W | ~6.5 W | 69–70 °C |
| `master1` | ~19 W | ~10.7 W | ~8.3 W | 54–55 °C |
| **Total** | **~37 W** | **~22 W** | **~15 W** | |

- Busy clocks dropped to ~1.0–1.4 GHz; `Busy%` rose slightly (~2.5–3.5%), as the same work
  runs at lower clocks. Plenty of headroom remains.
- ~15 W continuous ≈ **11 kWh/month** ≈ **~10,000 COP/month** at 900 COP/kWh (Air-e).

---

## Verification

```bash
# All 20 threads should report the same values
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c

# Unit enabled and exited cleanly
systemctl status cpu-powersave.service

# Power and temperature
turbostat --quiet --show Busy%,Bzy_MHz,PkgTmp,PkgWatt --interval 5
```

Expected: `20 powersave`, `20 balance_performance`, unit `enabled`, package power ~10–12 W at idle.

### Confirm boost still works

```bash
apt install stress-ng
# Terminal 1
turbostat --quiet --show Busy%,Bzy_MHz,PkgTmp,PkgWatt --interval 2
# Terminal 2
stress-ng --cpu 20 --timeout 30s
```

`Busy%` should approach 100% and `Bzy_MHz` climb well above idle, then fall back after the test.

---

## Rollback

```bash
systemctl disable --now cpu-powersave.service
rm /etc/systemd/system/cpu-powersave.service
systemctl daemon-reload
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

---

## Notes and findings

### Package C-states

Measured on `pvenode1` after the change:

```bash
turbostat --quiet --show Busy%,Pkg%pc2,Pkg%pc6,Pkg%pc8,Pkg%pc10,PkgWatt --interval 5
```

`Pkg%pc2` < 1%, `Pkg%pc6` / `Pkg%pc8` = 0. The package almost never enters deep sleep,
because it needs all 20 threads idle at the same instant, and the Kubernetes worker VMs and
Docker containers (kubelet, containerd, VM timer ticks) keep waking threads at uncorrelated
times. This is expected for a hypervisor with this workload; **~11 W is close to the idle
floor**. PCIe ASPM (`/sys/module/pcie_aspm/parameters/policy` is `[default]`, i.e. BIOS-
configured) was not changed.

### Dell vs. HP thermals

At the same CPU, load and power (~18–19 W), the Dell OptiPlex Micro 7010 runs **10–15 °C
hotter** than the HP Pro Mini 400 G9. This is a cooling/chassis difference, not load.

- The 7010 Micro BIOS exposes **no thermal profile setting** (Optimized/Quiet/Cool/Ultra
  Performance). On this model those modes live in Dell Optimizer, which is Windows-only.
- Levers on `pvenode1`: clearance and airflow, dust cleaning, repaste, and moving CPU-heavy
  work (e.g. video decoding) off the node or onto Quick Sync.
- 70s °C sustained is safe: Tjmax is 100 °C. Use the `high`/`crit` values from `sensors`
  and each node's own baseline for alerting rather than generic numbers.

### Third node

Apply the same unit when the third node joins. This is a good candidate for the Ansible
baseline so every node gets it consistently.
# 0003 — Keep UGOS on the NAS, not TrueNAS
**Date:** TODO · **Status:** Accepted

## Context
Installed TrueNAS SCALE on a separate M.2 boot drive (dual-boot with UGOS Pro). Considered migrating the 2× 4 TB disks to a ZFS pool.

## Decision
Stay on UGOS; don't migrate the disks. TODO: record the main reason.

## Consequences
The 256 GB TrueNAS boot SSD is a candidate to wipe and use as a read-only SSD cache in UGOS. The SN700 NVMe is also still unused as cache.

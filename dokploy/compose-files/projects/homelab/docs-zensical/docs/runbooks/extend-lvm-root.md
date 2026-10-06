# Extend an Ubuntu LVM root to use the full disk

Ubuntu's installer often leaves the root LV small. `docker-dev-1` had a 150 GB disk with root using only 24 GB → image pulls failed.

```bash
lsblk                                   # see disk, partition, PV, LV sizes
sudo growpart /dev/sda 3                # grow the partition holding the PV (adjust disk/partition)
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv # ext4; use xfs_growfs / for XFS
df -h /
```

If the virtual disk itself is too small, grow it in Proxmox first (VM → Hardware → Disk → Resize), then run the above.

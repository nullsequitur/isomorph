#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <target_device>"
    echo "Example: $0 /dev/sdb"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

TARGET_DEVICE=$(realpath -- "$1")

echo "Target device set to: ${TARGET_DEVICE}"

# Ensure device exists
if [[ ! -b "$TARGET_DEVICE" ]]; then
    echo "Error: Device $TARGET_DEVICE does not exist or is not a block device."
    exit 1
fi

# Ensure device is not mounted
if lsblk -n -o MOUNTPOINT -- "$TARGET_DEVICE" | grep -q "\S"; then
    echo "Error: Device $TARGET_DEVICE has mounted partitions."
    exit 1
fi

# 1. Safety First
echo "=== WARNING ==="
echo "You are about to wipe the following device:"
lsblk -d -n -o NAME,SIZE -- "$TARGET_DEVICE"
echo "ALL DATA ON THIS DEVICE WILL BE LOST!"
read -r -p "Type 'YES' (case-sensitive) to proceed: " confirm || true

if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 0
fi

# Get total size of disk in bytes/GB for validation
TOTAL_BYTES=$(lsblk -b -d -n -o SIZE -- "$TARGET_DEVICE")
TOTAL_GB=$(( TOTAL_BYTES / 1024 / 1024 / 1024 ))

echo "Total disk capacity: ${TOTAL_GB} GB"
echo "We will create 5 partitions: BIOS Boot (1MB), EFI (512MB), Unix ISOs, Windows ISOs, Data (remaining space)."

# 2. Interactive Allocation
read -r -p "Enter size for Unix ISOs partition (in GB): " unix_size_gb || true
read -r -p "Enter size for Windows ISOs partition (in GB): " win_size_gb || true

# Basic math validation
if ! [[ "$unix_size_gb" =~ ^[1-9][0-9]*$ ]] || ! [[ "$win_size_gb" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Sizes must be strictly positive integers (greater than 0)."
    exit 1
fi

if (( unix_size_gb + win_size_gb + 1 >= TOTAL_GB )); then
    echo "Error: Combined sizes ($unix_size_gb + $win_size_gb + 1 GB for EFI) exceed or leave no room for Data on total capacity (${TOTAL_GB} GB)."
    exit 1
fi

# 3. Execution
echo "Wiping and partitioning $TARGET_DEVICE..."
parted -s -- "$TARGET_DEVICE" mklabel gpt

# Partition 1: BIOS Boot (1MB)
parted -s -- "$TARGET_DEVICE" mkpart primary 1MiB 2MiB
parted -s -- "$TARGET_DEVICE" set 1 bios_grub on

# Partition 2: EFI System (512MB)
parted -s -- "$TARGET_DEVICE" mkpart primary fat32 2MiB 514MiB
parted -s -- "$TARGET_DEVICE" set 2 esp on
parted -s -- "$TARGET_DEVICE" set 2 boot on

# Partition 3: Unix ISOs (ext4)
unix_end_mb=$(( 514 + unix_size_gb * 1024 ))
parted -s -- "$TARGET_DEVICE" mkpart primary ext4 514MiB "${unix_end_mb}MiB"

# Partition 4: Windows ISOs (NTFS)
win_end_mb=$(( unix_end_mb + win_size_gb * 1024 ))
parted -s -- "$TARGET_DEVICE" mkpart primary ntfs "${unix_end_mb}MiB" "${win_end_mb}MiB"

# Partition 5: Data (exFAT)
parted -s -- "$TARGET_DEVICE" mkpart primary ext2 "${win_end_mb}MiB" 100%

# Force kernel to reread partition table and wait for device nodes
partprobe -- "$TARGET_DEVICE"
udevadm settle

# 4. Formatting
# Determine partition suffix
if [[ "$TARGET_DEVICE" =~ [0-9]$ ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

PART1="${TARGET_DEVICE}${PART_SUFFIX}1"
PART2="${TARGET_DEVICE}${PART_SUFFIX}2"
PART3="${TARGET_DEVICE}${PART_SUFFIX}3"
PART4="${TARGET_DEVICE}${PART_SUFFIX}4"
PART5="${TARGET_DEVICE}${PART_SUFFIX}5"

echo "Formatting partitions..."
# Partition 1 is BIOS Boot, no formatting needed.

# EFI (FAT32)
mkfs.fat -F 32 -- "$PART2"

# Unix (ext4)
mkfs.ext4 -F -L UNIX_ISOS -- "$PART3"

# Windows (NTFS)
mkfs.ntfs -f -q -L WIN_ISOS -- "$PART4"

# Data (exFAT)
mkfs.exfat -n DATA -- "$PART5"

echo "Partitioning and formatting complete!"

# 5. GRUB Installation
echo "Installing GRUB..."

TEMP_MNT=$(mktemp -d)

cleanup() {
    echo "Cleaning up..."
    if mountpoint -q -- "$TEMP_MNT"; then
        if ! umount -- "$TEMP_MNT"; then
            echo "Warning: Could not unmount $TEMP_MNT. Skipping removal."
            return
        fi
    fi
    rm -rf -- "$TEMP_MNT"
}
trap cleanup EXIT

# Mount EFI partition (PART2)
mount -- "$PART2" "$TEMP_MNT"

# Create boot directory
mkdir -p "$TEMP_MNT/boot"

# Install GRUB for UEFI
echo "Installing GRUB for UEFI..."
grub-install --target=x86_64-efi --efi-directory="$TEMP_MNT" --boot-directory="$TEMP_MNT/boot" --removable -- "$TARGET_DEVICE"

# Install GRUB for BIOS (Legacy)
echo "Installing GRUB for BIOS (Legacy)..."
grub-install --target=i386-pc --boot-directory="$TEMP_MNT/boot" -- "$TARGET_DEVICE"

echo "GRUB installation complete!"

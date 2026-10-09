#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <block_device>" >&2
    exit 1
fi

RAW_DEV="$1"
if [[ ! -b "${RAW_DEV}" ]]; then
    echo "Error: ${RAW_DEV} is not a valid block device." >&2
    exit 1
fi

TARGET_DEV=$(realpath -- "${RAW_DEV}")

# Resolve partition suffix logic
if [[ "${TARGET_DEV}" =~ [0-9]$ ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

EFI_PART="${TARGET_DEV}${PART_SUFFIX}2"
UNIX_PART="${TARGET_DEV}${PART_SUFFIX}3"
WINDOWS_PART="${TARGET_DEV}${PART_SUFFIX}4"

for part in "${EFI_PART}" "${UNIX_PART}" "${WINDOWS_PART}"; do
    if [[ ! -b "${part}" ]]; then
        echo "Error: Partition ${part} does not exist." >&2
        exit 1
    fi
done

EFI_MNT=$(mktemp -d)
UNIX_MNT=$(mktemp -d)
WINDOWS_MNT=$(mktemp -d)

cleanup() {
    echo "Cleaning up..."
    for mnt in "${EFI_MNT}" "${UNIX_MNT}" "${WINDOWS_MNT}"; do
        if [[ -n "${mnt:-}" ]] && [[ -d "${mnt}" ]]; then
            if mountpoint -q -- "${mnt}"; then
                if ! umount -- "${mnt}"; then
                    echo "Warning: Could not unmount ${mnt}. Skipping removal."
                    continue
                fi
            fi
            rm -rf -- "${mnt}"
        fi
    done
}
trap cleanup EXIT ERR

echo "Mounting partitions..."
mount -- "${EFI_PART}" "${EFI_MNT}"
mount -- "${UNIX_PART}" "${UNIX_MNT}"
mount -- "${WINDOWS_PART}" "${WINDOWS_MNT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Updating EFI partition (grub configuration)..."
mkdir -p "${EFI_MNT}/boot/grub"
cp -- "${SCRIPT_DIR}/grub.cfg" "${EFI_MNT}/boot/grub/"
cp -- "${SCRIPT_DIR}/entries.cfg" "${EFI_MNT}/boot/grub/"

echo "Updating Unix partition..."
if [[ -d "${SCRIPT_DIR}/payload/unix/" ]]; then
    rsync -av -- "${SCRIPT_DIR}/payload/unix/" "${UNIX_MNT}/"
else
    echo "Warning: ${SCRIPT_DIR}/payload/unix/ does not exist. Skipping."
fi

echo "Updating Windows partition..."
if [[ -d "${SCRIPT_DIR}/payload/windows/" ]]; then
    rsync -av -- "${SCRIPT_DIR}/payload/windows/" "${WINDOWS_MNT}/"
else
    echo "Warning: ${SCRIPT_DIR}/payload/windows/ does not exist. Skipping."
fi

echo "Update complete."

#!/bin/bash
# silen-gpu-check — diagnose black-screen / KMS failures.
# Usage: silen-gpu-check [output-file]
# Mirrors scripts/wifi-check.sh: collects GPU, DRM, firmware and boot
# state into one log the user can paste into a bug report. Safe to run
# from the live ISO (fallback nomodeset boot) or the installed system.

out="${1:-/dev/stdout}"

{
echo "===== silen-gpu-check ====="
echo "date ---"
date 2>/dev/null || true
echo "kernel/cmdline ---"
uname -r 2>/dev/null || true
cat /proc/cmdline 2>/dev/null || echo "/proc/cmdline unreadable"
echo "nomodeset present? ---"
if grep -qw nomodeset /proc/cmdline 2>/dev/null; then
    echo "YES (safe-graphics mode, KMS disabled by request)"
else
    echo "no (KMS enabled, expected path)"
fi
echo "PCI GPUs ---"
if command -v lspci >/dev/null 2>&1; then
    lspci -k 2>/dev/null | grep -iEA3 "vga|3d|display" || echo "no VGA/3D/display devices shown"
else
    echo "lspci unavailable"
    for d in /sys/bus/pci/devices/*; do
        [ -f "$d/class" ] || continue
        case "$(cat "$d/class" 2>/dev/null)" in
            0x03*) _drv="$(basename "$(readlink "$d/driver" 2>/dev/null)" 2>/dev/null)"; echo "$(basename "$d"): class $(cat "$d/class" 2>/dev/null) vendor=$(cat "$d/vendor" 2>/dev/null) device=$(cat "$d/device" 2>/dev/null) driver=${_drv:-none}" ;;
        esac
    done
fi
echo "loaded DRM/GPU modules ---"
if command -v lsmod >/dev/null 2>&1; then
    lsmod 2>/dev/null | grep -iE "^(amdgpu|radeon|i915|xe|nouveau|nvidia|nvidia_drm|nvidia_modeset|drm|drm_kms_helper|ttm|video|wmi|backlight|virtio_gpu|qxl|vmwgfx|ast|mgag200)" || echo "no DRM/GPU modules loaded"
else
    echo "lsmod unavailable"
fi
echo "DRM devices ---"
ls -l /dev/dri/ 2>/dev/null || echo "no /dev/dri (KMS driver did not create outputs)"
echo "framebuffers/consoles ---"
ls /sys/class/graphics/ 2>/dev/null || echo "/sys/class/graphics missing"
cat /sys/class/graphics/fb0/name 2>/dev/null || true
echo "firmware on disk ---"
for _fw in amdgpu i915 xe radeon; do
    if [ -d "/lib/firmware/$_fw" ]; then
        echo "$_fw: $(ls "/lib/firmware/$_fw" 2>/dev/null | wc -l) files"
    else
        echo "$_fw: MISSING (black-screen likely on this hardware)"
    fi
done
ls -d /lib/firmware/amd-ucode /lib/firmware/intel-ucode 2>/dev/null || echo "no CPU microcode dirs (ok if distro ships them elsewhere)"
echo "kernel DRM/firmware messages ---"
if command -v dmesg >/dev/null 2>&1; then
    dmesg 2>/dev/null | grep -iE "drm|fbcon|vga|framebuffer|simpledrm|efifb|amdgpu|radeon|i915|xe|nouveau|nvidia|firmware.*(fail|error|missing|not found|direct.*load)|modeset|blacklist|taint" | tail -n 60 || echo "no DRM/firmware lines in dmesg"
else
    echo "dmesg unavailable"
fi
echo "X/Wayland greeters ---"
if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active sddm gdm lightdm 2>/dev/null || true
fi
for _svc in sddm gdm lightdm; do
    if [ -f "/etc/init.d/$_svc" ]; then
        echo "$_svc openrc service present"
    fi
done || true
ls /usr/bin/Sway /usr/bin/gnome-shell /usr/bin/plasmashell /usr/bin/Xorg 2>/dev/null || echo "no DE binaries in /usr/bin (console-only install?)"
echo "modprobe GPU config ---"
cat /etc/modprobe.d/nvidia.conf 2>/dev/null || echo "no /etc/modprobe.d/nvidia.conf"
grep -ri "nouveau\|nvidia\|amdgpu\|i915" /etc/modprobe.d/ 2>/dev/null | head -n 20 || echo "no GPU lines in /etc/modprobe.d"
echo "bootloader cmdline ---"
grep -h "linux " /boot/grub/grub.cfg 2>/dev/null || echo "/boot/grub/grub.cfg unreadable"
echo "===== end ====="
echo "hint: boot the 'fallback, safe graphics' GRUB entry, then run:"
echo "  silen-gpu-check /tmp/silen-gpu.log"
echo "and share /tmp/silen-gpu.log plus 'lspci -k' output."
} > "$out" 2>&1
[ "$out" != "/dev/stdout" ] && echo "wrote $out"

setup-grub() {
    if [ -f /mnt/boot/vmlinuz ]; then
        if ! cp /mnt/boot/vmlinuz "$root"/boot/vmlinuz 2>/dev/null; then
            whiptail --msgbox --title "$title" "couldn't copy the kernel" 8 40 || true
            return 1
        fi
    else
        whiptail --msgbox --title "$title" "no kernel found on the install medium" 8 40 || true
        return 1
    fi
    initramfs_name=""
    for i in /mnt/boot/initramfs.*; do
        [ -f "$i" ] || continue
        if cp "$i" "$root"/boot/ 2>/dev/null; then
            initramfs_name="$(basename "$i")"
            break
        fi
    done || true
    if [ -z "$initramfs_name" ]; then
        whiptail --msgbox --title "$title" "no initramfs found in the install ISO" 8 40 || true
        return 1
    fi

    if [ ! -d /sys/firmware/efi ]; then
        whiptail --msgbox --title "$title" "this machine booted in legacy mode, but Silen can currently only install an EFI bootloader. Boot the iso in UEFI mode and try again." 10 60 || true
        return 1
    fi

    if [ -d /mnt/grub/usr/local ]; then
        mkdir -p "$root"/usr/local
        cp -a /mnt/grub/usr/local/. "$root"/usr/local/ 2>/dev/null || { whiptail --msgbox --title "$title" "couldn't copy bundled GRUB" 8 40 || true; }
    fi

    mkdir -p "$root/tmp" 2>/dev/null || true
    if chroot "$root" /bin/bash -c "PATH=/usr/local/sbin:/usr/local/bin:\$PATH LD_LIBRARY_PATH=/usr/local/lib /usr/local/sbin/grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --removable" >"$root/tmp/grub-install.log" 2>&1 || chroot "$root" /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --removable" >>"$root/tmp/grub-install.log" 2>&1; then
        cp "$root/tmp/grub-install.log" /tmp/grub-install.log 2>/dev/null || true
        if [ ! -f "$root"/boot/grub/fonts/unicode.pf2 ]; then
            for _pf2 in /mnt/grub/usr/local/share/grub/unicode.pf2 \
                         /usr/local/share/grub/unicode.pf2 \
                         /usr/share/grub/unicode.pf2; do
                if [ -f "$_pf2" ]; then
                    mkdir -p "$root"/boot/grub/fonts 2>/dev/null || true
                    cp "$_pf2" "$root"/boot/grub/fonts/unicode.pf2 2>/dev/null || true
                    break
                fi
            done || true
        fi
        # RELIABLE-VIDEO 2026-09-21 — KMS stays ON by default. `nomodeset`
        # as a default would "fix" black screens by disabling all hardware
        # graphics (no accel, wrong resolution, Wayland broken) — a cheap
        # workaround, not a fix, and against "reliable by default".
        # Instead: fbcon=nodefer binds the console even with deferred
        # probes (classic AMD black-screen), gfxpayload=keep hands the GOP
        # framebuffer to the kernel so there is never a dead gap between
        # GRUB and KMS, and the nomodeset entry below remains as SAFE MODE
        # (rootfs/init skips every DRM/GPU module when it sees it).
        # NOTE: 'set gfxpayload=text' is invalid on UEFI ('invalid video
        # mode specification', blind mode) — 'keep' is the correct value.
        # On proprietary-NVIDIA targets also blacklist nouveau on the
        # cmdline: the reused live initramfs loads modules before the
        # target's /etc/modprobe.d exists, so without this nouveau binds
        # first and nvidia fails -> black.
        _video_extra=""
        case "${driver_choice:-none}" in
            nvidia|nvidia-legacy) _video_extra=" modprobe.blacklist=nouveau" ;;
        esac
        cat > "$root"/boot/grub/grub.cfg <<EOF
set default=0
set timeout=10

insmod part_gpt
insmod part_msdos
insmod fat
insmod ext2
insmod search_fs_uuid
insmod all_video
insmod gfxterm
insmod efi_gop
insmod efi_uga
if loadfont \$prefix/fonts/unicode.pf2; then
    set gfxmode=auto
fi
# console fallback: if gfxterm dies the menu is still usable (never black).
set gfxpayload=keep
terminal_output gfxterm console
search --no-floppy --fs-uuid --set=root $bootuuid

menuentry "Silen Linux" {
    linux /vmlinuz root=UUID=$rootuuid ro rootwait loglevel=4 console=tty0 fbcon=nodefer$_video_extra
    initrd /$initramfs_name
}

menuentry "Silen Linux (quiet)" {
    linux /vmlinuz root=UUID=$rootuuid ro quiet loglevel=3 console=tty0 fbcon=nodefer$_video_extra
    initrd /$initramfs_name
}

menuentry "Silen Linux (fallback, safe graphics)" {
    linux /vmlinuz root=UUID=$rootuuid ro rootwait nomodeset loglevel=4 console=tty0 fbcon=nodefer
    initrd /$initramfs_name
}

menuentry "Silen Linux (verbose, debug video)" {
    linux /vmlinuz root=UUID=$rootuuid ro rootwait loglevel=7 console=tty0 fbcon=nodefer drm.debug=0x1e$_video_extra
    initrd /$initramfs_name
}
EOF
        whiptail --msgbox --title "$title" "GRUB is installed" 8 40 || true
    else
        cp "$root/tmp/grub-install.log" /tmp/grub-install.log 2>/dev/null || true
        whiptail --msgbox --title "$title" "grub-install failed, see /tmp/grub-install.log for errors" 8 40 || true
        return 1
    fi
}

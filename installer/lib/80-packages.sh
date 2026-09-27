install-wifi() {
    [ "$INSTALL_MODE" = "online" ] || return 0
    [ -n "${want_wifi:-}" ] || return 0
    if [ ! -x "$root"/usr/bin/nmtui ] && [ ! -x "$root"/usr/bin/nmcli ]; then
        whiptail --msgbox --title "$title" "NetworkManager not available, skipping Wi-Fi setup" 8 50 || true
        return 0
    fi
    whiptail --msgbox --title "$title" "Wi-Fi will be configured on first boot via nmtui. After reboot, run 'nmtui' as root to connect." 8 60 || true
    chroot "$root" /bin/bash -c "rc-update add dbus default" >/dev/null 2>&1 || true
    chroot "$root" /bin/bash -c "rc-update add wpa_supplicant default" >/dev/null 2>&1 || true
    chroot "$root" /bin/bash -c "rc-update add NetworkManager default" >/dev/null 2>&1 || true

    whiptail --infobox --title "$title" "Installing Wi-Fi drivers linux-firmware" 8 50 2>/dev/null || true
    ensure-firmware

    for pkg in rtl8822ce iwlwifi mt7921 ath11k brcmfmac rtw89; do
        chroot "$root" /bin/bash -c "spk get $pkg" 2>>"$root/tmp/spk-wifi-install.log" || true
    done
}

ensure-firmware() {
    [ "$INSTALL_MODE" = "online" ] || return 0
    [ -f "$root/tmp/.spk-firmware-done" ] && return 0
    mkdir -p "$root/tmp" 2>/dev/null || true
    # NOTE: linux-firmware is not packaged in the spk repo (yet), so this
    # refresh is best-effort — the ISO already seeded /lib/firmware on the
    # target via install-modules. Only warn when the seed is missing too,
    # otherwise a guaranteed-404 would scare every online user.
    whiptail --infobox --title "$title" "Refreshing firmware (linux-firmware) if available" 8 60 2>/dev/null || true
    if chroot "$root" /bin/bash -c "spk get linux-firmware" 2>"$root/tmp/spk-firmware.log"; then
        touch "$root/tmp/.spk-firmware-done" 2>/dev/null || true
    else
        _seeded=""
        for _g in amdgpu i915 xe radeon; do
            if [ -d "$root/lib/firmware/$_g" ] && [ -n "$(ls -A "$root/lib/firmware/$_g" 2>/dev/null)" ]; then
                _seeded="1"
                break
            fi
        done || true
        if [ -z "$_seeded" ]; then
            whiptail --msgbox --title "$title" "linux-firmware is not available via spk and no GPU firmware came from the install medium. Normal boot may black-screen on AMD/Intel graphics. Details in /tmp/spk-firmware.log after reboot." 9 70 || true
        fi
    fi
}

install-drivers() {
    [ "$INSTALL_MODE" = "online" ] || return 0
    # RELIABLE-VIDEO: firmware is not optional. KMS (amdgpu/i915/xe/radeon)
    # refuses to modeset without /lib/firmware blobs -> black screen. The
    # ISO already seeds them via install-modules, but online installs
    # refresh to the latest linux-firmware via spk so new GPUs work too.
    # Always fetch on online installs, no matter which driver was picked
    # (even "Skip" — the user still boots with KMS on the console).
    ensure-firmware
    case "${driver_choice:-none}" in
        nvidia)
            chroot "$root" /bin/bash -c "spk get nvidia" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install nvidia via spk Run spk get nvidia after boot" 8 70 || true
            mkdir -p "$root"/etc/modprobe.d
            cat > "$root"/etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia NVreg_UsePageAttributeTable=1
options nvidia_drm modeset=1
blacklist nouveau
blacklist lbm-nouveau
alias nouveau off
alias lbm-nouveau off
EOF
            printf 'nvidia\nnvidia_drm\nnvidia_modeset\nnvidia_uvm\n' > "$root"/etc/modules-load.d/nvidia.conf 2>/dev/null || true
            ;;
        nvidia-legacy)
            chroot "$root" /bin/bash -c "spk get nvidia-legacy" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install nvidia-legacy via spk Run spk get nvidia-legacy after boot" 8 70 || true
            mkdir -p "$root"/etc/modprobe.d
            cat > "$root"/etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia NVreg_UsePageAttributeTable=1
options nvidia_drm modeset=1
blacklist nouveau
blacklist lbm-nouveau
alias nouveau off
alias lbm-nouveau off
EOF
            printf 'nvidia\nnvidia_drm\nnvidia_modeset\nnvidia_uvm\n' > "$root"/etc/modules-load.d/nvidia.conf 2>/dev/null || true
            ;;
        amd)
            chroot "$root" /bin/bash -c "spk get amd" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install AMD drivers via spk (package: amd)" 8 70 || true
            mkdir -p "$root/etc/modules-load.d" 2>/dev/null || true
            printf 'amdgpu\n' > "$root"/etc/modules-load.d/amdgpu.conf 2>/dev/null || true
            ;;
        intel)
            # No standalone mesa/intel package in the repo; xorg-server
            # ships the modesetting driver, which is what Intel needs.
            chroot "$root" /bin/bash -c "spk get xorg-server" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install Intel graphics via spk (package: xorg-server)" 8 70 || true
            mkdir -p "$root/etc/modules-load.d" 2>/dev/null || true
            printf 'i915\n' > "$root"/etc/modules-load.d/intel.conf 2>/dev/null || true
            ;;
        vmware)
            # No vmware package in the repo; xorg-server's fbdev/vesa
            # drivers give a working (unaccelerated) display in a VM.
            chroot "$root" /bin/bash -c "spk get xorg-server" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install VMware graphics via spk (package: xorg-server)" 8 70 || true
            mkdir -p "$root/etc/modules-load.d" 2>/dev/null || true
            printf 'vmwgfx\n' > "$root"/etc/modules-load.d/vmwgfx.conf 2>/dev/null || true
            ;;
        none|*)
            # User skipped the GPU question but still boots with KMS — and a
            # DE needs a display server. There is no standalone mesa
            # package in the repo, so install xorg-server as the neutral
            # base (modesetting/fbdev/vesa cover AMD/Intel/VMs and nouveau
            # on NVIDIA); otherwise "Skip" with a DE means no GUI at all.
            if [ -n "${want_de:-}" ] && [ "${de_choice:-none}" != "none" ]; then
                whiptail --infobox --title "$title" "Installing base graphics (xorg-server) for the desktop" 8 50 2>/dev/null || true
                chroot "$root" /bin/bash -c "spk get xorg-server" 2>/dev/null || \
                    whiptail --msgbox --title "$title" "Failed to install xorg-server via spk — the desktop may not start. Run spk get xorg-server after boot." 8 70 || true
            fi
            ;;
    esac
}

install-gpu-drivers-choice() {
    whiptail --msgbox --title "$title" "After install, choose your GPU drivers.\nCheck spk_pkgs for exact package names." 8 60 || true
    gpu_choice=$(whiptail --title "$title" --menu "Select GPU driver" 14 50 6 \
        "nvidia" "NVIDIA (spk: nvidia)" \
        "nvidia-legacy" "NVIDIA Legacy (spk: nvidia-legacy)" \
        "amd" "AMD (spk: amd)" \
        "intel" "Intel (spk: xorg-server)" \
        "none" "Skip" \
        3>&1 1>&2 2>&3 || true)
    [ -z "$gpu_choice" ] && return
    case "$gpu_choice" in
        nvidia)
            chroot "$root" /bin/bash -c "spk get nvidia" 2>/dev/null || true
            ;;
        nvidia-legacy)
            chroot "$root" /bin/bash -c "spk get nvidia-legacy" 2>/dev/null || true
            ;;
        amd)
            chroot "$root" /bin/bash -c "spk get amd" 2>/dev/null || true
            ;;
        intel)
            chroot "$root" /bin/bash -c "spk get xorg-server" 2>/dev/null || true
            ;;
        none)
            return 0
            ;;
    esac
    whiptail --msgbox --title "$title" "GPU drivers installed Reboot to use them" 8 40 || true
}

install-desktop() {
    [ "$INSTALL_MODE" = "online" ] || return 0
    [ -n "${want_de:-}" ] || return 0
    [ "${de_choice:-none}" = "none" ] && return 0

    case "${de_choice}" in
        kde)
            chroot "$root" /bin/bash -c "spk get kde" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install KDE Plasma via spk (package: kde)" 8 76 || true
            ;;
        gnome)
            chroot "$root" /bin/bash -c "spk get gnome" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install GNOME via spk (package: gnome)" 8 70 || true
            ;;
        xfce)
            chroot "$root" /bin/bash -c "spk get xfce4" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install XFCE via spk (package: xfce4)" 8 70 || true
            ;;
        i3)
            chroot "$root" /bin/bash -c "spk get i3 i3status dmenu rxvt-unicode" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install i3 via spk" 8 70 || true
            ;;
        sway)
            chroot "$root" /bin/bash -c "spk get sway waybar wofi foot" 2>/dev/null || \
                whiptail --msgbox --title "$title" "Failed to install Sway via spk" 8 70 || true
            ;;
    esac

    case "${dm_choice:-}" in
        sddm)
            if chroot "$root" /bin/bash -c "spk get sddm" 2>/dev/null; then
                chroot "$root" /bin/bash -c "rc-update add sddm default" 2>/dev/null || true
            else
                whiptail --msgbox --title "$title" "Failed to install SDDM via spk" 8 70 || true
            fi
            if [ -n "${newuser:-}" ]; then
                mkdir -p "$root"/etc/sddm.conf.d
                _sddm_session="plasma"
                case "${de_choice:-none}" in
                    i3) _sddm_session="i3" ;;
                    sway) _sddm_session="sway" ;;
                    xfce) _sddm_session="xfce" ;;
                    gnome) _sddm_session="gnome" ;;
                esac
                cat > "$root"/etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=$newuser
Session=$_sddm_session
EOF
            fi
            ;;
        gdm)
            if chroot "$root" /bin/bash -c "spk get gdm" 2>/dev/null; then
                chroot "$root" /bin/bash -c "rc-update add gdm default" 2>/dev/null || true
            else
                whiptail --msgbox --title "$title" "Failed to install GDM via spk" 8 70 || true
            fi
            ;;
        lightdm)
            if chroot "$root" /bin/bash -c "spk get lightdm lightdm-gtk-greeter" 2>/dev/null; then
                chroot "$root" /bin/bash -c "rc-update add lightdm default" 2>/dev/null || true
            else
                whiptail --msgbox --title "$title" "Failed to install LightDM via spk (not in the repo yet)" 8 70 || true
            fi
            ;;
        ly)
            if chroot "$root" /bin/bash -c "spk get ly" 2>/dev/null; then
                chroot "$root" /bin/bash -c "rc-update add ly default" 2>/dev/null || true
            else
                whiptail --msgbox --title "$title" "Failed to install ly via spk" 8 70 || true
            fi
            ;;
    esac

    if chroot "$root" /bin/bash -c "command -v elogind >/dev/null 2>&1 || test -f /etc/init.d/elogind" >/dev/null 2>&1; then
        chroot "$root" /bin/bash -c "rc-update add elogind boot" >/dev/null 2>&1 || \
        chroot "$root" /bin/bash -c "rc-update add elogind default" >/dev/null 2>&1 || true
    fi
}

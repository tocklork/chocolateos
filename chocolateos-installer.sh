#!/bin/bash
# ╔══════════════════════════════════════════╗
# ║   ChocolateOS Installer v1.0             ║
# ║   arch-based install script              ║
# ╚══════════════════════════════════════════╝
# run from arch live iso as root

set -e

# ── colors ────────────────────────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ── helpers ───────────────────────────────────────────────────────────────────
header() {
    clear
    echo -e "${M}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   🍫  ChocolateOS Installer v1.0         ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${N}"
}

step() {
    echo -e "\n${C}──────────────────────────────────────${N}"
    echo -e "${W}  $1${N}"
    echo -e "${C}──────────────────────────────────────${N}\n"
}

info()    { echo -e "${B}  →  $1${N}"; }
success() { echo -e "${G}  ✓  $1${N}"; }
warn()    { echo -e "${Y}  !  $1${N}"; }
error()   { echo -e "${R}  ✗  $1${N}"; exit 1; }

confirm() {
    echo -e "${Y}  $1 [y/N]: ${N}\c"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

pause() {
    echo -e "\n${Y}  press enter to continue...${N}"
    read -r
}

# ── check root ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${R}run this script as root${N}"
    exit 1
fi

# ── check internet ────────────────────────────────────────────────────────────
header
step "checking internet connection..."
if ! ping -c 1 archlinux.org &>/dev/null; then
    error "no internet connection. connect first and re-run."
fi
success "internet ok"
pause

# ══════════════════════════════════════════════════════════════════════════════
# 1. DISK SELECTION
# ══════════════════════════════════════════════════════════════════════════════
header
step "disk selection"

warn "available disks:"
echo ""
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk
echo ""

while true; do
    echo -e "${Y}  enter disk to install on (e.g. sda, nvme0n1): ${N}\c"
    read -r DISK_NAME
    DISK="/dev/$DISK_NAME"
    if [[ -b "$DISK" ]]; then
        break
    fi
    warn "disk $DISK not found, try again"
done

echo ""
warn "current partition layout of $DISK:"
lsblk "$DISK"
echo ""

warn "⚠️  ALL DATA ON $DISK WILL BE DESTROYED ⚠️"
if ! confirm "are you sure you want to use $DISK?"; then
    error "aborted by user"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. PARTITION SCHEME
# ══════════════════════════════════════════════════════════════════════════════
header
step "partition scheme"

echo -e "  ${W}choose partition layout:${N}"
echo -e "  ${C}1)${N} automatic (recommended) — EFI + swap + root"
echo -e "  ${C}2)${N} manual — open cfdisk yourself"
echo ""
echo -e "${Y}  choice [1/2]: ${N}\c"
read -r PART_CHOICE

if [[ "$PART_CHOICE" == "2" ]]; then
    cfdisk "$DISK"
    echo ""
    warn "current layout after manual partition:"
    lsblk "$DISK"
    echo ""
    echo -e "${Y}  enter EFI partition (e.g. sda1, nvme0n1p1): ${N}\c"
    read -r EFI_PART_NAME
    EFI_PART="/dev/$EFI_PART_NAME"

    echo -e "${Y}  enter root partition (e.g. sda2, nvme0n1p2): ${N}\c"
    read -r ROOT_PART_NAME
    ROOT_PART="/dev/$ROOT_PART_NAME"

    echo -e "${Y}  enter swap partition (leave blank to skip): ${N}\c"
    read -r SWAP_PART_NAME
    SWAP_PART="${SWAP_PART_NAME:+/dev/$SWAP_PART_NAME}"
else
    # automatic partitioning
    step "automatic partitioning"

    echo -e "${Y}  enter swap size in GB (e.g. 4, or 0 to skip): ${N}\c"
    read -r SWAP_SIZE

    info "wiping disk..."
    wipefs -af "$DISK"
    sgdisk -Z "$DISK"

    info "creating partitions..."
    # EFI: 512MB
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"

    if [[ "$SWAP_SIZE" -gt 0 ]]; then
        # swap
        sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"swap" "$DISK"
        # root: rest
        sgdisk -n 3:0:0 -t 3:8300 -c 3:"root" "$DISK"
        # figure out partition naming (nvme uses p1/p2/p3, sata uses 1/2/3)
        if [[ "$DISK" == *"nvme"* ]]; then
            EFI_PART="${DISK}p1"
            SWAP_PART="${DISK}p2"
            ROOT_PART="${DISK}p3"
        else
            EFI_PART="${DISK}1"
            SWAP_PART="${DISK}2"
            ROOT_PART="${DISK}3"
        fi
    else
        # root: rest (no swap)
        sgdisk -n 2:0:0 -t 2:8300 -c 2:"root" "$DISK"
        SWAP_PART=""
        if [[ "$DISK" == *"nvme"* ]]; then
            EFI_PART="${DISK}p1"
            ROOT_PART="${DISK}p2"
        else
            EFI_PART="${DISK}1"
            ROOT_PART="${DISK}2"
        fi
    fi

    success "partitions created"
    lsblk "$DISK"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. FILESYSTEM
# ══════════════════════════════════════════════════════════════════════════════
header
step "formatting partitions"

echo -e "  ${W}choose root filesystem:${N}"
echo -e "  ${C}1)${N} ext4   — stable, widely supported (recommended for beginners)"
echo -e "  ${C}2)${N} btrfs  — snapshots, compression, good with timeshift"
echo -e "  ${C}3)${N} xfs    — fast, good for large files"
echo ""
echo -e "${Y}  choice [1/2/3]: ${N}\c"
read -r FS_CHOICE

info "formatting EFI partition as FAT32..."
mkfs.fat -F32 "$EFI_PART"

case "$FS_CHOICE" in
    2)
        FS_TYPE="btrfs"
        info "formatting root as btrfs..."
        mkfs.btrfs -f "$ROOT_PART"
        info "creating btrfs subvolumes..."
        mount "$ROOT_PART" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        umount /mnt
        info "mounting btrfs subvolumes..."
        mount -o subvol=@,compress=zstd "$ROOT_PART" /mnt
        mkdir -p /mnt/{home,.snapshots}
        mount -o subvol=@home,compress=zstd "$ROOT_PART" /mnt/home
        mount -o subvol=@snapshots,compress=zstd "$ROOT_PART" /mnt/.snapshots
        ;;
    3)
        FS_TYPE="xfs"
        info "formatting root as xfs..."
        mkfs.xfs -f "$ROOT_PART"
        mount "$ROOT_PART" /mnt
        ;;
    *)
        FS_TYPE="ext4"
        info "formatting root as ext4..."
        mkfs.ext4 -F "$ROOT_PART"
        mount "$ROOT_PART" /mnt
        ;;
esac

if [[ -n "$SWAP_PART" ]]; then
    info "setting up swap..."
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

success "partitions formatted and mounted"

# ══════════════════════════════════════════════════════════════════════════════
# 4. LOCALE / TIMEZONE / HOSTNAME
# ══════════════════════════════════════════════════════════════════════════════
header
step "system configuration"

echo -e "${Y}  hostname (e.g. chocolateos): ${N}\c"
read -r HOSTNAME
HOSTNAME="${HOSTNAME:-chocolateos}"

echo ""
echo -e "${Y}  username: ${N}\c"
read -r USERNAME

echo ""
echo -e "${Y}  timezone (e.g. America/Argentina/Buenos_Aires): ${N}\c"
read -r TIMEZONE
TIMEZONE="${TIMEZONE:-UTC}"

echo ""
echo -e "${Y}  locale (e.g. en_US, es_AR — leave blank for en_US): ${N}\c"
read -r LOCALE_INPUT
LOCALE="${LOCALE_INPUT:-en_US}"

echo ""
echo -e "${Y}  keyboard layout (e.g. us, es, br-abnt2 — leave blank for us): ${N}\c"
read -r KEYMAP
KEYMAP="${KEYMAP:-us}"

# ══════════════════════════════════════════════════════════════════════════════
# 5. BOOTLOADER
# ══════════════════════════════════════════════════════════════════════════════
header
step "bootloader selection"

echo -e "  ${W}choose bootloader:${N}"
echo -e "  ${C}1)${N} GRUB    — most compatible, most common"
echo -e "  ${C}2)${N} Limine  — modern, fast, minimal config"
echo -e "  ${C}3)${N} systemd-boot — simple, built into systemd"
echo ""
echo -e "${Y}  choice [1/2/3]: ${N}\c"
read -r BOOT_CHOICE

case "$BOOT_CHOICE" in
    2) BOOTLOADER="limine" ;;
    3) BOOTLOADER="systemd-boot" ;;
    *) BOOTLOADER="grub" ;;
esac

success "will use $BOOTLOADER"

# ══════════════════════════════════════════════════════════════════════════════
# 6. CACHYOS KERNEL OR MAINLINE
# ══════════════════════════════════════════════════════════════════════════════
header
step "kernel selection"

echo -e "  ${W}choose kernel:${N}"
echo -e "  ${C}1)${N} CachyOS kernel — optimized scheduler, better gaming/desktop perf (recommended)"
echo -e "  ${C}2)${N} mainline linux  — standard arch kernel, most stable"
echo -e "  ${C}3)${N} linux-lts       — long term support kernel"
echo ""
echo -e "${Y}  choice [1/2/3]: ${N}\c"
read -r KERNEL_CHOICE

case "$KERNEL_CHOICE" in
    2) KERNEL="linux linux-headers" ;;
    3) KERNEL="linux-lts linux-lts-headers" ;;
    *) KERNEL="cachyos" ;; # handled specially during install
esac

# ══════════════════════════════════════════════════════════════════════════════
# 7. BASE INSTALL
# ══════════════════════════════════════════════════════════════════════════════
header
step "installing base system..."

info "updating mirrorlist..."
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

if [[ "$KERNEL" == "cachyos" ]]; then
    info "setting up cachyos repo on live iso..."
    curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz
    tar xvf cachyos-repo.tar.xz

    CACHYOS_DIR=$(find . -maxdepth 1 -type d -name 'cachyos*' | head -1)
    cd "$CACHYOS_DIR"

    # the script does:
    # 1. pacman-key --recv-keys / --lsign-key  (fine)
    # 2. pacman -U keyring + mirrorlist pkgs   (fails — no space on live iso tmpfs)
    # 3. gawk to add repos to pacman.conf      (fine)
    # 4. pacman -Syu at the end                (fails — same reason)
    #
    # we only need steps 1 and 3, so patch out 2 and 4

    # skip the pacman -U block (mirrorlist/keyring package installs)
    sed -i '/pacman -U/,/pacman-7.*pkg.tar.zst/d' cachyos-repo.sh

    # skip the final pacman -Syu
    sed -i 's/^\s*pacman -Syu/: #pacman -Syu/' cachyos-repo.sh

    bash cachyos-repo.sh
    cd ..
    rm -rf "$CACHYOS_DIR" cachyos-repo.tar.xz

    # import and fully trust the cachyos signing key
    pacman-key --init
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key F3B607488DB35A47
    # set full trust level (6 = ultimate trust in gpg)
    echo "F3B607488DB35A47:6:" | pacman-key --import-trustdb

    # manually add direct server entries if gawk didn't add them
    if ! grep -q '\[cachyos\]' /etc/pacman.conf; then
        info "manually adding cachyos repos to pacman.conf..."
        cat >> /etc/pacman.conf << 'EOF'

[cachyos-v3]
Server = https://mirror.cachyos.org/repo/x86_64_v3/$repo

[cachyos]
Server = https://mirror.cachyos.org/repo/x86_64/$repo
EOF
    fi

    # sync databases only
    pacman -Sy --noconfirm

    # add x86_64_v3 architecture so pacman accepts cachyos v3 packages
    if ! grep -q 'x86_64_v3' /etc/pacman.conf; then
        sed -i '/^Architecture/s/auto/auto x86_64_v3/' /etc/pacman.conf
    fi

    if ! pacman -Si linux-cachyos &>/dev/null; then
        warn "linux-cachyos still not found — cachyos entries in pacman.conf:"
        grep -A3 'cachyos' /etc/pacman.conf
        error "cachyos repo setup failed, cannot continue"
    fi

    success "cachyos repo added"
fi

info "installing base packages..."
# pacstrap checks free space against live iso tmpfs (very limited RAM)
# write a temp pacman.conf with CheckSpace disabled to work around this
sed 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf > /tmp/pacman-nocheckspace.conf
# ensure x86_64_v3 arch is in the temp config for cachyos packages
sed -i '/^Architecture/s/auto/auto x86_64_v3/' /tmp/pacman-nocheckspace.conf

if [[ "$KERNEL" == "cachyos" ]]; then
    pacstrap -K -C /tmp/pacman-nocheckspace.conf /mnt base base-devel linux-firmware \
        networkmanager pipewire pipewire-pulse pipewire-alsa wireplumber \
        zsh git curl wget sudo nano \
        linux-cachyos linux-cachyos-headers
else
    pacstrap -K -C /tmp/pacman-nocheckspace.conf /mnt base base-devel linux-firmware \
        networkmanager pipewire pipewire-pulse pipewire-alsa wireplumber \
        zsh git curl wget sudo nano \
        $KERNEL
fi

rm /tmp/pacman-nocheckspace.conf

success "base system installed"

# copy cachyos repo config into installed system if applicable
if [[ "$KERNEL" == "cachyos" ]]; then
    info "copying cachyos repo config into installed system..."
    cp /etc/pacman.d/cachyos-mirrorlist /mnt/etc/pacman.d/cachyos-mirrorlist 2>/dev/null || true
    cp /etc/pacman.d/cachyos-v3-mirrorlist /mnt/etc/pacman.d/cachyos-v3-mirrorlist 2>/dev/null || true
    cp /etc/pacman.d/cachyos-v4-mirrorlist /mnt/etc/pacman.d/cachyos-v4-mirrorlist 2>/dev/null || true
    # append cachyos repos to installed system's pacman.conf
    grep -q '\[cachyos\]' /mnt/etc/pacman.conf || \
        grep '\[cachyos\]' /etc/pacman.conf >> /mnt/etc/pacman.conf || true
    # add x86_64_v3 architecture to installed system
    if ! grep -q 'x86_64_v3' /mnt/etc/pacman.conf; then
        sed -i '/^Architecture/s/auto/auto x86_64_v3/' /mnt/etc/pacman.conf
    fi
    success "cachyos repo config copied"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 8. FSTAB
# ══════════════════════════════════════════════════════════════════════════════
step "generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
success "fstab generated"

# ══════════════════════════════════════════════════════════════════════════════
# 9. CHROOT CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
header
step "configuring system inside chroot..."

arch-chroot /mnt bash -c "
set -e

# timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# locale
echo '${LOCALE}.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=${LOCALE}.UTF-8' > /etc/locale.conf
echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf

# hostname
echo '${HOSTNAME}' > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# enable networkmanager
systemctl enable NetworkManager

# root password
echo 'set root password:'
passwd

# create user
useradd -m -G wheel,audio,video,storage -s /bin/zsh ${USERNAME}
echo 'set password for ${USERNAME}:'
passwd ${USERNAME}

# sudo for wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# initramfs
mkinitcpio -P
"

success "system configured"

# ══════════════════════════════════════════════════════════════════════════════
# 10. BOOTLOADER INSTALL
# ══════════════════════════════════════════════════════════════════════════════
header
step "installing bootloader: $BOOTLOADER"

case "$BOOTLOADER" in
    grub)
        arch-chroot /mnt bash -c "
            sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
            pacman -S --noconfirm grub efibootmgr os-prober
            sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
            grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ChocolateOS --recheck
            grub-mkconfig -o /boot/grub/grub.cfg
        "
        ;;
    limine)
        arch-chroot /mnt bash -c "
            pacman -S --noconfirm limine efibootmgr
            limine bios-install $DISK
            mkdir -p /boot/efi/EFI/limine
            cp /usr/share/limine/BOOTX64.EFI /boot/efi/EFI/limine/
            cat > /boot/limine.cfg <<EOF
timeout: 5

/ChocolateOS
    comment: ChocolateOS
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    cmdline: root=${ROOT_PART} rw quiet splash
    module_path: boot():/initramfs-linux-cachyos.img
EOF
        "
        ;;
    systemd-boot)
        arch-chroot /mnt bash -c "
            bootctl install
            mkdir -p /boot/efi/loader/entries
            cat > /boot/efi/loader/loader.conf <<EOF
default chocolateos
timeout 5
editor no
EOF
            cat > /boot/efi/loader/entries/chocolateos.conf <<EOF
title   ChocolateOS
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=${ROOT_PART} rw quiet splash
EOF
        "
        ;;
esac

success "$BOOTLOADER installed"

# ══════════════════════════════════════════════════════════════════════════════
# 11. CHOCOLATEOS PACKAGES
# ══════════════════════════════════════════════════════════════════════════════
header
step "installing ChocolateOS packages..."

if confirm "install full ChocolateOS app suite now? (takes a while, can skip and run post-install script later)"; then
    arch-chroot /mnt bash -c "
        # disable CheckSpace — avoids false disk space errors during install
        sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

        pacman -S --noconfirm \
            niri waybar mako swaylock wlogout swaybg swww \
            rofi-wayland copyq grim slurp \
            xdg-desktop-portal xdg-desktop-portal-gnome \
            xwayland-satellite \
            polkit-gnome \
            kitty \
            ttf-jetbrains-mono noto-fonts noto-fonts-emoji \
            steam lutris krita kdenlive \
            vlc tenacity mousepad hexchat gnome-calculator \
            ffmpeg yt-dlp rsync \
            cmake rust gcc make meson ninja \
            gamemode mangohud timeshift dolphin flameshot \
            zsh starship btop fastfetch \
            zsh-autosuggestions zsh-syntax-highlighting \
            python python-gobject gtk3 \
            gtk3-nocsd \
            hyprpicker wl-clipboard brightnessctl playerctl \
            network-manager-applet \
            bluez bluez-utils blueberry pavucontrol \
            yazi unzip unrar p7zip udiskie tumbler \
            wine winetricks bottles \
            mpv strawberry handbrake obs-studio \
            qpwgraph easyeffects \
            gimp inkscape darktable \
            eza bat fd ripgrep fzf tmux zellij \
            ncdu duf trash-cli httpie neovim \
            bleachbit gparted hwinfo smartmontools \
            lm_sensors cpupower acpi \
            cava lolcat figlet foliate

        # re-enable CheckSpace
        sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf

        # enable services
        systemctl enable bluetooth
        systemctl enable NetworkManager

        # install paru as user
        sudo -u ${USERNAME} bash -c '
            cd /tmp
            git clone https://aur.archlinux.org/paru.git
            cd paru
            makepkg -si --noconfirm
        '

        # build and install awww from source
        pacman -S --noconfirm lz4 scdoc
        sudo -u ${USERNAME} bash -c '
            cd /tmp
            git clone https://codeberg.org/LGFae/awww.git
            cd awww
            cargo build --release
            sudo install -Dm755 target/release/awww /usr/local/bin/awww
            sudo install -Dm755 target/release/awww-daemon /usr/local/bin/awww-daemon
        '

        # AUR packages
        sudo -u ${USERNAME} paru -S --noconfirm \
            librewolf-bin \
            equibop \
            ttf-monocraft \
            proton-ge-custom \
            heroic-games-launcher \
            goverlay \
            satty \
            pipes.sh \
            cbonsai \
            tty-clock
    "

    # copy niri config
    info "copying niri config..."
    mkdir -p /mnt/home/${USERNAME}/.config/niri
    cp "$(dirname "$0")/config.kdl" /mnt/home/${USERNAME}/.config/niri/config.kdl
    arch-chroot /mnt chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/niri

    # zsh config for new user
    arch-chroot /mnt bash -c "
        cat >> /home/${USERNAME}/.zshrc <<'EOF'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval \"\$(starship init zsh)\"
alias ls='eza --icons'
alias ll='eza -la --icons'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias df='duf'
alias du='ncdu'
alias rm='trash'
EOF
        chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.zshrc
    "

    success "all packages installed"
fi

# ══════════════════════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════════════════════
header
echo -e "${G}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   🍫 ChocolateOS installed successfully! ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${N}"
echo -e "  ${W}summary:${N}"
echo -e "  ${C}disk:${N}       $DISK"
echo -e "  ${C}filesystem:${N} $FS_TYPE"
echo -e "  ${C}bootloader:${N} $BOOTLOADER"
echo -e "  ${C}hostname:${N}   $HOSTNAME"
echo -e "  ${C}user:${N}       $USERNAME"
echo -e "  ${C}timezone:${N}   $TIMEZONE"
echo ""
warn "unmounting and rebooting..."
sleep 2
umount -R /mnt
echo -e "\n${G}  remove the live usb and reboot!${N}\n"

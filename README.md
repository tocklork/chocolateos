# 🍫 ChocolateOS
 
An opinionated Arch Linux install script — sets up a minimal, lightweight system the way I like it.
 
---
 
## Overview
 
ChocolateOS is NOT a fucking distribution. It's a fucking interactive installer script that sets up a vanilla Arch Linux system with a curated set of packages and configs. It uses the CachyOS kernel for better desktop and gaming performance, and niri as the Wayland compositor.
 
- **Base:** Arch Linux
- **Kernel:** CachyOS (BORE/EEVDF scheduler)
- **Compositor:** niri (scrollable-tiling Wayland)
- **Shell:** zsh + starship
- **Terminal:** Kitty
- **Browser:** Librewolf
 
---
 
## Installation
 
### Requirements
- A USB drive (4GB+)
- A 64-bit UEFI system
- Internet connection
 
### Steps
 
1. Boot from an Arch Linux live ISO
2. Clone this repo or download the installer:
```bash
curl -O https://raw.githubusercontent.com/tocklork/chocolateos/main/chocolateos-installer.sh
curl -O https://raw.githubusercontent.com/tocklork/chocolateos/main/config.kdl
```
3. Run the installer as root:
```bash
bash chocolateos-installer.sh
```
4. Follow the prompts — it will ask for:
   - Disk to install on
   - Partition layout (automatic or manual)
   - Filesystem (ext4 / btrfs / xfs)
   - Hostname, username, timezone, locale
   - Bootloader (GRUB / Limine / systemd-boot)
   - Kernel (CachyOS / mainline / LTS)
 
5. Reboot and remove the USB
 
---
 
## What's Included
 
### Desktop
| App | Purpose |
|-----|---------|
| niri | Wayland compositor |
| waybar | Status bar |
| mako | Notification daemon |
| swaylock | Screen locker |
| wlogout | Logout menu |
| rofi-wayland | App launcher |
| copyq | Clipboard manager |
| awww | Wallpaper daemon |
| xwayland-satellite | XWayland support |
 
### Apps
| App | Purpose |
|-----|---------|
| Kitty | Terminal |
| Librewolf | Browser |
| Mousepad | Text editor |
| Dolphin | File manager |
| VLC | Media player |
| MPV | Video player |
| OBS Studio | Recording/streaming |
| GIMP | Image editor |
| Krita | Digital painting |
| Inkscape | Vector graphics |
| Darktable | Photo editing |
| KDEnlive | Video editor |
| Tenacity | Audio editor |
| Handbrake | Video transcoding |
| Strawberry | Music player |
| Gnome Calculator | Calculator |
| HexChat | IRC client |
| Equibop | Discord client |
 
### Gaming
| App | Purpose |
|-----|---------|
| Steam | Gaming platform |
| Lutris | Game manager |
| Heroic | Epic/GOG/Amazon launcher |
| Bottles | Wine prefix manager |
| GameMode | Gaming performance daemon |
| MangoHud | In-game overlay |
| Proton-GE | Enhanced Proton |
 
### Development
| App | Purpose |
|-----|---------|
| Git | Version control |
| Neovim | Text editor |
| GCC + Make | C/C++ compiler |
| CMake | Build system |
| Meson + Ninja | Build system |
| Rust | Rust toolchain |
| Python + pip | Python runtime |
| Docker | Containers |
| Paru | AUR helper |
 
### CLI Tools
| App | Purpose |
|-----|---------|
| btop | Resource monitor |
| fastfetch | System info |
| eza | Modern ls |
| bat | Modern cat |
| fd | Modern find |
| ripgrep | Modern grep |
| fzf | Fuzzy finder |
| tmux | Terminal multiplexer |
| zellij | Modern tmux alternative |
| ncdu | Disk usage |
| duf | Modern df |
| yt-dlp | Video downloader |
| ffmpeg | Audio/video processing |
| rsync | File sync |
| timeshift | System snapshots |
 
---
 
## Niri Keybinds
 
| Keybind | Action |
|---------|--------|
| `Mod+T` | Open terminal (Kitty) |
| `Mod+D` | App launcher (Rofi) |
| `Mod+Q` | Close window |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+H/J/K/L` | Focus left/down/up/right |
| `Mod+Ctrl+H/J/K/L` | Move window |
| `Mod+1-9` | Switch workspace |
| `Mod+Ctrl+1-9` | Move to workspace |
| `Mod+R` | Cycle column widths |
| `Mod+Shift+E` | Quit niri |
| `Super+Alt+L` | Lock screen |
| `Print` | Screenshot |
| `Ctrl+Print` | Screenshot screen |
| `Alt+Print` | Screenshot window |
 
---
 
## Filesystem Options
 
| Option | Notes |
|--------|-------|
| **ext4** | Stable, simple, recommended for beginners |
| **btrfs** | Snapshots + compression, works great with timeshift |
| **xfs** | Fast, good for large files |
 
---
 
## Bootloader Options
 
| Option | Notes |
|--------|-------|
| **GRUB** | Most compatible, most common |
| **Limine** | Modern, fast, minimal config |
| **systemd-boot** | Simple, built into systemd |
 
---
 
> made with love by thomi

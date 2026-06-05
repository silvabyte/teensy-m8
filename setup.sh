#!/usr/bin/env bash
# One-shot host setup for M8 headless on a Teensy 4.1, keyboard-controlled.
# Installs dependencies and drops the Teensy udev rule. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACMAN_PKGS=(
    teensy_loader_cli
    libserialport
    sdl2-compat
    sdl2_image
    sdl2_ttf
)
AUR_PKGS=(m8c-bin)

echo ">> Installing official repo packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

echo ">> Installing AUR packages via yay..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

echo ">> Installing udev rules..."
sudo install -m 0644 "$SCRIPT_DIR/udev/00-teensy.rules" /etc/udev/rules.d/00-teensy.rules

echo ">> Reloading udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "Setup complete. Next steps:"
echo "  1. Plug in the Teensy 4.1, then run:  ./flash.sh"
echo "  2. After flashing, run:  ./run.sh  (controls are keyboard — see CHEATSHEET.md)"

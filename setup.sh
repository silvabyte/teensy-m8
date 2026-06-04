#!/usr/bin/env bash
# One-shot host setup for M8 headless on a Teensy 4.1 + Steam Controller (wired).
# Installs dependencies, drops udev rules, adds you to the uinput group.
# Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACMAN_PKGS=(
    teensy_loader_cli
    sc-controller
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

echo ">> Ensuring 'uinput' group exists (needed for sc-controller's virtual gamepad)..."
if ! getent group uinput >/dev/null; then
    sudo groupadd uinput
fi
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx uinput; then
    sudo usermod -aG uinput "$USER"
    echo "   Added $USER to 'uinput'. You must log out and back in for this to apply."
fi

echo ">> Installing udev rules..."
sudo install -m 0644 "$SCRIPT_DIR/udev/00-teensy.rules"          /etc/udev/rules.d/00-teensy.rules
sudo install -m 0644 "$SCRIPT_DIR/udev/99-steam-controller.rules" /etc/udev/rules.d/99-steam-controller.rules

echo ">> Reloading udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "Setup complete. Next steps:"
echo "  1. If you were just added to 'uinput', log out and back in."
echo "  2. Plug in the Teensy 4.1, then run:  ./flash.sh"
echo "  3. After flashing, plug in the Steam Controller and run:  ./run.sh"

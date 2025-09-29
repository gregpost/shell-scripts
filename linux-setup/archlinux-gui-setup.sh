#!/bin/bash
# Arch Linux Graphical Interface Installer
# Run as root

set -e

echo "Updating system..."
pacman -Syu --noconfirm

echo "Installing Xorg display server..."
pacman -S --noconfirm xorg xorg-xinit xorg-apps

echo "Installing GNOME Desktop Environment..."
pacman -S --noconfirm gnome gnome-extra

echo "Installing GDM (GNOME Display Manager)..."
pacman -S --noconfirm gdm

echo "Enabling GDM to start on boot..."
systemctl enable gdm.service

echo "Installation complete! Rebooting is recommended."

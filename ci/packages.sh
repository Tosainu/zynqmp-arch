#!/usr/bin/env bash

set -e

sudo pacman -Syu --noconfirm

sudo sed -i "s/^#\(MAKEFLAGS=\).*/\1\"-j$(( $(nproc) * 2 ))\"/" /etc/makepkg.conf

sudo mkdir /work
sudo chown $(id -un):$(id -gn) /work
cd /work

cp -r /repo/PKGBUILDs .

pushd PKGBUILDs/linux-zynqmp/
makepkg -si --noconfirm --noprogressbar
popd

pushd PKGBUILDs/wilc3000-ultra96v2/
makepkg -si --noconfirm --noprogressbar
popd

pushd PKGBUILDs/wilc-firmware/
makepkg -si --noconfirm --noprogressbar
popd

mkdir pkgs
mv PKGBUILDs/*/*.pkg.tar.xz pkgs/

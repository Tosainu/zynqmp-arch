#!/usr/bin/env bash

set -e
set -o pipefail
set -u

sudo pacman-key --init
sudo pacman-key --populate archlinuxarm

sudo sed -i 's/^#\?\(Color\)/\1/' /etc/pacman.conf
sudo sed -i 's/^#\?\(MAKEFLAGS=\).*$/\1"-j4"/' /etc/makepkg.conf
sudo pacman -Syyu --noconfirm --noprogressbar

# another pacman conig and db for downloading previously built packages
cp /etc/pacman.conf ~/
cat >> ~/pacman.conf <<EOS

[zynqmp-arch]
SigLevel = Never
Server = https://zynqmp-arch.myon.info/\$arch
EOS

cp -r /var/lib/pacman ~/db
fakeroot pacman -Sy --noconfirm --noprogressbar --config ~/pacman.conf --dbpath ~/db

dlpkg() {
  fakeroot pacman -Sddw --noconfirm --noprogressbar --config ~/pacman.conf --dbpath ~/db --cachedir . $@
}

mkdir ~/work
cd ~/work

cp -r /repo/PKGBUILDs .

for p in \
  PKGBUILDs/linux-zynqmp \
  PKGBUILDs/wilc3000-ultra96v2 \
  PKGBUILDs/wilc-firmware
do
  pushd "$p"

  mapfile -t pkg_names < <(makepkg --printsrcinfo | grep -Po '(?<=pkgname = ).+')
  dlpkg "${pkg_names[@]}" || true

  mapfile -t pkg_files < <(makepkg --packagelist)
  if ! ls "${pkg_files[@]}" > /dev/null 2>&1; then
    rm -f ./*.pkg.tar.xz
    makepkg -si --noconfirm --noprogressbar
  else
    sudo pacman -U --noconfirm --noprogressbar "${pkg_files[@]}"
  fi

  popd
done

mkdir -p /pkgs/aarch64
cp PKGBUILDs/*/*.pkg.tar.xz /pkgs/aarch64/
cd /pkgs/aarch64
repo-add zynqmp-arch.db.tar.gz *.pkg.tar.xz

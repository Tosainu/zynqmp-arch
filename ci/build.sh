#!/usr/bin/env bash

set -e
set -o pipefail
set -u

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

mkdir -p ~/pkgs/aarch64

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

  cp *.pkg.tar.xz ~/pkgs/aarch64/

  popd
done

cd ~/pkgs/aarch64
repo-add zynqmp-arch.db.tar.gz *.pkg.tar.xz

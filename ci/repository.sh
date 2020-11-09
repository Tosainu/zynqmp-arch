#!/usr/bin/env bash

set -e

sudo mkdir /work
sudo chown $(id -un):$(id -gn) /work
cd /work

mkdir -p aarch64
cd aarch64

cp -r /pkgs/*.pkg.tar.xz .
repo-add zynqmp-arch.db.tar.gz *.pkg.tar.xz

ls -las

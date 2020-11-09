FROM alpine AS download
RUN \
  apk add --no-cache curl gnupg && \
  curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz && \
  curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.sig && \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6 && \
  gpg --verify ArchLinuxARM-aarch64-latest.tar.gz.sig && \
  mkdir /rootfs && \
  tar xf ArchLinuxARM-aarch64-latest.tar.gz -C /rootfs && \
  rm ArchLinuxARM-aarch64-latest.tar.gz ArchLinuxARM-aarch64-latest.tar.gz.sig

FROM scratch AS build
COPY --from=download /rootfs/ /
RUN \
  pacman-key --init && \
  pacman-key --populate archlinuxarm && \
  mkdir -m 0755 -p /rootfs/var/{cache/pacman/pkg,lib/pacman,log} && \
  mkdir -m 0755 -p /rootfs/{dev,run,etc/pacman.d} && \
  mkdir -m 1777 -p /rootfs/tmp && \
  mkdir -m 0555 -p /rootfs/{sys,proc} && \
  pacman -r /rootfs -Sy --noconfirm base base-devel

FROM scratch
COPY --from=build /rootfs/ /
RUN \
  pacman-key --init && \
  pacman-key --populate archlinuxarm && \
  useradd -m -U alarm && \
  echo 'alarm ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
USER alarm
CMD ["/usr/bin/bash"]

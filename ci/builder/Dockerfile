FROM alpine AS download
RUN \
  apk add --no-cache curl gnupg libarchive-tools && \
  curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz && \
  curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.sig && \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6 && \
  gpg --verify ArchLinuxARM-aarch64-latest.tar.gz.sig && \
  mkdir /rootfs && \
  bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /rootfs && \
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
	mkdir -p /rootfs/alpm-hooks/usr/share/libalpm/hooks && \
	bash -c "find /usr/share/libalpm/hooks -exec ln -sf /dev/null /rootfs/alpm-hooks{} \;" && \
  pacman -r /rootfs -Sy --noconfirm --noscriptlet \
    --hookdir /rootfs/alpm-hooks/usr/share/libalpm/hooks/ base base-devel && \
  sed -i 's/^#\(en_US\.UTF-8\)/\1/' /rootfs/etc/locale.gen && \
  rm -rf /rootfs/alpm-hooks /rootfs/var/lib/pacman/sync/*

FROM scratch
COPY --from=build /rootfs/ /
RUN \
  ldconfig && \
  update-ca-trust && \
  locale-gen && \
  (ls usr/lib/sysusers.d/*.conf | /usr/share/libalpm/scripts/systemd-hook sysusers) && \
  ln -s /usr/lib/os-release /etc/os-release && \
  pacman-key --init && \
  pacman-key --populate archlinuxarm && \
  useradd -m -U alarm && \
  echo 'alarm ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
ENV LANG=en_US.UTF-8
USER alarm
CMD ["/usr/bin/bash"]

setenv bootargs earlycon clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait

setenv fdtfile xilinx/avnet-ultra96-v2-rev1.dtb

if load ${devtype} ${devnum}:${distro_bootpart} 0x00200000 /boot/vmlinuz-linux-zynqmp; then
  if load ${devtype} ${devnum}:${distro_bootpart} 0x00100000 /boot/dtbs/${fdtfile}; then
    if load ${devtype} ${devnum}:${distro_bootpart} 0x04000000 /boot/initramfs-linux-zynqmp.img; then
      booti 0x00200000 0x04000000:${filesize} 0x00100000;
    fi;
  fi;
fi

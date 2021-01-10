# zynqmp-arch

Arch Linux ARM for Xilinx Zynq UltraScale+ devices.

![](images/screenfetch.png)

## Installation

**Required tools:**
- Linux-based host PC
- Vitis 2020.1
- Statically-linked QEMU User space emulator for AArch64 + binfmt_misc configurations
    - If you are using Arch Linux, you can use [binfmt-qemu-static][binfmt-qemu-static] and [qemu-user-static][qemu-user-static] packages from the AUR ([ArchWiki][qemu-wiki]).
    - You can also use the [multiarch/qemu-user-static][multiarch-qemu-static] container image.
- [arch-install-scripts][arch-install-scripts]
    - We will use [`arch-chroot(8)`][arch-chroot-man] to chroot into the target system.

### Step1: Hardware Design

Use Vivado to create the hardware design. After synth, impl, and generating bitstream, export the `.xsa` file by following the TCL command.

```
Vivado% write_hw_platform -fixed -include_bit system.xsa
```

### Step2: Boot Loaders and Firmwares

1. Generate First Stage Boot Loader (fsbl) and PMU Firmware (pmufw) sources:
    ```
    $ mkdir xsct && cd $_
    $ cp /path/to/system.xsa .

    $ xsct

    xsct% set hw_design [hsi open_hw_design system.xsa]

    xsct% set sw_design [hsi create_sw_design fsbl -proc psu_cortexa53_0 -os standalone]
    xsct% hsi set_property CONFIG.stdin  psu_uart_1 [hsi get_os]
    xsct% hsi set_property CONFIG.stdout psu_uart_1 [hsi get_os]
    xsct% hsi add_library xilffs
    xsct% hsi add_library xilpm
    xsct% hsi add_library xilsecure
    xsct% hsi generate_app -hw $hw_design -sw $sw_design -app zynqmp_fsbl -dir fsbl
    xsct% hsi close_sw_design $sw_design

    xsct% set sw_design [hsi create_sw_design pmufw -proc psu_pmu_0 -os standalone]
    xsct% hsi set_property CONFIG.stdin  psu_uart_1 [hsi get_os]
    xsct% hsi set_property CONFIG.stdout psu_uart_1 [hsi get_os]
    xsct% hsi add_library xilfpga
    xsct% hsi add_library xilsecure
    xsct% hsi add_library xilskey
    xsct% hsi generate_app -hw $hw_design -sw $sw_design -app zynqmp_pmufw -dir pmufw
    xsct% hsi close_sw_design $sw_design

    xsct% exit

    $ cd ..
    ```
2. Patch the pmufw sources (Ultra96/Ultra96-V2):
    ```
    $ sed -i 's/^\(CFLAGS :=.*$\)/\1 -DENABLE_MOD_ULTRA96 -DULTRA96_VERSION=2/' xsct/pmufw/Makefile
    $ sed -i 's/^\(#define\s\+PMU_MIO_INPUT_PIN_VAL\).*/\1 (1U)/;
              s/^\(#define\s\+BOARD_SHUTDOWN_PIN_VAL\).*/\1 (1U)/;
              s/^\(#define\s\+BOARD_SHUTDOWN_PIN_STATE_VAL\).*/\1 (1U)/' xsct/pmufw/xpfw_config.h
    ```
3. Build fsbl and pmufw:
    ```
    $ make -C xsct/fsbl
    $ make -C xsct/pmufw
    ```
4. Build [Xilinx/arm-trusted-firmware][atf-xilinx]:
    ```
    $ mkdir arm-trusted-firmware && cd $_
    $ curl -L https://github.com/Xilinx/arm-trusted-firmware/archive/xilinx-v2020.1.tar.gz | \
        tar xz --strip-components=1 -C .

    $ CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 \
        make -j12 PLAT=zynqmp RESET_TO_BL31=1 ZYNQMP_CONSOLE=cadence1

    $ cd ..
    ```
5. Build [Xilinx/u-boot-xlnx][u-boot-xilinx]:
    ```
    $ mkdir u-boot-xlnx && cd $_
    $ curl -L https://github.com/Xilinx/u-boot-xlnx/archive/xilinx-v2020.1.tar.gz | \
        tar xz --strip-components=1 -C .

    $ CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 make xilinx_zynqmp_virt_defconfig
    $ CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 \
        DEVICE_TREE="<your-target-device-tree-name>" \
        BL31=$PWD/../arm-trusted-firmware/build/zynqmp/release/bl31.bin \
        make -j12 u-boot.elf

    $ cd ..
    ```
6. Create `BOOT.BIN`:
    ```
    $ mkdir boot && cd $_
    $ cp ../xsct/fsbl/executable.elf fsbl.elf
    $ cp ../xsct/pmufw/executable.elf pmufw.elf
    $ cp ../xsct/<bitstream_name>.bit bitstream.bit
    $ cp ../arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf .
    $ cp ../u-boot-xlnx/u-boot.elf .

    $ cat > boot.bif <<EOS
    the_ROM_image:
    {
      [destination_cpu=a53-0, bootloader]                       fsbl.elf
      [destination_cpu=pmu]                                     pmufw.elf
      [destination_device=pl]                                   bitstream.bit
      [destination_cpu=a53-0, exception_level=el-3, trustzone]  bl31.elf
      [destination_cpu=a53-0, exception_level=el-2]             u-boot.elf
    }
    EOS

    $ bootgen -arch zynqmp -image boot.bif -w -o BOOT.BIN

    $ cd ..
    ```

### Step3: Rootfs

1. Partition the SD card:
    1. Start `fdisk`:
        ```
        $ sudo fdisk /dev/sdX
        ```
    2. Clear out all partitions:
        ```
        Command (m for help): o
        Created a new DOS disklabel with disk identifier 0xad9770e8.
        ```
    3. Create the first partition (kernel and boot loaders):
        ```
        Command (m for help): n
        Partition type
        p   primary (0 primary, 0 extended, 4 free)
        e   extended (container for logical partitions)
        Select (default p): p
        Partition number (1-4, default 1): 1
        First sector (2048-124975103, default 2048):
        Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-124975103, default 124975103): +200M
        
        Created a new partition 1 of type 'Linux' and of size 200 MiB.
        
        Command (m for help): t
        Selected partition 1
        Hex code or alias (type L to list all): c
        Changed type of partition 'Linux' to 'W95 FAT32 (LBA)'.
        ```
    4. Create the second partition (rootfs):
        ```
        Command (m for help): n
        Partition type
        p   primary (1 primary, 0 extended, 3 free)
        e   extended (container for logical partitions)
        Select (default p): p
        Partition number (2-4, default 2):
        First sector (411648-124975103, default 411648):
        Last sector, +/-sectors or +/-size{K,M,G,T,P} (411648-124975103, default 124975103):
        
        Created a new partition 2 of type 'Linux' and of size 59.4 GiB.
        ```
    5. Write the partition table and exit:
        ```
        Command (m for help): w
        The partition table has been altered.
        Calling ioctl() to re-read partition table.
        Syncing disks.
        ```
2. Format and mount the SD card:
    ```
    $ sudo mkfs.vfat /dev/sdX1
    $ sudo mkfs.ext4 /dev/sdX2

    $ sudo mount /dev/sdX2 /mnt
    $ sudo mkdir -p /mnt/boot
    $ sudo mount /dev/sdX1 /mnt/boot
    ```
3. Download and extract the latest Arch Linux ARM tarball:
    ```
    $ curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
    $ curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.md5
    $ md5sum -c ArchLinuxARM-aarch64-latest.tar.gz.md5
    $ sudo bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
    $ sync
    ```
4. Chroot into the target system:
    ```
    $ sudo arch-chroot /mnt /bin/bash

    (chroot)# uname -m
    aarch64
    ```
5. Initialize the pacman keyring:
    ```
    (chroot)# packan-key --init
    (chroot)# packan-key --populate archlinuxarm
    ```
6. Add `zynqmp-arch` package repository:
    ```
    (chroot)# cat >> /etc/pacman.conf <<EOS
    
    [zynqmp-arch]
    SigLevel = Never
    Server = https://zynqmp-arch.myon.info/\$arch
    EOS
    ```
7. Add/Remove/Update packages:
    - Remove unneeded utilities:
        ```
        (chroot)# pacman -Rncs netctl dhcpcd net-tools
        ```
    - Remove pre-installed kernel:
        ```
        (chroot)# pacman -Rnd linux-aarch64
        ```
    - Update the system:
        ```
        (chroot)# pacman -Syu
        ```
    - Install the kernel ([linux-zynqmp](PKGBUILDs/linux-zynqmp/PKGBUILD)):
        ```
        (chroot)# pacman -S linux-zynqmp
        ```
    - Install Ultra96-V2 Wifi/BT driver ([wilc3000-ultra96v2](PKGBUILDs/wilc3000-ultra96v2/PKGBUILD)) and firmware ([wilc-firmware](PKGBUILDs/wilc-firmware/PKGBUILD)):
        ```
        (chroot)# pacman -S wilc3000-ultra96v2 wilc-firmware
        ```
    - Install [iwd][iwd-wiki] for connecting Wifi:
        ```
        (chroot)# pacman -S iwd
        ```
    - Remove unrequired packages:
        ```
        (chroot)# pacman -Rncs $(pacman -Qdtq)
        ```
8. Set passwords:
    ```
    (chroot)# passwd
    (chroot)# passwd alarm
    ```
9. Configure `/etc/fstab` and exit the chroot environment:
    ```
    (chroot)# cat >> /etc/fstab <<EOS
    /dev/mmcblk0p2 /     ext4 defaults 0 1
    /dev/mmcblk0p1 /boot vfat defaults 0 2
    EOS

    (chroot)# exit
    ```
10. Copy `BOOT.BIN` (created in step2) and `boot.scr` to `/boot`:
    ```
    $ sudo cp BOOT.BIN /mnt/boot/

    $ vim /path/to/zynqmp-arch/boot/boot.cmd
    $ /path/to/u-boot-xlnx/tools/mkimage -c none -A arm64 -T script -d /path/to/zynqmp-arch/boot/boot.cmd boot.scr
    $ sudo mv boot.scr /mnt/boot/
    ```
11. Unmount the SD card:
    ```
    sudo umount /mnt{/boot,}
    ```

### Step4: Boot!

Insert the SD card and turn on the power. You will see the following messages via serial console.

    Xilinx Zynq MP First Stage Boot Loader
    Release 2020.1   Nov  7 2020  -  11:51:03
    PMU Firmware 2020.1	Nov  7 2020   11:51:27
    PMU_ROM Version: xpbr-v8.1.0-0
    NOTICE:  ATF running on XCZU3EG/silicon v4/RTL5.1 at 0xfffea000
    NOTICE:  BL31: v2.2(release):
    NOTICE:  BL31: Built : 11:51:33, Nov  7 2020
    
    
    U-Boot 2020.01 (Nov 07 2020 - 11:51:38 +0000)
    
    Model: Avnet Ultra96 Rev1
    Board: Xilinx ZynqMP
    DRAM:  2 GiB
    PMUFW:	v1.1
    EL Level:	EL2
    Chip ID:	zu3eg
    NAND:  0 MiB
    MMC:   mmc@ff160000: 0, mmc@ff170000: 1
    In:    serial@ff010000
    Out:   serial@ff010000
    Err:   serial@ff010000
    Bootmode: SD_MODE
    Reset reason:	EXTERNAL
    Net:   No ethernet found.
    Hit any key to stop autoboot:  0
    switch to partitions #0, OK
    mmc0 is current device
    Scanning mmc 0:1...
    Found U-Boot script /boot.scr
    524 bytes read in 17 ms (29.3 KiB/s)
    ## Executing script at 20000000
    22747648 bytes read in 1820 ms (11.9 MiB/s)
    40479 bytes read in 26 ms (1.5 MiB/s)
    8193054 bytes read in 668 ms (11.7 MiB/s)
    ## Flattened Device Tree blob at 00100000
       Booting using the fdt blob at 0x100000
       Loading Ramdisk to 7882f000, end 78fff41e ... OK
       Loading Device Tree to 000000000fff3000, end 000000000ffffe1e ... OK
    
    Starting kernel ...
    
    [    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
    [    0.000000] Linux version 5.4.0-1-ARCH (alarm@buildenv) (gcc version 10.2.0 (GCC)) #1 SMP Mon Nov 9 07:02:37 UTC 2020
    [    0.000000] Machine model: Avnet Ultra96-V2 Rev1
    [    0.000000] earlycon: cdns0 at MMIO 0x00000000ff010000 (options '115200n8')
    [    0.000000] printk: bootconsole [cdns0] enabled
    
    (...)
    
    Arch Linux 5.4.0-1-ARCH (ttyPS0)
    
    alarm login:

[arch-install-scripts]: https://github.com/archlinux/arch-install-scripts
[binfmt-qemu-static]: https://aur.archlinux.org/packages/binfmt-qemu-static/
[qemu-user-static]: https://aur.archlinux.org/packages/qemu-user-static/
[qemu-wiki]: https://wiki.archlinux.org/index.php/QEMU#Chrooting_into_arm/arm64_environment_from_x86_64
[multiarch-qemu-static]: https://github.com/multiarch/qemu-user-static
[arch-chroot-man]: https://jlk.fjfi.cvut.cz/arch/manpages/man/extra/arch-install-scripts/arch-chroot.8.en
[atf-xilinx]: https://github.com/Xilinx/arm-trusted-firmware
[u-boot-xilinx]: https://github.com/Xilinx/u-boot-xlnx
[iwd-wiki]: https://wiki.archlinux.org/index.php/Iwd

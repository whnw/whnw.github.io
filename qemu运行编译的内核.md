- qemu组件
```
sudo apt install qemu-system-aarch64
```
- 交叉编译器
```
sudo apt install gcc-aarch64-linux-gnu
```
- 编译kernel
```
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8
```
- 编译busybox
```
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -xvf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install
```
- 构建根文件系统
在生成的_install文件夹下创建系统所需的目录。并给启动程序创建一个软连接。
```
cd _install
mkdir {proc,sys,dev,etc,etc/init.d,lib,tmp}
ln -sf linuxrc init
```
- 复制动态库：
```
cd ..
cp /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 _install/lib/
cp /usr/aarch64-linux-gnu/lib/libc.so.6 _install/lib/
cp /usr/aarch64-linux-gnu/lib/libm.so.6 _install/lib/
cp /usr/aarch64-linux-gnu/lib/libresolv.so.2 _install/lib/
```
- 创建配置文件：
```
cat > _install/etc/init.d/rcS <<EOF
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
/sbin/mdev -s
ifconfig lo up
EOF
chmod +x _install/etc/init.d/rcS
```
```
cat > _install/etc/inittab <<EOF
# /etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF
```

使用cpio生成根文件系统
```
cd _install
find . | cpio -o --format=newc > ../initramfs
```
系统启动脚本：
```
cd ..
cat > run.sh <<EOF
qemu-system-aarch64 \
	-M virt \
	-cpu cortex-a72 \
	-machine type=virt \
	-kernel Image \
	-nographic \
	-m 512M \
	-smp 4 \
	-append "console=ttyAMA0" \
	-initrd initramfs \
  -netdev tap,id=hn2 \
  -device e1000,netdev=hn2
EOF
```
```
cp /path/to/kernel/arch/arm64/boot/Image ./
ls
Image  initramfs  run.sh
```

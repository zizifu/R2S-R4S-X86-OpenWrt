#!/bin/bash
clear

# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip

# 超频到 2.2/1.8 GHz
rm -rf ./target/linux/rockchip/patches-5.4/992-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/new/main/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch ./target/linux/rockchip/patches-5.4/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/new/main/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch ./target/linux/rockchip/patches-5.4/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch

# 使用特定的优化
sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mabi=lp64,g' include/target.mk
cp -f ../PATCH/new/package/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch ./package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch
sed -i 's,kmod-r8169,kmod-r8168,g' target/linux/rockchip/image/armv8.mk
# 测试性功能
sed -i '/CRYPTO_DEV_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/HW_RANDOM_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
echo '
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_HW_RANDOM_ROCKCHIP=y
' >> ./target/linux/rockchip/armv8/config-5.4

# IRQ 调优
sed -i '/set_interface_core 20 "eth1"/a\set_interface_core 8 "ff3c0000" "ff3c0000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/set_interface_core 20 "eth1"/a\ethtool -C eth0 rx-usecs 1000 rx-frames 25 tx-usecs 100 tx-frames 25' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity

# 翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate
echo "
#R4S_LED
uci del system.led_wan.mode
uci del system.led_lan.mode
uci del system.@led[-1]
uci del system.@led[-1]
uci add system led
uci set system.@led[-1].name='LAN'
uci set system.@led[-1].sysfs='nanopi-r4s:green:lan'
uci set system.@led[-1].trigger='netdev'
uci set system.@led[-1].dev='eth1'
uci add_list system.@led[-1].mode='link'
uci add_list system.@led[-1].mode='tx'
uci add_list system.@led[-1].mode='rx'
uci add system led
uci set system.@led[-1].name='WAN'
uci set system.@led[-1].sysfs='nanopi-r4s:green:wan'
uci set system.@led[-1].trigger='netdev'
uci set system.@led[-1].dev='eth0'
uci add_list system.@led[-1].mode='link'
uci add_list system.@led[-1].mode='tx'
uci commit
#R4S_LANWAN
uci set network.wan.ifname='eth0'
uci set network.lan.ifname='eth1'
uci del network.wan6
uci commit network
exit 0

" >> ./package/lean/lean-translate/files/zzz-default-settings

# 内核加解密模块
echo '
CONFIG_ARM64_CRYPTO=y
CONFIG_CRYPTO_SHA256_ARM64=y
CONFIG_CRYPTO_SHA512_ARM64=y
CONFIG_CRYPTO_SHA1_ARM64_CE=y
CONFIG_CRYPTO_SHA2_ARM64_CE=y
# CONFIG_CRYPTO_SHA512_ARM64_CE is not set
CONFIG_CRYPTO_SHA3_ARM64=y
CONFIG_CRYPTO_SM3_ARM64_CE=y
CONFIG_CRYPTO_SM4_ARM64_CE=y
CONFIG_CRYPTO_GHASH_ARM64_CE=y
# CONFIG_CRYPTO_CRCT10DIF_ARM64_CE is not set
CONFIG_CRYPTO_AES_ARM64=y
CONFIG_CRYPTO_AES_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE_CCM=y
CONFIG_CRYPTO_AES_ARM64_CE_BLK=y
CONFIG_CRYPTO_AES_ARM64_NEON_BLK=y
CONFIG_CRYPTO_CHACHA20_NEON=y
CONFIG_CRYPTO_POLY1305_NEON=y
CONFIG_CRYPTO_NHPOLY1305_NEON=y
CONFIG_CRYPTO_AES_ARM64_BS=y
' >> ./target/linux/rockchip/armv8/config-5.4

<<'COMMENT'
#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
COMMENT

# 对齐内核 Vermagic
wget https://downloads.openwrt.org/releases/21.02-SNAPSHOT/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 预配置一些插件
cp -rf ../PATCH/R4S/files ./files

exit 0

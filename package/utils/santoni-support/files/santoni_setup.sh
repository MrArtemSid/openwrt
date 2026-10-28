#!/bin/sh

exec > /dev/kmsg 2>&1
echo "=== SANTONI FIRMWARE, MODEM & WIFI SETUP ==="

# 1. Mount modem and persist partitions for firmware extraction on first boot only
if [ ! -f /lib/firmware/wcnss.mdt ]; then
	mkdir -p /lib/firmware/wlan/prima
	mkdir -p /mnt/modem /mnt/persist

	mount -o ro /dev/mmcblk0p1 /mnt/modem 2>/dev/null
	if [ -d /mnt/modem/image ]; then
		echo "Copying Wi-Fi & Modem firmwares..."
		cp -f /mnt/modem/image/wcnss.* /lib/firmware/ 2>/dev/null
		cp -f /mnt/modem/image/mba.mbn /lib/firmware/ 2>/dev/null
		cp -f /mnt/modem/image/modem.* /lib/firmware/ 2>/dev/null
	fi
	umount /mnt/modem 2>/dev/null

	mount -o ro /dev/mmcblk0p26 /mnt/persist 2>/dev/null
	if [ -f /mnt/persist/WCNSS_qcom_wlan_nv.bin ]; then
		echo "Copying NV bin..."
		cp -f /mnt/persist/WCNSS_qcom_wlan_nv.bin /lib/firmware/wlan/prima/
		cp -f /mnt/persist/WCNSS_qcom_wlan_nv.bin /lib/firmware/
	fi
	umount /mnt/persist 2>/dev/null
fi

# 2. Setup correct partition symlinks for rmtfs on Santoni
mkdir -p /dev/disk/by-partlabel
ln -sf /dev/mmcblk0p2 /dev/disk/by-partlabel/fsc 2>/dev/null || true
ln -sf /dev/mmcblk0p13 /dev/disk/by-partlabel/modemst1 2>/dev/null || true
ln -sf /dev/mmcblk0p14 /dev/disk/by-partlabel/modemst2 2>/dev/null || true
ln -sf /dev/mmcblk0p16 /dev/disk/by-partlabel/fsg 2>/dev/null || true

# 3. Start RMTFS daemon BEFORE booting the modem
if [ -x /usr/bin/rmtfs ] && ! pidof rmtfs >/dev/null 2>&1; then
	echo "Starting rmtfs service..."
	/usr/bin/rmtfs -P -r -s &
fi

# Wait a moment for RMTFS to register on QRTR
sleep 2

# 4. Boot WCNSS (Wi-Fi) and MPSS (Modem)
for rproc in /sys/class/remoteproc/remoteproc*; do
	if [ -d "$rproc" ]; then
		name=$(cat "$rproc/name" 2>/dev/null)
		state=$(cat "$rproc/state" 2>/dev/null)
		echo "$rproc: name=$name state=$state"
		if [ "$state" = "offline" ]; then
			echo "Booting $rproc ($name)..."
			echo start > "$rproc/state" 2>/dev/null || true
		fi
	fi
done

# 5. Bring up Wi-Fi
sleep 3
# Rebind wcn36xx if interface not created yet
WIFI_DEV="a204000.remoteproc:smd-edge:wcnss:wifi"
if [ ! -d /sys/class/net/wlan0 ] && [ -d /sys/bus/platform/drivers/wcn36xx/$WIFI_DEV ]; then
	echo "Rebinding wcn36xx driver..."
	echo "$WIFI_DEV" > /sys/bus/platform/drivers/wcn36xx/unbind 2>/dev/null || true
	sleep 1
	echo "$WIFI_DEV" > /sys/bus/platform/drivers/wcn36xx/bind 2>/dev/null || true
	sleep 2
fi

if [ -d /sys/class/net/wlan0 ]; then
	ip link set wlan0 address 02:ba:de:af:42:01
	if [ ! -f /etc/config/wireless ]; then
		echo "Generating OpenWRT wireless config..."
		wifi config > /etc/config/wireless 2>/dev/null || true
	fi
	uci set wireless.default_radio0.ssid='OpenWrt-Santoni' 2>/dev/null || true
	uci set wireless.default_radio0.encryption='psk2' 2>/dev/null || true
	uci set wireless.default_radio0.key='openwrt123' 2>/dev/null || true
	uci set wireless.radio0.disabled='0' 2>/dev/null || true
	uci commit wireless 2>/dev/null || true
	wifi reload 2>/dev/null || true
	sleep 3
	# Standalone hostapd fallback
	if ! ip link show phy0-ap0 >/dev/null 2>&1 && ! pidof wpad >/dev/null 2>&1; then
		echo "Starting standalone hostapd..."
		ip addr add 192.168.10.1/24 dev wlan0 2>/dev/null || true
		ip link set wlan0 up 2>/dev/null || true
		/usr/sbin/wpad hostapd -B /etc/hostapd.conf 2>/dev/null || true
		/etc/init.d/dnsmasq restart 2>/dev/null || true
	fi
fi

echo "=== SANTONI SETUP COMPLETE ==="

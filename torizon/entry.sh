#!/bin/bash

if [ "$1" == "dhcp" ]; then
    echo "Starting DHCP server ..."

    touch /var/lib/dhcp/dhcpd.leases
    /usr/sbin/dhcpd -d --no-pid

    exit 0
fi

chmod +s /usr/lib/qemu/qemu-bridge-helper
mkdir /etc/qemu
echo "allow docker0" > /etc/qemu/bridge.conf

_hdSize=$STORAGE
_ramSize=$RAM
_instances=$INSTANCES
_ramSize=$(($_ramSize * 1024))

if [ $_instances -gt 1 ]; then
    for i in $(seq 1 $_instances); do
        _random_mac=$(printf 'DE:AD:BE:EF:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)))
        cp /torizon.wic /torizon$i.wic

        qemu-img resize -f raw /torizon$i.wic +${_hdSize}G

        qemu-system-x86_64 \
            -name "Torizon Emulator" \
            -cpu host \
            --netdev bridge,id=hn0,br=docker0 \
            -device virtio-net-pci,netdev=hn0,id=nic1,mac=$_random_mac \
            -machine pc \
            -vga none \
            -device virtio-gpu-pci \
            -device virtio-tablet-pci \
            -display gtk,zoom-to-fit=off \
            -m $_ramSize \
            -drive file=/torizon$i.wic,format=raw \
            -bios /usr/share/ovmf/OVMF.fd \
            -enable-kvm &

    done

    while [ $(ps aux | grep qemu-system-x86_64 | wc -l) -gt 1 ]; do
        sleep 15
    done

    exit 0
fi

echo "Starting Torizon Emulator, please wait ..."

_random_mac=$(printf 'DE:AD:BE:EF:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)))
qemu-img resize -f raw /torizon.wic +${_hdSize}G

qemu-system-x86_64 \
    -name "Torizon Emulator" \
    -cpu host \
    --netdev bridge,id=hn0,br=docker0 \
    -device virtio-net-pci,netdev=hn0,id=nic1,mac=$_random_mac \
    -machine pc \
    -vga none \
    -device virtio-gpu-pci \
    -device virtio-tablet-pci \
    -display gtk,zoom-to-fit=off \
    -m $_ramSize \
    -drive file=/torizon.wic,format=raw \
    -bios /usr/share/ovmf/OVMF.fd \
    -enable-kvm \
    -serial mon:stdio

#!/bin/bash

VER="15.2"
IMG_PATH="/haos"
IMG="${IMG_PATH}/haos_ova.qcow2"
CPU=2
MEMORY=4096
HA_PORT=8123
PKG_PATH="/lzcapp/pkg/content"

function start() {
  qemu-system-x86_64 \
    -name "haos" \
    -machine q35,accel=kvm \
    -cpu host \
    -smp ${CPU} \
    -m ${MEMORY} \
    -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,readonly=on \
    -drive file=/usr/share/OVMF/OVMF_VARS.fd,if=pflash,format=raw \
    -drive file=${IMG},format=qcow2,if=none,id=scsidisk \
    -device virtio-scsi-pci \
    -device scsi-hd,drive=scsidisk \
    -netdev user,id=net0,hostfwd=tcp::${HA_PORT}-:${HA_PORT} \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    -vnc :0 -k en-us
}

function main() {
  if [ ! -f ${IMG} ]; then
    echo "Image ${IMG} not found"
    cp ${PKG_PATH}/haos_ova-${VER}.qcow2.xz ${IMG_PATH}
    cd ${IMG_PATH} && xz -d ${IMG_PATH}/haos_ova-${VER}.qcow2.xz
    mv ${IMG_PATH}/haos_ova-${VER}.qcow2 ${IMG}
    rm -rf ${IMG_PATH}/haos_ova-${VER}.qcow2.xz
  fi
  
  start

}

main
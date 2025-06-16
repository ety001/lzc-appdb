#!/bin/bash
# 这是一个临时启动器
# 等待懒猫官方解决大体积 lpk 上传问题后，删除此文件

VER="15.2"
IMG_PATH="/haos"
IMG="${IMG_PATH}/haos_ova.qcow2"
CPU=2
MEMORY=4096
HA_PORT=8123
PKG_PATH="/lzcapp/pkg/content"
IMG_REMOTE="https://alist.serv.mypi.win/d/data/haos_ova-15.2.qcow2.xz?sign=rZOnO27OStbV60bqKaCHuz55WDpP5vFH126AbYKrL-4=:0"

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
    # install axel
    dpkg -i /lzcapp/pkg/content/axel.deb
    # start download
    echo "We will download remote image"
    until axel -n 2 -o "${IMG_PATH}/haos_ova-${VER}.qcow2.xz" "${IMG_REMOTE}"; do
      echo "Download failed, retrying in 10 seconds..."
      sleep 10 
    done
    # unzip
    echo ""
    echo "Start Unzip Image"
    cd ${IMG_PATH} && xz -d ${IMG_PATH}/haos_ova-${VER}.qcow2.xz
    mv ${IMG_PATH}/haos_ova-${VER}.qcow2 ${IMG}
    rm -rf ${IMG_PATH}/haos_ova-${VER}.qcow2.xz
    echo ""
    echo "Image Ready"
    echo ""
  fi
  
  start

}

main
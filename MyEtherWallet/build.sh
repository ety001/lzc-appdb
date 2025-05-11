#!/bin/bash

VER=v6.9.22
PKG=https://github.com/MyEtherWallet/MyEtherWallet/releases/download/${VER}/MyEtherWallet-${VER}-Hash.zip

rm -rf ./dist/*
rm -rf ./*.zip
curl -L -o ./MyEtherWallet-${VER}-Hash.zip ${PKG}
unzip -o ./MyEtherWallet-${VER}-Hash.zip -d ./dist/
rm -rf ./*.zip
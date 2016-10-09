#!/bin/sh

bomb(){
	echo "${1:-error}"; exit 23
}

sudo easy_install pip || bomb "pip install failed"
sudo pip install ansible || bomb "ansible install failed"

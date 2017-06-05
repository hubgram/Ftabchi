#!/usr/bin/env bash

THIS_DIR=$(cd $(dirname $0); pwd)
cd $THIS_DIR

update() {
	git pull
	git submodule update --init --recursive
}

install() {
	sudo apt-get -y update && sudo apt-get -y upgrade 
	sudo apt-get install libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev lua-socket lua-sec lua-expat libevent-dev make unzip git redis-server autoconf g++ libjansson-dev libpython-dev expat tmux libexpat1-dev
	sudo apt-get -y update && sudo apt-get -y upgrade 
	git pull
	git submodule update --init --recursive
	patch -i "dis.patch" -p 0 --batch --forward
	RET=$?;
	git clone --recursive https://github.com/janlou/tg.git
	cd tg
	
	if [ $RET -ne 0 ]; then
		autoconf -i
	fi
	
	./configure && make

	RET=$?; if [ $RET -ne 0 ]; then
		echo "Error. Exiting."; exit $RET;
	fi
	cd ..
}

if [ "$1" = "install" ]; then
	install
elif [ "$1" = "update" ]; then
	update
else
	if [ ! -f ./tg/telegram.h ]; then
		echo "tg not found"
		echo "Run $0 install"
		exit 1
	fi

	if [ ! -f ./tg/bin/telegram-cli ]; then
		echo "tg binary not found"
		echo "Run $0 install"
		exit 1
	fi
	rm -r ../.telegram-cli/state
	./tg/bin/telegram-cli -k ./tg/tg-server.pub -s ./bot.lua -l 1 -E $@
fi

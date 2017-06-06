#!/usr/bin/env bash

THIS_DIR=$(cd $(dirname $0); pwd)
cd $THIS_DIR

update() {
	git pull
	git submodule update --init --recursive
}

install() {
	sudo apt-get -y update && sudo apt-get -y upgrade 
	sudo apt-get install libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev lua-socket lua-sec lua-expat libevent-dev make unzip git redis-server autoconf g++ libjansson-dev libpython-dev expat libexpat1-dev
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

autolaunch() {
	while true ; do
		for oldtgbots in bot-*.lua ; do
			Fbot="${oldtgbots%.*}"
			num="${Fbot/bot-/}"
			tmux kill-session -t Fbot-"$num"
			for files in "$THIS_DIR"/.telegram-cli/Fbot"$num"/downloads ; do
				rm -rf $files/*
			done
			TMUX= tmux new-session -d -s Fbot-"$num" "bash launch.sh $num"
			tmux detach -s Fbot-"$num"
		done
		echo -e " \n\e[1;32mربات ها راه اندازی شدند << \e[1;34m| Naji |\e[1;32m>> Bots are Running\n\e[0;39;49m"
		sleep 1200
	done 
}

make_config() {
	mkdir -p "$THIS_DIR"/.telegram-cli/Fbot"$1"
	cfg="$THIS_DIR"/.telegram-cli/Fbot$1/Fbot.cfg
	bot="$THIS_DIR"/bot-$1.lua
	if [[ ! -f $cfg ]]; then
		echo "default_profile = \"Fbot$1\";Fbot$1 = {config_directory = \"$THIS_DIR/.telegram-cli/Fbot$1\";test = false;msg_num = true;};" >> $cfg
	fi
	if [[ ! -f $bot ]]; then
		cat bot.lua >> bot-$1.lua
		sed -i 's/BOT-ID/'$1'/g' bot-$1.lua
	fi
}

usage() {
printf "\e[1;36m"
  cat <<EOF

>> Usage: $0 [options]
    Options:
	
      install           Install the prerequisites of Bot
      update            Update the source code of bot
      help              Print this message for help
      NUM               run bot by this NUM

EOF

printf "%s\n\e[0;39;49m"
}

if [ "$1" ]; then
	if [ "$1" = "install" ]; then
		install
	elif [ "$1" = "update" ]; then
		update
	elif 
		[ "$1" = "autolaunch" ]; then
		autolaunch
	else
		if [[ "$1" =~ ^[0-9]+$ ]] ; then
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
			make_config $1
			rm -r /.telegram-cli/Fbot$1/state
			./tg/bin/telegram-cli -k ./tg/tg-server.pub -s ./bot-$1.lua -E -c ./.telegram-cli/Fbot$1/Fbot.cfg "$@"
		else
			usage
		fi
	fi
else
	usage
fi

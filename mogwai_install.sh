#!/bin/bash

echo -e "   ______  ___                              _____   "
echo -e "   ___   |/  /____________ ___      _______ ___(_)  "
echo -e "   __  /|_/ /_  __ \_  __ `/_ | /| / /  __ `/_  /   "
echo -e "   _  /  / / / /_/ /  /_/ /__ |/ |/ // /_/ /_  /    "
echo -e "   /_/  /_/  \____/_\__, / ____/|__/ \__,_/ /_/     "
echo -e "                   /____/                           "
                                                    

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

COIN_NAME='MOG'
COIN_DAEMON='mogwaid'
COIN_CLIENT='mogwai-cli'
COIN_FOLDER='.mogwaicore'
COIN_CONFIG='mogwai.conf'
COIN_BINARIES_URL='https://github.com/mogwaicoin/mogwai/releases/download/v0.12.2.4/mogwaicore-0.12.2.4-linux64.tar.gz'
COIN_ARCHIVE='mogwaicore-0.12.2.4-linux64.tar.gz'
COIN_ARCHIVE_FOLDER='mogwaicore-0.12.2'
COIN_PORT='17777'

# Check if package is installed and if not, deploy it
function package_check {
	dpkg -s $1 &> /dev/null

	if [ $? -eq 0 ]; then
		echo "Package $1 is installed!"
    	else
		echo "Package $1 is NOT installed!"
		apt install $1 -y
	fi
}

# Pre-requirements check
function prereq_check {
	package_check curl
	package_check wget
	package_check pwgen
}

# Download and unpack binaries
function install_binaries {
	echo -e "${GREEN}Downloading and installing binaries for ${COIN_NAME}${NC}"
	echo ""
	mkdir /tmp/${COIN_NAME}_deploy
	cd /tmp/${COIN_NAME}_deploy
	wget ${COIN_BINARIES_URL}
	tar -xvf ${COIN_ARCHIVE}
	cd ${COIN_ARCHIVE_FOLDER}
	cp -R * /usr/local
	rm -rf /tmp/${COIN_NAME}_deploy
}

# Install service
function add_service {
	echo -e "${GREEN}Adding ${COIN_DAEMON}.service to systemd${NC}"
	echo ""
	echo \
	"[Unit]
Description=${COIN_NAME} Coin Service
After=network.target

[Service]
User=root
Group=root
Type=forking
PIDFile=/root/${COIN_FOLDER}/${COIN_DAEMON}.pid
ExecStart=/usr/local/bin/${COIN_DAEMON} -daemon -conf=/root/${COIN_FOLDER}/${COIN_CONFIG} -datadir=/root/${COIN_FOLDER}
ExecStop=/usr/local/bin/${COIN_CLIENT} -conf=/root/${COIN_FOLDER}/${COIN_CONFIG} -datadir=/root/${COIN_FOLDER} stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
Alias=${COIN_DAEMON}.service" | tee /lib/systemd/system/${COIN_DAEMON}.service
	chmod 664 /lib/systemd/system/${COIN_DAEMON}.service
	systemctl enable /lib/systemd/system/${COIN_DAEMON}.service
}

# Create Masternode configuration
function generate_masternode_configuration {
	echo -e "${GREEN}Creating ${COIN_CONFIG}${NC}"
	echo ""
	mkdir /root/${COIN_FOLDER}
	echo \
	"rpcuser=m0g`pwgen -1 20 -n`
rpcpassword=`pwgen -1 40 -n`
rpcallowip=127.0.0.1
server=1
listen=
daemon=1
masternode=1
masternodeprivkey=<PRIVATE_KEY>
externalip=`curl ipinfo.io/ip`
port=${COIN_PORT}
	" | tee /root/${COIN_FOLDER}/${COIN_CONFIG}
}

# Install Sentinel
function install_sentinel {
	echo -e "${GREEN}Installing ${COIN_NAME}${NC} Sentinel"
	echo ""
	cd ~/.mogwaicore
	apt-get install -y git python-virtualenv virtualenv
	git clone https://github.com/mogwaicoin/mogwai-sentinel.git sentinel && cd sentinel
	virtualenv ./venv
	./venv/bin/pip install -r requirements.txt
	croncmd="cd /root/.mogwaicore/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1"
	cronjob="* * * * * $croncmd"
	( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -
}

# Display installation summary
function display_summary {
	echo "${GREEN}Node installation finished.${NC}"
}

prereq_check
install_binaries
add_service
generate_masternode_configuration
install_sentinel
display_summary
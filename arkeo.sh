#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export ARKEO_CHAIN_ID=arkeo-testnet-3" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 -y

# install go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.7.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.profile
source .profile

# download binary
cd $HOME && git clone https://github.com/arkeonetwork/arkeo
cd arkeo
git checkout master
TAG=testnet make install

# Prepare cosmovisor directories
mkdir -p $HOME/.arkeo/cosmovisor/genesis/bin
ln -s $HOME/.arkeo/cosmovisor/genesis $HOME/.arkeo/cosmovisor/current -f

# Copy binary to cosmovisor directory
cp $(which arkeod) $HOME/.arkeo/cosmovisor/genesis/bin

# config
arkeod config chain-id $ARKEO_CHAIN_ID
arkeod config keyring-backend test

# init
arkeod init $NODENAME --chain-id $ARKEO_CHAIN_ID

# download genesis and addrbook
curl -L https://snapshots-testnet.nodejumper.io/arkeo/genesis.json > $HOME/.arkeo/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/arkeo/addrbook.json > $HOME/.arkeo/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.01uarkeo\"|" $HOME/.arkeo/config/app.toml

# set peers and seeds
SEEDS="9dfa5f2d19c1174baf5e597965394269e654f9b7@seed31.innovationtheory.com:26656,bb761c984bd990f3055f412917396754cd22af7a@validator31.innovationtheory.com:26656"
PEERS="d579b42752617069d97c26722c0b44e3ec011e8a@65.109.92.241:10356,fd1f96034775faa95ce716dc419a548e65a5ae56@65.108.206.118:36656,eac1be3f271d857cc641ac4552bae46f4e98e606@65.108.13.154:42656,81e36f94351d47803b8e1e0d0ad2d2e8e14ed36b@54.235.252.102:26656,0564aaa233c8741084b0c09805b8e0d251b61462@[2a01:4f9:3051:4762::2]:22856,bb761c984bd990f3055f412917396754cd22af7a@71.218.36.205:26656,0370e95d59bdfffb15f08749462c960574608451@[2a01:4f8:221:4267::2]:26656,7ec7a7a00ed2b35e3072e7420636f67675599448@142.132.205.82:14056,8c2d799bcc4fbf44ef34bbd2631db5c3f4619e41@[2a01:4f8:a0:92d3::2]:60656,893a44b8501faa22fbe2f4d61c6586f231bd1638@[2a01:4f9:5a:1a1d::2]:33656,e6b058d1d6be000d67b87e9d11cb0de1bba1e477@[2a01:4f9:5a:55d9::2]:42656,12154ecc692cb994593bf9d9a8acdc92e700005f@45.85.250.108:33656,ba5e69bf31c601e91be3b876b3db29eb406cbfd9@[2a01:4f9:1a:9c22::2]:42656,0909dbada3305d135e4b86775a7c39b5578e5978@65.108.111.236:55926,3569aeed70d799a29f5d2128a6e4ccdb7624c603@[2a01:4f9:5a:160b::2]:22856,709ae59c5e9098aeacf333e1ccbaf2827e07fd8d@[2a01:4f9:5a:14de::2]:22856,ebfc883c33943f248437312a2d9c5d88c81bd843@[2a01:4f9:1a:a626::2]:22856,bf8b66267e3e1e7ac89c391658522e0a4f0dc161@[2a01:4ff:f0:846d::1]:14056,86a22aef01672e8f255bb06c945b44b2484097cf@[2a01:4f9:3071:1b4f::2]:14056,fe14a2636bba5675f62998635f7751d7740a4087@[2a01:4f9:6b:25eb::2]:14056"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.arkeo/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.arkeo/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.arkeo/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.arkeo/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.arkeo/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.arkeo/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.arkeo/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.arkeo/config/config.toml

# Install Cosmovisor
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.6.0

# create service
sudo tee /etc/systemd/system/arkeod.service > /dev/null << EOF
[Unit]
Description=Arkeo Network node service
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.arkeo
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.arkeo"
Environment="DAEMON_NAME=arkeod"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
[Install]
WantedBy=multi-user.target
EOF

# reset
arkeod tendermint unsafe-reset-all --home $HOME/.arkeo --keep-addr-book 
curl https://snapshots-testnet.nodejumper.io/arkeo/arkeo_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.arkeo

# start service
sudo systemctl daemon-reload
sudo systemctl enable arkeod
sudo systemctl restart arkeod

break
;;

"Create Wallet")
arkeod keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
ARKEO_WALLET_ADDRESS=$(arkeod keys show $WALLET -a)
ARKEO_VALOPER_ADDRESS=$(arkeod keys show $WALLET --bech val -a)
echo 'export ARKEO_WALLET_ADDRESS='${ARKEO_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export ARKEO_VALOPER_ADDRESS='${ARKEO_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
arkeod tx staking create-validator \
--amount=1000000uarkeo \
--pubkey=$(arkeod tendermint show-validator) \
--moniker=$NODENAME \
--chain-id=arkeo-testnet-3 \
--commission-rate=0.10 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=wallet \
--gas-prices=0.01uarkeo \
--gas-adjustment=1.5 \
--gas=300000 \
-y  
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done

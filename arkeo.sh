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
echo "export ARKEO_CHAIN_ID=arkeo" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 -y

# install go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.21.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source .bash_profile

# download binary
cd $HOME && git clone https://github.com/arkeonetwork/arkeo
cd arkeo
git checkout master
TAG=testnet make install

# config
arkeod config chain-id $ARKEO_CHAIN_ID
arkeod config keyring-backend test

# init
arkeod init $NODENAME --chain-id $ARKEO_CHAIN_ID

# download genesis and addrbook
curl -Ls https://ss-t.arkeo.nodestake.org/genesis.json > $HOME/.arkeo/config/genesis.json
curl -Ls https://ss-t.arkeo.nodestake.org/addrbook.json > $HOME/.arkeo/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0001uarkeo\"|" $HOME/.arkeo/config/app.toml

# set peers and seeds
SEEDS="364ff02df0007a498eca4039688c46fd4190e771@rpc-t.arkeo.nodestake.org:666"
PEERS="beeef4607ebbb98f5b2293b6407765067a73e781@54.144.10.49:26656,22ae7b9bd6aed0b69e4599885529ed84a577bfc8@65.109.23.114:22856,78820c26ac2b680a610df13fc651d2d09d18bc48@65.109.57.180:26656,a25610b1ed8f47ab662b17921cb9cafbcfb1e012@142.132.194.124:11304"
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

# create service
sudo tee /etc/systemd/system/arkeod.service > /dev/null << EOF
[Unit]
Description=Arkeo Network Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which arkeod) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset
arkeod tendermint unsafe-reset-all --home $HOME/.arkeo --keep-addr-book 
SNAP_NAME=$(curl -s https://ss-t.arkeo.nodestake.org/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://ss-t.arkeo.nodestake.org/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.arkeo

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
--chain-id=arkeo \
--commission-rate=0.10 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=wallet \
--gas-prices=0.1uarkeo \
--gas-adjustment=1.5 \
--gas=auto \
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

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
sudo apt install curl build-essential git wget jq make gcc tmux chrony -y

# install go
if ! [ -x "$(command -v go)" ]; then
ver="1.19" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version
fi

# download binary
cd $HOME
git clone https://github.com/arkeonetwork/arkeo && cd arkeo
wget https://share101.utsa.tech/arkeo/arkeod
chmod +x arkeod
mv arkeod /usr/local/bin/arkeod

# config
arkeod config chain-id $ARKEO_CHAIN_ID
arkeod config keyring-backend test

# init
arkeod init $NODENAME --chain-id $ARKEO_CHAIN_ID

# download genesis and addrbook
curl -s http://seed.arkeo.network:26657/genesis | jq '.result.genesis' > $HOME/.arkeo/config/genesis.json
curl -s https://snapshots-testnet.nodejumper.io/arkeonetwork-testnet/addrbook.json > $HOME/.arkeo/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0001uarkeo\"|" $HOME/.arkeo/config/app.toml

# set peers and seeds
SEEDS="20e1000e88125698264454a884812746c2eb4807@seeds.lavenderfive.com:22856"
PEERS="d1ade0f7afb6d0e99dcfd3a8d1373a03d459adb8@158.220.91.214:15756,41e9f8771e28a5b51d6a99529ccf55db19f34abe@5.161.70.240:26656,7139c267a8b8bb03cd2cbf0cf7092ffd1a475ef7@65.109.103.140:15756,1a86a2a0593f29180d4eb3c52b5863bf84e708dc@88.198.52.46:22856,25a9af68f987e254e50d6d7e6a1e68a5a40c1b7c@65.109.92.148:60556"
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
curl https://snapshots-testnet.nodejumper.io/arkeonetwork-testnet/arkeonetwork-testnet_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.arkeo

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

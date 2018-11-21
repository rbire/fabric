set -e
export MSYS_NO_PATHCONV=1
starttime=$(date +%s)

if [ ! -d ~/.hfc-key-store/ ]; then
	mkdir ~/.hfc-key-store/
fi

printf "\nStopping containers...\n\n"
docker stop $(docker ps -aq)

printf "\nRemoving containers...\n\n"
docker rm $(docker ps -aq)

printf "\nRemoving chaincode image...\n\n"
docker rmi $(docker images dev-* -q)

printf "\nRemoving user accounts...\n\n"
rm -f ~/.hfc-key-store/*

printf "\nLanunching new containers...\n\n"
cd ../network
./start.sh

printf "\nStaring cli container...\n\n"
docker-compose -f ./docker-compose.yml up -d cli

printf "\nInstalling chaincode...\n\n"
CC_SRC_PATH=/opt/gopath/src/github.com/events-app/node
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode install -n events -v 1.0 -p "$CC_SRC_PATH" -l node
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode instantiate -o orderer.example.com:7050 -C mychannel -n events -l node -v 1.0  -c '{"Args":[""]}' -P "OR ('Org1MSP.member','Org2MSP.member')"
sleep 30
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n events -c '{"function":"initLedger","Args":[""]}'
sleep 10
printf "\nRegistering users...\n\n"
cd ../setup
node registerAdmin.js
node registerUser.js
printf "\nAll set..\n\n"
printf "\nTotal execution time : $(($(date +%s) - starttime)) secs ...\n\n"

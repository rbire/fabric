##############################################################
#installing hyperledger fabric peer to join RBI network
#coudhdb
#https://github.com/helm/charts/tree/master/stable/hlf-couchdb
#peer
#https://github.com/helm/charts/tree/master/stable/hlf-peer
##############################################################
export NUM=1
export CA_INGRESS='ca.rbi.events'
export ORD_INGRESS='ord.rbi.events:443'

#need peer admin and peer node users registered by network admin to enroll
export PEER_ADMIN_ID = 'peer-admin-id'
export PEER_ADMIN_PWD = 'peer-admin-passworkd'
export PEER_NODE_ID = 'peer-node-id'
export PEER_NODE_PWD = 'peer-node-passworkd'
#enroll users to get keys and certs 
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -u https://${PEER_ADMIN_ID}:${PEER_ADMIN_PWD}@$CA_INGRESS -M ./PeerMSP
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u htts://${PEER_NODE_ID}:${PEER_NODE_PWD}@$CA_INGRESS -M ${PEER_NODE_ID}_MSP
#save keys and certs to k8 secrets
mkdir -p ./config/PeerMSP/admincerts
cp ./config/PeerMSP/signcerts/* ./config/PeerMSP/admincerts
ORG_CERT=$(ls ./config/PeerMSP/admincerts/cert.pem)
ORG_KEY=$(ls ./config/PeerMSP/keystore/*_sk)
CA_CERT=$(ls ./config/PeerMSP/cacerts/*.pem)
NODE_CERT=$(ls ./config/${PEER_NODE_ID}_MSP/signcerts/*.pem)
NODE_KEY=$(ls ./config/${PEER_NODE_ID}_MSP/keystore/*_sk)
kubectl create secret generic -n peers hlf--peer-adminkey --from-file=key.pem=$ORG_KEY
kubectl create secret generic -n peers hlf--peer-admincert --from-file=cert.pem=$ORG_CERT
kubectl create secret generic -n peers hlf--peer-ca-cert --from-file=cacert.pem=$CA_CERT
kubectl create secret generic -n peers hlf--peer-idcert --from-file=cert.pem=${NODE_CERT}
kubectl create secret generic -n peers hlf--peer-idkey --from-file=key.pem=${NODE_KEY}
#install charts
helm install stable/hlf-couchdb -n cdb --namespace peers -f ./cdb.yaml
sleep 20
helm install stable/hlf-peer -n peer --namespace peers -f ./peer.yaml
sleep 20
#wait for peer to start
kubectl get pods -n peers
PEER_POD=$(kubectl get pods -n peers -l "app=hlf-peer,release=peer" -o jsonpath="{.items[0].metadata.name}")
#copy chaincode to the running container
kubectl cp  ./cc $PEER_POD:/var/hyperledger/cc -n peers

#run these manually on peer to join channel and install chaincode
kubectl exec -n peers -it $PEER_POD bash
CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH
peer channel fetch config /var/hyperledger/mychannel.block -c mychannel -o $ORD_INGRESS
peer channel join -b /var/hyperledger/mychannel.block
peer chaincode install -n events -v 1.0 -l node -p /var/hyperledger/cc 
peer chaincode instantiate -o $ORD_INGRESS -C mychannel -n events -l node -v 1.0  -c '{"Args":[""]}' -P "OR ('PeerMSP.member')"
peer chaincode invoke -o $ORD_INGRESS -C mychannel -n events -c '{"function":"initLedger","Args":[""]}'
exit

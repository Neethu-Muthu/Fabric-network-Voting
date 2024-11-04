#!/bin/bash

echo "------------Register the ca admin for each organization—----------------"

docker compose -f docker/docker-compose-ca.yaml up -d
sleep 3
sudo chmod -R 777 organizations/

echo "------------Register and enroll the users for each organization—-----------"

chmod +x registerEnroll.sh

./registerEnroll.sh
sleep 3

echo "—-------------Build the infrastructure—-----------------"

docker compose -f docker/docker-compose-4org.yaml up -d
sleep 3

echo "-------------Generate the genesis block—-------------------------------"

export FABRIC_CFG_PATH=${PWD}/config

export CHANNEL_NAME=votingchannel

configtxgen -profile ChannelUsingRaft -outputBlock ${PWD}/channel-artifacts/${CHANNEL_NAME}.block -channelID $CHANNEL_NAME

echo "------ Create the application channel------"

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/voting.com/orderers/orderer.voting.com/msp/tlscacerts/tlsca.voting.com-cert.pem

export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/voting.com/orderers/orderer.voting.com/tls/server.crt

export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/voting.com/orderers/orderer.voting.com/tls/server.key

osnadmin channel join --channelID $CHANNEL_NAME --config-block ${PWD}/channel-artifacts/$CHANNEL_NAME.block -o localhost:7053 --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY
sleep 2
osnadmin channel list -o localhost:7053 --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY
sleep 2

export FABRIC_CFG_PATH=${PWD}/peercfg
export commissioner_PEER_TLSROOTCERT=${PWD}/organizations/peerOrganizations/commissioner.voting.com/peers/peer0.commissioner.voting.com/tls/ca.crt
export voterRegistrationAuthority_PEER_TLSROOTCERT=${PWD}/organizations/peerOrganizations/voterRegistrationAuthority.voting.com/peers/peer0.voterRegistrationAuthority.voting.com/tls/ca.crt
export votingBooth_PEER_TLSROOTCERT=${PWD}/organizations/peerOrganizations/votingBooth.voting.com/peers/peer0.votingBooth.voting.com/tls/ca.crt
export auditor_PEER_TLSROOTCERT=${PWD}/organizations/peerOrganizations/auditor.voting.com/peers/peer0.auditor.voting.com/tls/ca.crt


export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=commissionerMSP
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/commissioner.voting.com/peers/peer0.commissioner.voting.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/commissioner.voting.com/users/Admin@commissioner.voting.com/msp
export CORE_PEER_ADDRESS=localhost:7051
sleep 2

echo "—---------------Join commissioner peer to the channel—-------------"

echo ${FABRIC_CFG_PATH}
sleep 2
peer channel join -b ${PWD}/channel-artifacts/${CHANNEL_NAME}.block
sleep 3

echo "-----channel List----"
peer channel list

echo "—-------------commissioner anchor peer update—-----------"


peer channel fetch config ${PWD}/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
sleep 1

cd channel-artifacts

configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
jq '.data.data[0].payload.data.config' config_block.json > config.json

cp config.json config_copy.json

jq '.channel_group.groups.Application.groups.commissionerMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.commissioner.voting.com","port": 7051}]},"version": "0"}}' config_copy.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output config_update.pb

configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb

cd ..

peer channel update -f ${PWD}/channel-artifacts/config_update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050  --ordererTLSHostnameOverride orderer.voting.com --tls --cafile $ORDERER_CA
sleep 1

echo "—---------------package chaincode—-------------"




peer lifecycle chaincode package vote-contract.tar.gz --path ${PWD}/../Chaincode/Vote-Contract  --lang node --label basic_1.0


sleep 1

export CC_PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid vote-contract.tar.gz)

echo "—---------------install chaincode in commissioner peer—-------------"

peer lifecycle chaincode install vote-contract.tar.gz
sleep 3

peer lifecycle chaincode queryinstalled

echo "—---------------Approve chaincode in commissioner peer—-------------"

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --collections-config ../Chaincode/Vote-Contract/collection-voting.json --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA --waitForEvent
sleep 1

export CORE_PEER_LOCALMSPID=voterRegistrationAuthorityMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/voterRegistrationAuthority.voting.com/peers/peer0.voterRegistrationAuthority.voting.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/voterRegistrationAuthority.voting.com/users/Admin@voterRegistrationAuthority.voting.com/msp
export CORE_PEER_ADDRESS=localhost:8051

echo "—---------------Join voterRegistrationAuthority peer0 to the channel—-------------"

peer channel join -b ${PWD}/channel-artifacts/$CHANNEL_NAME.block
sleep 1
peer channel list




echo "—-------------voterRegistrationAuthority anchor peer update—-----------"


peer channel fetch config ${PWD}/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
sleep 1

cd channel-artifacts

configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
jq '.data.data[0].payload.data.config' config_block.json > config.json

cp config.json config_copy.json

jq '.channel_group.groups.Application.groups.voterRegistrationAuthorityMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.voterRegistrationAuthority.voting.com","port": 8051}]},"version": "0"}}' config_copy.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output config_update.pb

configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb

cd ..

peer channel update -f ${PWD}/channel-artifacts/config_update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050  --ordererTLSHostnameOverride orderer.voting.com --tls --cafile $ORDERER_CA
peer channel getinfo -c $CHANNEL_NAME
sleep 1

echo "—---------------install chaincode in voterRegistrationAuthority peer—-------------"

peer lifecycle chaincode install vote-contract.tar.gz
sleep 3

peer lifecycle chaincode queryinstalled

echo "—---------------Approve chaincode in votingBooth peer—-------------"

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --collections-config ../Chaincode/Vote-Contract/collection-voting.json --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA --waitForEvent
sleep 1



export CORE_PEER_LOCALMSPID=votingBoothMSP 
export CORE_PEER_ADDRESS=localhost:9051 
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/votingBooth.voting.com/peers/peer0.votingBooth.voting.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/votingBooth.voting.com/users/Admin@votingBooth.voting.com/msp

echo "—---------------Join votingBooth peer0 to the channel—-------------"

peer channel join -b ${PWD}/channel-artifacts/$CHANNEL_NAME.block
sleep 1
peer channel list

echo "—-------------votingBooth anchor peer update—-----------"

# peer channel join -b ${PWD}/channel-artifacts/$CHANNEL_NAME.block --tls --cafile $ORDERER_CA

peer channel fetch config ${PWD}/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
sleep 1

cd channel-artifacts

configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
jq '.data.data[0].payload.data.config' config_block.json > config.json

cp config.json config_copy.json

jq '.channel_group.groups.Application.groups.votingBoothMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.votingBooth.voting.com","port": 9051}]},"version": "0"}}' config_copy.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output config_update.pb

configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb

cd ..

peer channel update -f ${PWD}/channel-artifacts/config_update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050  --ordererTLSHostnameOverride orderer.voting.com --tls --cafile $ORDERER_CA
sleep 2

echo "—---------------install chaincode in votingBooth peer—-------------"

peer lifecycle chaincode install vote-contract.tar.gz
sleep 3

peer lifecycle chaincode queryinstalled

echo "—---------------Approve chaincode in votingBooth peer—-------------"

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --collections-config ../Chaincode/Vote-Contract/collection-voting.json --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA --waitForEvent
sleep 1

export CORE_PEER_LOCALMSPID=votingBoothMSP 
export CORE_PEER_ADDRESS=localhost:9053 
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/votingBooth.voting.com/peers/peer1.votingBooth.voting.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/votingBooth.voting.com/users/Admin@votingBooth.voting.com/msp

echo "—---------------Join votingBooth peer1 to the channel—-------------"

echo ${FABRIC_CFG_PATH}
sleep 2
peer channel join -b ${PWD}/channel-artifacts/${CHANNEL_NAME}.block
sleep 3

echo "-----channel List----"
peer channel list




export CORE_PEER_LOCALMSPID=auditorMSP 
export CORE_PEER_ADDRESS=localhost:11051 
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/auditor.voting.com/peers/peer0.auditor.voting.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/auditor.voting.com/users/Admin@auditor.voting.com/msp

echo "—---------------Join auditor peer to the channel—-------------"

peer channel join -b ${PWD}/channel-artifacts/$CHANNEL_NAME.block
sleep 1
peer channel list

echo "—-------------auditor anchor peer update—-----------"


peer channel fetch config ${PWD}/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
sleep 1

cd channel-artifacts

configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
jq '.data.data[0].payload.data.config' config_block.json > config.json

cp config.json config_copy.json

jq '.channel_group.groups.Application.groups.auditorMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.auditor.voting.com","port": 11051}]},"version": "0"}}' config_copy.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output config_update.pb

configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb

cd ..

peer channel update -f ${PWD}/channel-artifacts/config_update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050  --ordererTLSHostnameOverride orderer.voting.com --tls --cafile $ORDERER_CA
sleep 1

echo "—---------------install chaincode in auditor peer—-------------"

peer lifecycle chaincode install vote-contract.tar.gz
sleep 3

peer lifecycle chaincode queryinstalled

echo "—---------------Approve chaincode in auditor peer—-------------"

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --collections-config ../Chaincode/Vote-Contract/collection-voting.json --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA --waitForEvent
sleep 1


echo "—---------------Commit chaincode in auditor peer—-------------"


peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --sequence 1 --collections-config ../Chaincode/Vote-Contract/collection-voting.json  --tls --cafile $ORDERER_CA --output json

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.voting.com --channelID $CHANNEL_NAME --name vote-contract --version 1.0 --sequence 1 --collections-config ../Chaincode/Vote-Contract/collection-voting.json  --tls --cafile $ORDERER_CA --peerAddresses localhost:7051 --tlsRootCertFiles $commissioner_PEER_TLSROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $votingBooth_PEER_TLSROOTCERT --peerAddresses localhost:8051 --tlsRootCertFiles $voterRegistrationAuthority_PEER_TLSROOTCERT --peerAddresses localhost:11051 --tlsRootCertFiles $auditor_PEER_TLSROOTCERT
sleep 1

peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name vote-contract --cafile $ORDERER_CA



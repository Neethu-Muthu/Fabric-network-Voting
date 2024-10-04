#!/bin/bash

function createvoters() {
  echo "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/voters.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voters.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca-voters --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voters.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voters.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voters.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voters.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/voters.example.com/msp/config.yaml"

  # Since the CA serves as both the organization CA and TLS CA, copy the org's root cert that was generated by CA startup into the org level ca and tlsca directories

  # Copy voters's CA cert to voters's /msp/tlscacerts directory (for use in the channel MSP definition)
  mkdir -p "${PWD}/organizations/peerOrganizations/voters.example.com/msp/tlscacerts"
  cp "${PWD}/organizations/fabric-ca/voters/ca-cert.pem" "${PWD}/organizations/peerOrganizations/voters.example.com/msp/tlscacerts/ca.crt"

  # Copy voters's CA cert to voters's /tlsca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/voters.example.com/tlsca"
  cp "${PWD}/organizations/fabric-ca/voters/ca-cert.pem" "${PWD}/organizations/peerOrganizations/voters.example.com/tlsca/tlsca.voters.example.com-cert.pem"

  # Copy voters's CA cert to voters's /ca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/voters.example.com/ca"
  cp "${PWD}/organizations/fabric-ca/voters/ca-cert.pem" "${PWD}/organizations/peerOrganizations/voters.example.com/ca/ca.voters.example.com-cert.pem"

  echo "Registering peer0"
  set -x
  fabric-ca-client register --caname ca-voters --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering user"
  set -x
  fabric-ca-client register --caname ca-voters --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering the org admin"
  set -x
  fabric-ca-client register --caname ca-voters --id.name votersadmin --id.secret votersadminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-voters -M "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/voters.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/msp/config.yaml"

  echo "Generating the peer0-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-voters -M "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls" --enrollment.profile tls --csr.hosts peer0.voters.example.com --csr.hosts localhost --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  # Copy the tls CA cert, server cert, server keystore to well known file names in the peer's tls directory that are referenced by peer startup config
  cp "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/tlscacerts/"* "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/ca.crt"
  cp "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/signcerts/"* "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/server.crt"
  cp "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/keystore/"* "${PWD}/organizations/peerOrganizations/voters.example.com/peers/peer0.voters.example.com/tls/server.key"

  echo "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@localhost:7054 --caname ca-voters -M "${PWD}/organizations/peerOrganizations/voters.example.com/users/User1@voters.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/voters.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/voters.example.com/users/User1@voters.example.com/msp/config.yaml"

  echo "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://votersadmin:votersadminpw@localhost:7054 --caname ca-voters -M "${PWD}/organizations/peerOrganizations/voters.example.com/users/Admin@voters.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/voters/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/voters.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/voters.example.com/users/Admin@voters.example.com/msp/config.yaml"
}

function createcommissioner() {
  echo "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/commissioner.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/commissioner.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:8054 --caname ca-commissioner --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-commissioner.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-commissioner.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-commissioner.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-commissioner.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/config.yaml"

  # Since the CA serves as both the organization CA and TLS CA, copy the org's root cert that was generated by CA startup into the org level ca and tlsca directories

  # Copy commissioner's CA cert to commissioner's /msp/tlscacerts directory (for use in the channel MSP definition)
  mkdir -p "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/tlscacerts"
  cp "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem" "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/tlscacerts/ca.crt"

  # Copy commissioner's CA cert to commissioner's /tlsca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/commissioner.example.com/tlsca"
  cp "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem" "${PWD}/organizations/peerOrganizations/commissioner.example.com/tlsca/tlsca.commissioner.example.com-cert.pem"

  # Copy commissioner's CA cert to commissioner's /ca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/commissioner.example.com/ca"
  cp "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem" "${PWD}/organizations/peerOrganizations/commissioner.example.com/ca/ca.commissioner.example.com-cert.pem"

  echo "Registering peer0"
  set -x
  fabric-ca-client register --caname ca-commissioner --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering user"
  set -x
  fabric-ca-client register --caname ca-commissioner --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering the org admin"
  set -x
  fabric-ca-client register --caname ca-commissioner --id.name commissioneradmin --id.secret commissioneradminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:8054 --caname ca-commissioner -M "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/msp/config.yaml"

  echo "Generating the peer0-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:8054 --caname ca-commissioner -M "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls" --enrollment.profile tls --csr.hosts peer0.commissioner.example.com --csr.hosts localhost --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  # Copy the tls CA cert, server cert, server keystore to well known file names in the peer's tls directory that are referenced by peer startup config
  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/tlscacerts/"* "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/ca.crt"
  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/signcerts/"* "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/server.crt"
  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/keystore/"* "${PWD}/organizations/peerOrganizations/commissioner.example.com/peers/peer0.commissioner.example.com/tls/server.key"

  echo "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@localhost:8054 --caname ca-commissioner -M "${PWD}/organizations/peerOrganizations/commissioner.example.com/users/User1@commissioner.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/commissioner.example.com/users/User1@commissioner.example.com/msp/config.yaml"

  echo "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://commissioneradmin:commissioneradminpw@localhost:8054 --caname ca-commissioner -M "${PWD}/organizations/peerOrganizations/commissioner.example.com/users/Admin@commissioner.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/commissioner/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/commissioner.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/commissioner.example.com/users/Admin@commissioner.example.com/msp/config.yaml"
}

function createauditor() {
  echo "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/auditor.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/auditor.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:6054 --caname ca-auditor --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-6054-ca-auditor.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-6054-ca-auditor.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-6054-ca-auditor.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-6054-ca-auditor.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/config.yaml"

  # Since the CA serves as both the organization CA and TLS CA, copy the org's root cert that was generated by CA startup into the org level ca and tlsca directories

  # Copy auditor's CA cert to auditor's /msp/tlscacerts directory (for use in the channel MSP definition)
  mkdir -p "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/tlscacerts"
  cp "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem" "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/tlscacerts/ca.crt"

  # Copy auditor's CA cert to auditor's /tlsca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/auditor.example.com/tlsca"
  cp "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem" "${PWD}/organizations/peerOrganizations/auditor.example.com/tlsca/tlsca.auditor.example.com-cert.pem"

  # Copy auditor's CA cert to auditor's /ca directory (for use by clients)
  mkdir -p "${PWD}/organizations/peerOrganizations/auditor.example.com/ca"
  cp "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem" "${PWD}/organizations/peerOrganizations/auditor.example.com/ca/ca.auditor.example.com-cert.pem"

  echo "Registering peer0"
  set -x
  fabric-ca-client register --caname ca-auditor --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering user"
  set -x
  fabric-ca-client register --caname ca-auditor --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering the org admin"
  set -x
  fabric-ca-client register --caname ca-auditor --id.name auditoradmin --id.secret auditoradminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:6054 --caname ca-auditor -M "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/msp/config.yaml"

  echo "Generating the peer0-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:6054 --caname ca-auditor -M "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls" --enrollment.profile tls --csr.hosts peer0.auditor.example.com --csr.hosts localhost --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  # Copy the tls CA cert, server cert, server keystore to well known file names in the peer's tls directory that are referenced by peer startup config
  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/tlscacerts/"* "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/ca.crt"
  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/signcerts/"* "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/server.crt"
  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/keystore/"* "${PWD}/organizations/peerOrganizations/auditor.example.com/peers/peer0.auditor.example.com/tls/server.key"

  echo "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@localhost:6054 --caname ca-auditor -M "${PWD}/organizations/peerOrganizations/auditor.example.com/users/User1@auditor.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/auditor.example.com/users/User1@auditor.example.com/msp/config.yaml"

  echo "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://auditoradmin:auditoradminpw@localhost:6054 --caname ca-auditor -M "${PWD}/organizations/peerOrganizations/auditor.example.com/users/Admin@auditor.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/auditor/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/peerOrganizations/auditor.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/auditor.example.com/users/Admin@auditor.example.com/msp/config.yaml"
}


function createOrderer() {
  echo "Enrolling the CA admin"
  mkdir -p organizations/ordererOrganizations/example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml"

  # Since the CA serves as both the organization CA and TLS CA, copy the org's root cert that was generated by CA startup into the org level ca and tlsca directories

  # Copy orderer org's CA cert to orderer org's /msp/tlscacerts directory (for use in the channel MSP definition)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts"
  cp "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

  # Copy orderer org's CA cert to orderer org's /tlsca directory (for use by clients)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/tlsca"
  cp "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"

  echo "Registering orderer"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Registering the orderer admin"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo "Generating the orderer msp"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/config.yaml"

  echo "Generating the orderer-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls" --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  # Copy the tls CA cert, server cert, server keystore to well known file names in the orderer's tls directory that are referenced by orderer startup config
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/signcerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/keystore/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"

  # Copy orderer org's CA cert to orderer's /msp/tlscacerts directory (for use in the orderer MSP definition)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

  echo "Generating the admin msp"
  set -x
  fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml"
}

createvoters
createcommissioner
createauditor
createOrderer
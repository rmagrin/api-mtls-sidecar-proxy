#!/usr/bin/env bash

BASE_DIR=temp/certs
CA_DIR=${BASE_DIR}/ca
SERVER_DIR=${BASE_DIR}/server
CLIENT_DIR=${BASE_DIR}/client

# CA certificate
mkdir -p ${CA_DIR}

cat > ${CA_DIR}/ca.conf <<EOF
[ req ]
prompt             = no
distinguished_name = req_distinguished_name
x509_extensions    = v3_ca

[ req_distinguished_name ]
CN = mtls.dev

[ v3_ca ]
keyUsage = critical,keyCertSign,cRLSign
basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
EOF

openssl req -x509 \
    -nodes \
    -set_serial "0x`openssl rand -hex 20`" \
    -days 364 \
    -sha256 \
    -newkey ec:<(openssl ecparam -name prime256v1) \
    -config ${CA_DIR}/ca.conf \
    -keyout ${CA_DIR}/ca.key \
    -out ${CA_DIR}/ca.pem

# Server certificate
mkdir -p ${SERVER_DIR}

openssl ecparam -name prime256v1 \
    -genkey \
    -noout \
    -out ${SERVER_DIR}/server.key

cat > ${SERVER_DIR}/server-csr.cnf <<EOF
[ req ]
prompt             = no
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
CN = sidecar.mtls.labbs.com.br

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = sidecar.mtls.labbs.com.br
EOF

openssl req -new \
    -key ${SERVER_DIR}/server.key \
    -config ${SERVER_DIR}/server-csr.cnf \
    -out ${SERVER_DIR}/server.csr

cat > ${SERVER_DIR}/server-pem.cnf <<EOF
keyUsage                = digitalSignature,keyEncipherment
extendedKeyUsage        = serverAuth
basicConstraints        = critical,CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = sidecar.mtls.labbs.com.br
EOF

openssl x509 -req \
    -set_serial "0x`openssl rand -hex 20`" \
    -days 364 \
    -sha256 \
    -in ${SERVER_DIR}/server.csr \
    -CA ${CA_DIR}/ca.pem \
    -CAkey ${CA_DIR}/ca.key \
    -CAcreateserial \
    -extfile ${SERVER_DIR}/server-pem.cnf \
    -out ${SERVER_DIR}/server.pem

# Client certificate
mkdir -p ${CLIENT_DIR}

openssl ecparam -name prime256v1 \
    -genkey \
    -noout \
    -out ${CLIENT_DIR}/client.key

cat > ${CLIENT_DIR}/client-csr.cnf <<EOF
[ req ]
prompt             = no
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
CN = Sandman
EOF

openssl req -new \
    -key ${CLIENT_DIR}/client.key \
    -config ${CLIENT_DIR}/client-csr.cnf \
    -out ${CLIENT_DIR}/client.csr

cat > ${CLIENT_DIR}/client-pem.cnf <<EOF
keyUsage                = digitalSignature,keyEncipherment
extendedKeyUsage        = clientAuth
basicConstraints        = critical,CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
EOF

openssl x509 -req \
    -set_serial "0x`openssl rand -hex 20`" \
    -days 364 \
    -sha256 \
    -in ${CLIENT_DIR}/client.csr \
    -CA ${CA_DIR}/ca.pem \
    -CAkey ${CA_DIR}/ca.key \
    -CAcreateserial \
    -extfile ${CLIENT_DIR}/client-pem.cnf \
    -out ${CLIENT_DIR}/client.pem

openssl pkcs12 -export \
    -passout pass: -nokeys  \
    -in ${CLIENT_DIR}/client.pem \
    -inkey ${CLIENT_DIR}/client.key \
    -out ${CLIENT_DIR}/client.p12

# Copy to example
SERVER_DEST_DIR=example/sidecar/server-certs
CLIENT_DEST_DIR=example/client/certs

cp ${SERVER_DIR}/server.pem ${SERVER_DEST_DIR}/server.pem
cp ${SERVER_DIR}/server.key ${SERVER_DEST_DIR}/server-key.pem

cp ${CA_DIR}/ca.pem ${SERVER_DEST_DIR}/server-ca.pem
cp ${CA_DIR}/ca.pem ${SERVER_DEST_DIR}/clients-ca.pem

cp ${CLIENT_DIR}/client.pem ${CLIENT_DEST_DIR}/client.pem
cp ${CLIENT_DIR}/client.key ${CLIENT_DEST_DIR}/client-key.pem
cp ${CLIENT_DIR}/client.p12 ${CLIENT_DEST_DIR}/client.cert.p12
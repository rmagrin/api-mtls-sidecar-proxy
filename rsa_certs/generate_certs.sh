echo 'Removing any existing files..'
rm ./*.pem ./*.key ./*.srl ./*.csr ./*.p12

echo 'Generating certificate authority private key..'
openssl genpkey -algorithm RSA -outform PEM -out ca.key

echo 'Generating certificate authority certificate..'
openssl req -new -x509 -nodes -sha256 -key ca.key -days 3650 -outform PEM -out ca.pem -subj "/C=GB/ST=England/L=London/O=Mettle/CN=mettle-ca"

echo 'Generating server private key..'
openssl genpkey -algorithm RSA -outform PEM -out server.key

echo 'Generating server certificate signing request..'
openssl req -new -sha256 -key server.key -out server.csr -subj "/C=GB/ST=England/L=London/O=Mettle/CN=mettle-server"

echo 'Generating server certificate..'
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -outform PEM -out server.pem -days 3650 -sha256

echo 'Generating client private key..'
openssl genpkey -algorithm RSA -outform PEM -out client.key

echo 'Generating client certificate signing request..'
openssl req -new -sha256 -key client.key -out client.csr -subj "/C=GB/ST=England/L=London/O=Mettle/CN=mettle-client"

echo 'Generating client certificate..'
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -outform PEM -out client.pem -days 365 -sha256

echo 'Creating server certificate chain as server-chain.pem ..'
cat server.pem ca.pem > server-chain.pem

echo 'Creating client certificate chain as client-chain.pem ..'
cat client.pem ca.pem > client-chain.pem

echo 'Verifying server certificate against certificate authority..'
openssl verify -CAfile ca.pem server.pem

echo 'Verifying client certificate against certificate authority..'
openssl verify -CAfile ca.pem client.pem

echo 'Generating client bundle as PKCS12..'
openssl pkcs12 -export -nokeys -passout pass: -nokeys -in client.pem -inkey client.key -out client.p12

echo 'Copying certificates to correct locations for Docker build..'
cp ca.pem ./../example/sidecar/server-certs/clients-ca.pem
cp ca.pem ./../example/sidecar/server-certs/server-ca.pem
cp server.key ./../example/sidecar/server-certs/server-key.pem
cp server.pem ./../example/sidecar/server-certs/server.pem
cp client.key ./../example/client/certs/client-key.pem
cp client.pem ./../example/client/certs/client.pem
cp client.p12 ./../example/client/certs/client.cert.p12

echo 'Rebuilding api-mtls-sidecar-proxy docker image..'
docker build --no-cache --tag local/api-mtls-sidecar-proxy ~/code/api-mtls-sidecar-proxy/

echo 'Dumping list of docker images..'
docker images

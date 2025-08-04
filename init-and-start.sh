#!/bin/bash

# Make script executable
chmod +x init-and-start.sh

# --- AUFRÄUMEN ---
echo "--- Stopping and removing old containers/volumes... ---"
docker-compose down -v --remove-orphans

# --- VERZEICHNISSE ERSTELLEN ---
echo "--- Creating necessary host directories... ---"
mkdir -p ./step-ca/config ./step-ca/secrets ./step-ca/db ./step-ca/certs ./step-cli-data ./sshd-server
echo "SuperSecretPassword123" > ./step-ca/secrets/password

# --- HOLZHAMMER-ANSATZ: BERECHTIGUNGEN SETZEN ---
echo "--- Setting permissive rights on volumes to bypass host restrictions... ---"
chmod -R 777 ./step-ca
chmod -R 777 ./step-cli-data
# --- ENDE HOLZHAMMER-ANSATZ ---

# --- DIENSTE STARTEN ---
echo "--- Starting OpenLDAP and Keycloak... ---"
docker-compose up -d openldap keycloak

echo "--- Waiting for Keycloak to start (approx. 30 seconds)... ---"
sleep 30

echo "--- Starting and initializing Step-CA... ---"
docker-compose up -d step-ca

echo "--- Waiting for Step-CA to initialize... ---"
COUNTER=0
while ! docker exec step-ca test -f /home/step/certs/root_ca.crt; do
    if [ ${COUNTER} -ge 30 ]; then
        echo "!! ERROR: Timeout (60s) waiting for step-ca to initialize. Aborting."
        echo "!! Please check the container logs for errors: docker logs step-ca"
        exit 1
    fi
    sleep 2
    COUNTER=$((COUNTER+1))
    echo "    ... still waiting for initialization ..."
done
echo "--- CA initialization complete! ---"

# --- OIDC PROVISIONER KONFIGURIEREN ---
echo "--- Adding OIDC Provisioner to Step-CA... ---"
docker exec step-ca step ca provisioner add Keycloak --type OIDC \
  --client-id ssh-step-cli \
  --client-secret very-secret-ssh-client-password \
  --configuration-endpoint http://keycloak:8080/auth/realms/sso-test/.well-known/openid-configuration \
  --admin-provisioner "admin" --admin-password-file /home/step/secrets/password

if [ $? -ne 0 ]; then
    echo "!! ERROR: Failed to add OIDC provisioner. Aborting."
    exit 1
fi
echo "--- OIDC Provisioner configured successfully. ---"

# --- SSH SERVER VORBEREITEN UND STARTEN ---
echo "--- Copying CA public key to SSH server config... ---"
cp ./step-ca/certs/root_ca.crt ./sshd-server/ca.pub

if [ ! -f "./sshd-server/ca.pub" ]; then
    echo "ERROR: Failed to copy CA public key. Aborting."
    exit 1
fi

echo "--- Building and starting SSHD-Server and Test-Client... ---"
docker-compose up -d --build sshd-server test-client

# --- ABSCHLUSS ---
echo "---"
echo "--- ✅ Setup Complete! ---"
echo "---"
echo "Keycloak Admin UI: http://localhost:8080 (admin/admin)"
echo "You can now test the SSH login as described in the guide."

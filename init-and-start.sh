#!/bin/bash

# Make script executable
chmod +x init-and-start.sh

# Cleanup previous runs
echo "--- Stopping and removing old containers/volumes... ---"
docker-compose down -v --remove-orphans

# Start basic services
echo "--- Starting OpenLDAP and Keycloak... ---"
docker-compose up -d openldap keycloak

# Wait for Keycloak to be ready
echo "--- Waiting for Keycloak to start (approx. 30 seconds)... ---"
sleep 30

# Start step-ca, which will initialize on first run
echo "--- Starting and initializing Step-CA... ---"
docker-compose up -d step-ca

# Wait for step-ca to generate its root certificate
echo "--- Waiting for Step-CA to initialize... ---"
COUNTER=0
while ! docker exec step-ca test -f /home/step/certs/root_ca.crt; do
    if [ ${COUNTER} -ge 20 ]; then
        echo "!! ERROR: Timeout (40s) waiting for step-ca to initialize. Aborting."
        echo "!! Please check the container logs for errors: docker logs step-ca"
        exit 1
    fi
    sleep 2
    COUNTER=$((COUNTER+1))
    echo "    ... still waiting for initialization ..."
done
echo "--- CA initialization complete! ---"

# === NEUER SCHRITT: OIDC PROVISIONER KONFIGURIEREN ===
echo "--- Adding OIDC Provisioner to Step-CA... ---"
docker exec step-ca step ca provisioner add Keycloak --type OIDC \
  --client-id ssh-step-cli \
  --client-secret very-secret-ssh-client-password \
  --configuration-endpoint http://keycloak:8080/auth/realms/sso-test/.well-known/openid-configuration \
  --admin-provisioner "admin" --admin-password-file /home/step/secrets/password

# Check if the last command was successful
if [ $? -ne 0 ]; then
    echo "!! ERROR: Failed to add OIDC provisioner. Aborting."
    echo "!! Please check the container logs for errors: docker logs step-ca"
    exit 1
fi
echo "--- OIDC Provisioner configured successfully. ---"
# ===================================================

# Step-CA's root public key is needed by the SSH server.
echo "--- Copying CA public key to SSH server config... ---"
if [ -d "./sshd-server/ca" ]; then
    rm -rf ./sshd-server/ca
fi
mkdir -p ./sshd-server/ca
docker cp step-ca:/home/step/certs/root_ca.crt ./sshd-server/ca/root_ca.pub

# Check if the copy was successful
if [ ! -f "./sshd-server/ca/root_ca.pub" ]; then
    echo "ERROR: Failed to copy CA public key. Aborting."
    exit 1
fi

# Now, build and start the remaining services
echo "--- Building and starting SSHD-Server and Test-Client... ---"
docker-compose up -d --build sshd-server test-client

echo "---"
echo "--- ✅ Setup Complete! ---"
echo "---"
echo "Keycloak Admin UI: http://localhost:8080 (admin/admin)"
echo "You can now test the SSH login as described in the guide."

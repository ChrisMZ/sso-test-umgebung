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
echo "--- Waiting for Step-CA to generate root certificate (approx. 10 seconds)... ---"
sleep 10

# Step-CA's root public key is needed by the SSH server.
# We copy it from the volume into the sshd-server's build context.
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
echo "Next steps are in the guide."
#!/bin/bash

echo "--- Ensuring a clean start by removing old containers and volumes... ---"
docker-compose down -v --remove-orphans

echo "--- Starting all services... ---"
# Wir starten alle Dienste, da step-ca gleich mit keycloak kommunizieren muss
docker-compose up -d

echo "--- Waiting for Keycloak to become available (approx. 30 seconds)... ---"
sleep 30

echo "--- Waiting for Step-CA to complete its initial startup... ---"
COUNTER=0
while ! docker logs step-ca | grep -q "root_ca.crt"; do
    if [ ${COUNTER} -ge 30 ]; then
        echo "!! ERROR: Timeout (60s) waiting for step-ca to initialize."
        echo "!! Please check logs: docker logs step-ca"
        exit 1
    fi
    if ! docker ps -f name=step-ca --format '{{.Names}}' | grep -q step-ca; then
        echo "!! ERROR: step-ca container has stopped unexpectedly."
        echo "!! Please check logs: docker logs step-ca"
        exit 1
    fi
    sleep 2
    COUNTER=$((COUNTER+1))
    echo "    ... waiting for certificate generation ..."
done
echo "--- CA initialization complete! ---"

# --- JETZT WIRD DIE KEYCLOAK-KONFIGURATION HINZUGEFÜGT ---
echo "--- Adding OIDC Provisioner for Keycloak to the running Step-CA... ---"
docker exec step-ca step ca provisioner add Keycloak --type OIDC \
  --client-id ssh-step-cli \
  --client-secret very-secret-ssh-client-password \
  --configuration-endpoint http://keycloak:8080/auth/realms/sso-test/.well-known/openid-configuration \
  --admin-provisioner "admin" --admin-password-file /home/step/secrets/password

# Prüfen, ob der letzte Befehl erfolgreich war
if [ $? -ne 0 ]; then
    echo "!! ERROR: Failed to add OIDC provisioner. Aborting."
    echo "!! Please check container logs: docker logs step-ca"
    exit 1
fi
echo "--- OIDC Provisioner configured successfully. ---"


# --- ABSCHLUSS ---
echo "---"
echo "--- ✅ Complete setup is running! ---"
echo "---"
echo "Keycloak Admin UI: http://localhost:8080 (admin/admin)"
echo "Step-CA is configured and ready."
echo "You can now proceed with testing the SSH login."

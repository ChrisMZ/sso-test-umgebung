Zusammenfassung der Architektur
OpenLDAP: Dient als zentrale Benutzerdatenbank. Wir erstellen hier zwei Beispielbenutzer.

Keycloak: Der Identity Provider (IdP). Er wird so konfiguriert, dass er seine Benutzer aus unserem OpenLDAP synchronisiert. Er stellt die OIDC-Schnittstelle für unsere Clients bereit.

step-ca: Eine Certificate Authority, die von Keycloak ausgestellte OIDC-Tokens verwendet, um kurzlebige SSH-Zertifikate zu generieren.

SSHD-Server: Ein benutzerdefinierter SSH-Server, der so konfiguriert ist, dass er nur Anmeldungen mit Zertifikaten von unserer step-ca akzeptiert.

Test-Client: Ein einfacher Container, der die step-CLI enthält, um den SSH-OIDC-Flow zu testen.

Web-Client (Konzeptionell): Wir konfigurieren Keycloak für einen Web-Client. Der Bau eines solchen Clients sprengt den Rahmen, aber die Konfiguration in Keycloak zeigt, wie es funktionieren würde.

__1. Starten der Umgebung__
Führen Sie das init-and-start.sh-Skript aus, um die gesamte Umgebung zu starten.

Bash

# Machen Sie das Skript zuerst ausführbar
chmod +x init-and-start.sh

# Führen Sie das Skript aus
./init-and-start.sh
Das Skript wird alle Container in der richtigen Reihenfolge starten und die notwendigen Konfigurationen kopieren.

2. Keycloak und LDAP-Synchronisation überprüfen
Öffnen Sie die Keycloak Admin Console in Ihrem Browser: http://localhost:8080.

Melden Sie sich mit den Anmeldedaten admin / admin an.

Wählen Sie oben links den Realm sso-test aus.

Gehen Sie im Menü auf User Federation. Sie sollten den ldap-provider sehen.

Klicken Sie auf den Provider und dann auf den Action-Button oben rechts. Wählen Sie Sync all users.

Gehen Sie nun im Menü auf Users. Sie sollten sshuser und testuser1 in der Liste sehen. Der LDAP-Sync war erfolgreich!

3. SSH-Login via OIDC/SSO testen
Dies ist der Kern des Tests. Wir verwenden den test-client Container, um den Login-Flow zu initiieren.

Öffnen Sie eine Shell im test-client Container:

Bash

docker exec -it test-client /bin/sh
Innerhalb des Containers, führen Sie die folgenden Befehle aus. Zuerst müssen wir der step-CLI mitteilen, wo sie unsere CA findet und ihr vertrauen:

Bash

# Bootstrap step-cli to trust our custom CA
step ca bootstrap --ca-url https://step-ca:9000 --fingerprint $(step ca fingerprint https://step-ca:9000) --install
(Hinweis: Der Fingerprint-Befehl funktioniert, weil die Container im selben Netzwerk sind. --install ist hier für die Vollständigkeit.)

Initiieren Sie jetzt den SSH-Login:

Bash

step ssh login sshuser --remote-user sshuser --port 22 sshd-server
sshuser: Der Principal (Benutzername), den wir für unser Zertifikat anfordern.

--remote-user sshuser: Der Linux-Benutzer auf dem Zielsystem.

--port 22: Der Port innerhalb des Containers.

sshd-server: Der Hostname unseres SSH-Servers im Docker-Netzwerk.

Nachdem Sie den Befehl ausgeführt haben, sehen Sie eine Ausgabe wie diese:

Your default web browser has been opened to visit:

https://keycloak.example.com/auth/realms/sso-test/protocol/openid-connect/auth?....
Öffnen Sie diese URL in Ihrem Browser auf Ihrem Host-Rechner.

Sie werden zur Keycloak-Anmeldeseite weitergeleitet. Melden Sie sich an als:

Benutzer: sshuser

Passwort: password123

Nach erfolgreicher Anmeldung wird die Webseite eine Erfolgsmeldung anzeigen, und die step-CLI im Terminal wird automatisch fortfahren. Sie erhält das OIDC-Token, tauscht es bei step-ca gegen ein SSH-Zertifikat ein und fügt dieses zu seinem SSH-Agenten hinzu.

Testen Sie den Login! Führen Sie im selben test-client Container den SSH-Befehl aus:

Bash

ssh -p 22 sshuser@sshd-server
Sie sollten ohne Passwortabfrage direkt eingeloggt sein. Der SSO-SSH-Flow war erfolgreich!

4. Web-Client-Login (Konzeptionell)
Wir haben zwar keinen laufenden Web-Client, aber in Keycloak ist bereits alles dafür vorbereitet. Ein typischer OIDC-fähiger Web-Client (z.B. eine Spring Boot, NodeJS oder Python App) würde wie folgt konfiguriert:

Authority/Issuer URL: http://localhost:8080/auth/realms/sso-test

Client ID: webapp-client

Redirect URI: http://localhost:8082/callback (oder ähnlich)

Wenn ein Benutzer auf dieser hypothetischen Webseite auf "Login" klicken würde, würde er zu Keycloak weitergeleitet, könnte sich mit testuser1 / password123 anmelden und würde dann zur Anwendung zurückgeleitet werden.

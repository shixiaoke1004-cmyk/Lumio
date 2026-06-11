#!/bin/bash
# Creates a stable self-signed code-signing identity so accessibility (and other
# TCC) grants survive rebuilds. Adhoc signatures change their cdhash on every
# build, which invalidates the grant; a fixed certificate keeps the designated
# requirement constant. Run once: Scripts/setup-signing.sh
set -euo pipefail

CERT_NAME="Lumio Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP=$(mktemp -d /tmp/lumio-signing.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Identity '$CERT_NAME' already exists in the login keychain. Nothing to do."
    exit 0
fi

echo "Generating a self-signed code-signing certificate…"
cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CERT_NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/openssl.cnf"

# macOS `security import` rejects empty-password p12 bundles and the modern
# default MAC, so use a throwaway password and the SHA1 MAC it understands.
P12_PASS="lumio"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT_NAME" -out "$TMP/identity.p12" \
    -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES \
    -passout "pass:$P12_PASS"

# Import the identity and pre-authorize codesign to use the private key.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$P12_PASS" \
    -T /usr/bin/codesign -T /usr/bin/security

# Trust it for code signing in the user's keychain (a GUI auth dialog appears).
echo "Adding code-signing trust (you'll be asked for your login password)…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" || \
    echo "warning: trust step skipped; signing may still work without it"

echo
echo "Done. Verify with:  security find-identity -v -p codesigning"
echo "project.yml is already set to sign with '$CERT_NAME'."

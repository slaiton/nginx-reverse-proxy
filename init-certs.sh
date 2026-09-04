#!/bin/bash

# ============================================================================
# Initialize SSL certificates (create self-signed if needed)
# ============================================================================
# Este script crea certificados autofirmados si los certificados reales
# no existen. Es útil para el primer despliegue.
# ============================================================================

set -e

DOMAIN="api-innvestock.slaiton.com"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

echo "Checking SSL certificates for $DOMAIN..."

# Si los certificados ya existen, no hacer nada
if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
    echo "✓ Certificados encontrados en $CERT_DIR"
    exit 0
fi

echo "Certificados no encontrados"
echo "Generando certificados autofirmados (temporal)..."

# Crear directorio para certificados
mkdir -p "$CERT_DIR"

# Crear certificados autofirmados directamente en la ubicación esperada
openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" -days 365 -nodes \
    -subj "/CN=$DOMAIN/O=Temporary/C=US" > /dev/null 2>&1

# Crear chain.pem como copia de fullchain.pem
cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem"

# Establecer permisos correctos
chmod 644 "$CERT_DIR/fullchain.pem"
chmod 644 "$CERT_DIR/chain.pem"
chmod 600 "$CERT_DIR/privkey.pem"

echo "✓ Certificados autofirmados creados en $CERT_DIR"
echo ""
echo "IMPORTANTE: Estos son certificados TEMPORALES de auto-firma."
echo "Genera certificados reales con:"
echo "  sudo ./setup-ssl.sh $DOMAIN"
echo "Luego recarga nginx:"
echo "  docker exec nginx-reverse-proxy nginx -s reload"

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
    echo "✓ Certificados reales encontrados"
    exit 0
fi

echo "Certificados reales no encontrados"
echo "Verificando certificados autofirmados..."

SNAKEOIL_DIR="/etc/nginx/certs"
mkdir -p "$SNAKEOIL_DIR"

# Si los certificados autofirmados ya existen, usar esos
if [ -f "$SNAKEOIL_DIR/fullchain.pem" ] && [ -f "$SNAKEOIL_DIR/privkey.pem" ]; then
    echo "✓ Usando certificados autofirmados existentes"
    # Crear symlinks a los certificados autofirmados en la ubicación esperada
    mkdir -p "$CERT_DIR"
    ln -sf "$SNAKEOIL_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem" 2>/dev/null || true
    ln -sf "$SNAKEOIL_DIR/privkey.pem" "$CERT_DIR/privkey.pem" 2>/dev/null || true
    ln -sf "$SNAKEOIL_DIR/chain.pem" "$CERT_DIR/chain.pem" 2>/dev/null || true
    exit 0
fi

# Crear certificados autofirmados
echo "Generando certificados autofirmados (temporal)..."
openssl req -x509 -newkey rsa:2048 -keyout "$SNAKEOIL_DIR/privkey.pem" \
    -out "$SNAKEOIL_DIR/fullchain.pem" -days 365 -nodes \
    -subj "/CN=$DOMAIN/O=Temporary/C=US" > /dev/null 2>&1

cp "$SNAKEOIL_DIR/fullchain.pem" "$SNAKEOIL_DIR/chain.pem"

# Crear symlinks
mkdir -p "$CERT_DIR"
ln -sf "$SNAKEOIL_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem" 2>/dev/null || true
ln -sf "$SNAKEOIL_DIR/privkey.pem" "$CERT_DIR/privkey.pem" 2>/dev/null || true
ln -sf "$SNAKEOIL_DIR/chain.pem" "$CERT_DIR/chain.pem" 2>/dev/null || true

echo "✓ Certificados autofirmados creados"
echo ""
echo "IMPORTANTE: Estos son certificados TEMPORALES de auto-firma."
echo "Genera certificados reales con:"
echo "  sudo ./setup-ssl.sh $DOMAIN"
echo "Luego activa HTTPS:"
echo "  ./enable-ssl.sh"

#!/bin/bash

# ============================================================================
# Switch from HTTP-only to HTTPS configuration
# ============================================================================
# Uso: chmod +x enable-ssl.sh && ./enable-ssl.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

DOMAIN="api-innvestock.slaiton.com"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

# Verificar que los certificados existen
if [ ! -d "$CERT_PATH" ]; then
    log_error "Certificados no encontrados en $CERT_PATH"
    log_info "Ejecuta primero: sudo ./setup-ssl.sh"
    exit 1
fi

log_info "Certificados encontrados ✓"
log_info "Activando configuración HTTPS..."

# Remover configuración HTTP-only si existe
if [ -f "conf.d/api-innvestock-http.conf" ]; then
    mv conf.d/api-innvestock-http.conf conf.d/api-innvestock-http.conf.bak
    log_info "Configuración HTTP desactivada (respaldada)"
fi

# Activar configuración HTTPS
if [ -f "conf.d/api-innvestock.conf" ]; then
    log_info "Configuración HTTPS activa"
else
    log_error "No se encontró conf.d/api-innvestock.conf"
    exit 1
fi

# Recargar nginx
log_info "Recargando nginx..."
docker exec nginx-reverse-proxy nginx -t && \
docker exec nginx-reverse-proxy nginx -s reload && \
log_info "✓ HTTPS activado exitosamente"

log_info ""
log_info "Verificando..."
sleep 1
curl -I https://$DOMAIN 2>/dev/null | head -1 || log_warn "HTTPS aún no responde (DNS o conectividad)"

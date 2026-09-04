#!/bin/bash

# ============================================================================
# Setup SSL con Certbot para Nginx Reverse Proxy
# ============================================================================
# Uso: chmod +x setup-ssl.sh && ./setup-ssl.sh
#
# Este script:
# 1. Instala certbot y el plugin de nginx
# 2. Crea los certificados SSL para el dominio configurado
# 3. Configura renovación automática
# ============================================================================

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir colores
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Leer dominio desde argumento o usar default
DOMAIN="${1:-api-innvestock.slaiton.com}"
EMAIL="${2:-jstivenlaiton@gmail.com}"

log_info "Configurando SSL para: $DOMAIN"
log_info "Email de notificaciones: $EMAIL"

# ============================================================================
# 1. Instalar Certbot
# ============================================================================
log_info "Instalando certbot..."

if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
elif command -v yum &> /dev/null; then
    yum install -y certbot python3-certbot-nginx > /dev/null 2>&1
else
    log_error "No se pudo instalar certbot. Sistema no soportado."
    exit 1
fi

log_info "✓ Certbot instalado"

# ============================================================================
# 2. Crear directorio para validación de Certbot
# ============================================================================
log_info "Creando directorio para validación ACME..."
mkdir -p /var/www/certbot
log_info "✓ Directorio creado: /var/www/certbot"

# ============================================================================
# 3. Generar certificados SSL
# ============================================================================
log_info "Generando certificados SSL para $DOMAIN..."

certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --expand \
    -d "$DOMAIN" \
    -d "www.$DOMAIN" 2>&1 | grep -v "^Processing\|^Cleaning up\|^Waiting for\|^Verifying that\|^The following"

if [ $? -eq 0 ]; then
    log_info "✓ Certificados generados exitosamente"
else
    log_warn "Error al generar certificados. Intenta manualmente:"
    echo "  sudo certbot certonly --webroot -w /var/www/certbot -d $DOMAIN"
    exit 1
fi

# ============================================================================
# 4. Configurar renovación automática
# ============================================================================
log_info "Configurando renovación automática..."

# Crear script de renovación con reload de docker
RENEWAL_HOOK_PATH="/etc/letsencrypt/renewal-hooks/post/docker-reload.sh"
mkdir -p "$(dirname "$RENEWAL_HOOK_PATH")"

cat > "$RENEWAL_HOOK_PATH" << 'EOF'
#!/bin/bash
# Reload nginx en docker después de renovar certificado
if [ -x "$(command -v docker)" ]; then
    cd /home/forge/nginx-reverse-proxy
    docker exec -it nginx-reverse-proxy nginx -s reload || true
fi
EOF

chmod +x "$RENEWAL_HOOK_PATH"

# Habilitar renovación automática
systemctl enable certbot.timer 2>/dev/null || true
systemctl start certbot.timer 2>/dev/null || true

log_info "✓ Renovación automática configurada"

# ============================================================================
# 5. Verificar certificados
# ============================================================================
log_info "Verificando certificados..."
certbot certificates

# ============================================================================
# 6. Instrucciones finales
# ============================================================================
echo ""
log_info "✓ SSL configurado exitosamente"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "1. Reinicia el servicio nginx:"
echo "   docker compose restart nginx-reverse-proxy"
echo ""
echo "2. Verifica que funcione:"
echo "   curl -I https://$DOMAIN"
echo ""
echo "3. Monitorea la renovación:"
echo "   certbot renew --dry-run"
echo ""

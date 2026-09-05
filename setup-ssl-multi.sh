#!/bin/bash

# ============================================================================
# Setup SSL para múltiples dominios con Let's Encrypt y Certbot
# ============================================================================
# Uso: sudo chmod +x setup-ssl-multi.sh && sudo ./setup-ssl-multi.sh
#
# Este script:
# 1. Busca todos los dominios configurados en conf.d/*.conf
# 2. Genera certificados Let's Encrypt para cada dominio
# 3. Configura renovación automática
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

EMAIL="${1:-jstivenlaiton@gmail.com}"
CONF_DIR="./conf.d"
DOMAINS_FILE="/tmp/ssl_domains.txt"

log_section "Setup SSL Multi-Dominio con Let's Encrypt"

# ============================================================================
# 1. Instalar Certbot
# ============================================================================
log_info "Verificando e instalando certbot..."

if ! command -v certbot &> /dev/null; then
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
else
    log_info "✓ Certbot ya está instalado"
fi

# ============================================================================
# 2. Crear directorio para validación de Certbot
# ============================================================================
log_info "Configurando directorio para validación ACME..."
mkdir -p /var/www/certbot
chmod 755 /var/www/certbot
log_info "✓ Directorio /var/www/certbot listo"

# ============================================================================
# 3. Extraer dominios de configuraciones nginx
# ============================================================================
log_section "Extrayendo dominios de configuraciones"

> "$DOMAINS_FILE"

if [ ! -d "$CONF_DIR" ]; then
    log_error "Directorio $CONF_DIR no encontrado"
    exit 1
fi

# Buscar todos los server_name en los archivos .conf
for conf_file in "$CONF_DIR"/*.conf; do
    [ -f "$conf_file" ] || continue

    # Saltar configuraciones HTTP-only
    if [[ "$conf_file" == *"-http.conf" ]]; then
        continue
    fi

    echo "Procesando: $(basename $conf_file)"

    # Extraer dominios del server_name (primera línea que contenga server_name)
    grep "server_name" "$conf_file" | head -1 | sed 's/.*server_name //g' | sed 's/;//g' | tr ' ' '\n' | \
    while read domain; do
        domain=$(echo $domain | xargs) # trim whitespace
        [ -z "$domain" ] && continue

        # Verificar que no es un wildcard o patrón
        if [[ ! "$domain" =~ ^\*\. ]] && [[ ! "$domain" =~ ~.*\$ ]]; then
            echo "$domain" >> "$DOMAINS_FILE"
        fi
    done
done

# Remover duplicados y dominios vacíos
sort -u "$DOMAINS_FILE" -o "$DOMAINS_FILE"
sed -i '/^$/d' "$DOMAINS_FILE"

if [ ! -s "$DOMAINS_FILE" ]; then
    log_error "No se encontraron dominios en las configuraciones"
    exit 1
fi

log_info "Dominios encontrados:"
cat "$DOMAINS_FILE" | sed 's/^/  - /'

# ============================================================================
# 4. Generar certificados Let's Encrypt
# ============================================================================
log_section "Generando certificados Let's Encrypt"

CERT_COUNT=0
CERT_FAILED=0

while IFS= read -r domain; do
    [ -z "$domain" ] && continue

    log_info "Procesando dominio: $domain"

    # Verificar si el certificado ya existe
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        log_warn "Certificado ya existe para $domain (usar --force-renewal para renovar)"
        CERT_COUNT=$((CERT_COUNT + 1))
        continue
    fi

    # Generar certificado
    if certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive \
        -d "$domain" 2>&1 | grep -v "^Processing\|^Cleaning up\|^Waiting for\|^Verifying that"; then

        log_info "✓ Certificado generado para $domain"
        CERT_COUNT=$((CERT_COUNT + 1))
    else
        log_warn "✗ Error al generar certificado para $domain"
        CERT_FAILED=$((CERT_FAILED + 1))
    fi
done < "$DOMAINS_FILE"

log_section "Resumen de certificados"
echo "Procesados exitosamente: $CERT_COUNT"
echo "Errores: $CERT_FAILED"

# ============================================================================
# 5. Configurar renovación automática
# ============================================================================
log_section "Configurando renovación automática"

RENEWAL_HOOK_PATH="/etc/letsencrypt/renewal-hooks/post/nginx-reload.sh"
mkdir -p "$(dirname "$RENEWAL_HOOK_PATH")"

cat > "$RENEWAL_HOOK_PATH" << 'HOOK_EOF'
#!/bin/bash
# Recarga nginx después de renovar certificados

if [ -x "$(command -v docker)" ]; then
    # Encontrar el contenedor nginx-reverse-proxy
    CONTAINER=$(docker ps -q -f "name=nginx-reverse-proxy" | head -1)

    if [ -n "$CONTAINER" ]; then
        echo "[$(date)] Recargando nginx en contenedor $CONTAINER"
        docker exec "$CONTAINER" nginx -s reload || echo "Error al recargar nginx"
    else
        echo "[$(date)] Contenedor nginx-reverse-proxy no encontrado"
    fi
fi
HOOK_EOF

chmod +x "$RENEWAL_HOOK_PATH"

# Habilitar renovación automática
if command -v systemctl &> /dev/null; then
    systemctl enable certbot.timer 2>/dev/null || true
    systemctl start certbot.timer 2>/dev/null || true
    log_info "✓ Renovación automática habilitada (systemd)"
else
    log_warn "systemd no disponible - configura renovación manual"
fi

# ============================================================================
# 6. Verificar certificados
# ============================================================================
log_section "Estado de certificados"
certbot certificates

# ============================================================================
# 7. Instrucciones finales
# ============================================================================
echo ""
log_info "✓ Configuración completa"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "1. Recargar nginx:"
echo "   docker exec nginx-reverse-proxy nginx -s reload"
echo ""
echo "2. Verificar HTTPS:"
echo "   curl -I https://$(head -1 $DOMAINS_FILE)"
echo ""
echo "3. Monitorear renovación:"
echo "   sudo certbot renew --dry-run"
echo ""
echo "4. Ver logs de renovación:"
echo "   sudo tail -f /var/log/letsencrypt/letsencrypt.log"
echo ""

rm -f "$DOMAINS_FILE"

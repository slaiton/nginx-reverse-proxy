# Setup SSL con Certbot

## Para múltiples dominios (RECOMENDADO)

Si tienes varios dominios configurados en `conf.d/`, usa este script para generar certificados para **todos automáticamente**:

```bash
cd /home/forge/nginx-reverse-proxy

# Dar permisos de ejecución
sudo chmod +x setup-ssl-multi.sh

# Ejecutar (busca dominios en conf.d/*.conf y genera certificados)
sudo ./setup-ssl-multi.sh
```

El script automáticamente:
- ✓ Detecta todos los dominios en las configuraciones
- ✓ Genera certificados Let's Encrypt para cada uno
- ✓ Configura renovación automática
- ✓ Crea hooks para recargar nginx al renovar

Luego recarga nginx:
```bash
docker exec nginx-reverse-proxy nginx -s reload
```

Verifica:
```bash
sudo certbot certificates
curl -I https://tu-dominio.com
```

---

## Para un solo dominio

Si solo tienes un dominio:

```bash
cd /home/forge/nginx-reverse-proxy
sudo chmod +x setup-ssl.sh
sudo ./setup-ssl.sh tu-dominio.com tu-email@example.com
```

---

## Flujo de despliegue (automático vía GitHub Actions)

El workflow de GitHub Actions maneja automáticamente:

1. **Inicializa certificados**: Si no existen, crea temporales autofirmados
2. **Despliega nginx**: Levanta el contenedor
3. **Verifica estado**: Comprueba que nginx esté corriendo

**Después del primer despliegue**, genera certificados Let's Encrypt:

```bash
cd /home/forge/nginx-reverse-proxy
sudo ./setup-ssl-multi.sh
docker exec nginx-reverse-proxy nginx -s reload
```

---

## Instalación Manual Paso a Paso

### 1. Clonar el repositorio
```bash
cd /home/forge
git clone <tu-repo> nginx-reverse-proxy
cd nginx-reverse-proxy
```

### 2. Inicializar certificados (autofirmados temporal)
```bash
sudo chmod +x init-certs.sh
sudo ./init-certs.sh
```

### 3. Levantar nginx
```bash
docker compose up -d
docker compose logs -f nginx
```

### 4. Generar certificados Let's Encrypt
```bash
sudo chmod +x setup-ssl-multi.sh
sudo ./setup-ssl-multi.sh tu-email@example.com
```

### 5. Recargar nginx con certificados reales
```bash
docker exec nginx-reverse-proxy nginx -s reload
docker compose restart nginx-reverse-proxy
```

### 6. Verificar
```bash
sudo certbot certificates
curl -I https://tu-dominio.com
```

---

## Renovación Manual de Certificados

Si el script automático falla:

```bash
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d api-innvestock.slaiton.com \
  -d www.api-innvestock.slaiton.com
```

Luego:
```bash
docker compose restart nginx-reverse-proxy
```

---

## Verificar Estado de Certificados

```bash
# Listar certificados
sudo certbot certificates

# Simular renovación (sin hacer cambios)
sudo certbot renew --dry-run

# Renovar manualmente
sudo certbot renew --force-renewal
```

---

## Logs

- **Nginx access:** `./logs/api-innvestock-access.log`
- **Nginx error:** `./logs/api-innvestock-error.log`
- **Certbot:** `/var/log/letsencrypt/letsencrypt.log`

---

## Troubleshooting

### Error: "port 80 is already in use"
```bash
docker compose down
docker compose up -d
```

### Certificado no se renueva automáticamente
```bash
systemctl status certbot.timer
sudo systemctl restart certbot.timer
```

### Nginx no recarga certificados
```bash
docker exec nginx-reverse-proxy nginx -s reload
# O reiniciar:
docker compose restart nginx-reverse-proxy
```

---

## Estructura de Archivos

```
/home/forge/nginx-reverse-proxy/
├── nginx.conf                    # Configuración principal
├── conf.d/
│   ├── api-innvestock.conf      # ← Tu dominio (creado por el setup)
│   └── api-innvestock-example.conf
├── docker-compose.yml
├── setup-ssl.sh                 # ← Script de instalación
├── logs/                        # Logs de nginx
└── /etc/letsencrypt/           # Certificados SSL (del sistema)
    ├── live/api-innvestock.slaiton.com/
    │   ├── fullchain.pem
    │   ├── privkey.pem
    │   └── chain.pem
    └── renewal/api-innvestock.slaiton.com.conf
```

---

## CI/CD con GitHub Actions

El workflow automático:
1. Descarga cambios
2. Recarga la configuración de nginx
3. Recarga nginx sin downtime

Los certificados se renuevan automáticamente via certbot en el servidor.

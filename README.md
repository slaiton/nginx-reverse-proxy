# Reverse Proxy Nginx - Proyecto Independiente

Contenedor Nginx que actúa como **reverse proxy central** para múltiples proyectos Docker en el servidor.

## Arquitectura

```
Internet (HTTPS:443)
    ↓
Nginx Reverse Proxy (contenedor)
    ├─ api.prueba.com → logistica-api:8080 (proyecto 1)
    ├─ otro.dominio.com → otro-proyecto:8081 (proyecto 2)
    └─ ...
```

## Requisitos

- Docker + Docker Compose instalados en el servidor
- Certbot con certificados generados: `/etc/letsencrypt/live/*/`
- Puertos 80 y 443 abiertos en firewall

## Setup rápido

### 1. Clonar el repositorio en el servidor

```bash
cd /home/forge
git clone <tu-repo> nginx-reverse-proxy
cd nginx-reverse-proxy
```

### 2. Instalar SSL automáticamente

El repositorio incluye un script que:
- ✓ Instala Certbot
- ✓ Genera certificados SSL
- ✓ Configura renovación automática

```bash
sudo chmod +x setup-ssl.sh
sudo ./setup-ssl.sh api-innvestock.slaiton.com jstivenlaiton@gmail.com
```

**Nota:** Si ya tienes certificados, puedes saltarte este paso.

### 3. Levantar el reverse proxy

```bash
docker compose up -d

# Verificar
docker compose ps
docker compose logs -f
```

### 4. Verificar que funciona

```bash
# Health check interno
curl http://127.0.0.1:8888/health

# Acceso externo (HTTPS)
curl -I https://api-innvestock.slaiton.com/api/v1/health
```

### Ver instrucciones detalladas de SSL

```bash
cat SETUP_SSL.md
```

## Agregar más proyectos

Cada proyecto nuevo necesita:

1. **Su archivo de configuración** en `conf.d/`:

```bash
cp conf.d/api-prueba-example.conf conf.d/otro-proyecto.conf
nano conf.d/otro-proyecto.conf
```

2. **Certificado SSL** (si otro dominio):

```bash
sudo certbot certonly --standalone -d otro.dominio.com
```

3. **Recargar nginx** (sin downtime):

```bash
docker compose exec nginx nginx -s reload
```

## Estructura

```
nginx-reverse-proxy/
├── docker-compose.yml          ← Definición del contenedor
├── nginx.conf                  ← Config principal (no editar)
├── conf.d/                     ← Configuraciones por dominio
│   ├── api-prueba-example.conf    ← PLANTILLA (copiar y editar)
│   ├── api-prueba.conf            ← Config real (no versionar)
│   └── otro-proyecto.conf             ← Otros proyectos
├── logs/                       ← Logs de nginx (generado en runtime)
├── .env.example                ← Variables (solo referencia)
└── README.md                   ← Este archivo
```

## Configuración

### nginx.conf

Archivo principal, NO editar. Define:
- Worker processes
- Logging
- Gzip compression
- Resolver DNS
- Health check en puerto 8888

### conf.d/*.conf

Configuraciones específicas por dominio. Cada archivo debe tener:

```nginx
# Upstream: dónde está el proyecto interno
upstream mi_proyecto {
    server 127.0.0.1:8080;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name mi.dominio.com;
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS con proxy
server {
    listen 443 ssl http2;
    server_name mi.dominio.com;

    ssl_certificate /etc/letsencrypt/live/mi.dominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mi.dominio.com/privkey.pem;

    # ... headers, gzip, etc ...

    location / {
        proxy_pass http://mi_proyecto;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Renovación de certificados

Certbot se renueva automáticamente cada 60 días. Nginx no necesita reinicio — lee los certificados nuevos automáticamente.

Para renovar manualmente:

```bash
sudo certbot renew
docker compose exec nginx nginx -s reload
```

## Logs

Ver logs en tiempo real:

```bash
docker compose logs -f nginx
```

Logs de acceso por dominio:

```bash
cat logs/api-prueba-access.log
cat logs/api-prueba-error.log
```

## Troubleshooting

### "Port 80/443 already in use"

```bash
sudo lsof -i :80
sudo lsof -i :443
# Matar proceso si es necesario
sudo kill -9 <PID>
```

### Certificado no se ve (SSL error)

```bash
# Verificar que existen
ls -la /etc/letsencrypt/live/api.prueba.com/

# Recargar nginx
docker compose exec nginx nginx -s reload
```

### Proxy devuelve "502 Bad Gateway"

- Verificar que el proyecto Docker corre: `docker ps`
- Verificar puerto interno: `docker port <container-name>`
- Revisar logs del proyecto: `docker logs <project-name>_app_1`

### Nginx no recarga config

```bash
docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload
```

## CI/CD: renovación automática de certs

Si quieres que Certbot se renueve automáticamente y recarque nginx:

```bash
sudo nano /usr/local/bin/renew-certs-reverse-proxy.sh
```

```bash
#!/bin/bash
set -e

REPO_PATH="/home/forge/nginx-reverse-proxy"

echo "[$(date)] Renovando certificados"
certbot renew --quiet

echo "[$(date)] Recargando Nginx"
cd $REPO_PATH
docker compose exec -T nginx nginx -s reload

echo "[$(date)] Completado"
```

```bash
sudo chmod +x /usr/local/bin/renew-certs-reverse-proxy.sh
sudo crontab -e
```

Agregar:

```
0 3 * * 1 /usr/local/bin/renew-certs-reverse-proxy.sh >> /var/log/reverse-proxy-renewal.log 2>&1
```

## Seguridad

✅ TLS 1.2 + 1.3 únicamente  
✅ HSTS header (forzar HTTPS por 1 año)  
✅ X-Frame-Options DENY  
✅ X-Content-Type-Options nosniff  
✅ Certificados auto-renovables (Certbot)  
✅ Gzip compression  
✅ Server tokens off  

## Performance

- **Resolución DNS caché**: 10 segundos (resolver interno de Docker)
- **Timeouts**: 60 segundos (ajustable en conf.d)
- **Buffering**: habilitado (mejorar performance con tamaños personalizados)
- **Gzip**: nivel 6, mínimo 1KB

Para optimizar más, ajusta en `conf.d/`:

```nginx
# Aumentar timeout para uploads grandes
proxy_read_timeout 300s;

# Buffering para respuestas grandes
proxy_buffer_size 64k;
proxy_buffers 16 64k;
```

## Para más información

- [Nginx reverse proxy official docs](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Let's Encrypt / Certbot](https://certbot.eff.org/)
- [HTTP/2 in Nginx](https://nginx.org/en/docs/http/v2.html)


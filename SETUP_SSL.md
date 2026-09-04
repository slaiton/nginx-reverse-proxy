# Setup SSL con Certbot

## Instalación Rápida

### 1. En el servidor, clonar el repositorio
```bash
cd /home/forge
git clone <tu-repo> nginx-reverse-proxy
cd nginx-reverse-proxy
```

### 2. Ejecutar script de setup SSL
```bash
sudo chmod +x setup-ssl.sh
sudo ./setup-ssl.sh api-innvestock.slaiton.com jstivenlaiton@gmail.com
```

El script:
- ✓ Instala certbot
- ✓ Genera certificados SSL automáticamente
- ✓ Configura renovación automática
- ✓ Crea hooks para recargar nginx al renovar

### 3. Levantar nginx con Docker
```bash
docker compose up -d
```

### 4. Verificar HTTPS
```bash
curl -I https://api-innvestock.slaiton.com
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

# RPi Backup Web

Backup automatizado con interfaz web, barra de progreso y notificaciones por Telegram, diseñado para Raspberry Pi.

## Características

- Interfaz web con botón de backup manual
- Programación automática (cada hora, diario, personalizado)
- Barra de progreso y log en vivo
- Historial de backups
- Notificaciones por Telegram
- Subida automática con Rclone

## Uso

```bash
git clone https://github.com/tuusuario/rpi-backup-web.git
cd rpi-backup-web
docker compose up -d

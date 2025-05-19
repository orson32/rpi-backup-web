# RPi Backup Web

**Respalda tu Raspberry Pi con estilo.**  
Interfaz web + barra de progreso + programación automática + notificaciones por Telegram.  
Todo desde tu navegador.

![screenshot](https://via.placeholder.com/900x200?text=RPi+Backup+Web)

---

## 🚀 Características

- Interfaz web moderna (Bootstrap 5)
- Backup manual o automático
- Programación: cada hora, diario o personalizado (X min/hora/días)
- Log en vivo y barra de progreso
- Historial de backups
- Monitoreo de CPU, RAM, disco y temperatura
- Notificaciones por Telegram
- Subida automática a la nube (usando Rclone)

---

## 📦 Requisitos

- Raspberry Pi (o cualquier sistema Linux)
- Docker + Docker Compose
- Rclone ya configurado (`rclone config`)
- Un bot de Telegram creado (ver más abajo)

---

## ⚙️ Configuración

### 1. Clona el repositorio

```bash
git clone https://github.com/orson32/rpi-backup-web.git
cd rpi-backup-web
```

### 2. Crea y edita tu archivo `.env`

```bash
cp .env.example .env
```

Edita `.env` con tu token de Telegram y chat_id:

```env
TELEGRAM_TOKEN=123456789:ABCdefGHIjklMNOP
CHAT_ID=987654321
```

### 3. Lanza el contenedor

```bash
docker compose up -d
```

Abre en tu navegador:  
```
http://<IP_DE_TU_RPI>:5000
```

---

## ☁️ Configurar Rclone

Este sistema usa [Rclone](https://rclone.org) para subir backups a la nube.  
Asegúrate de tener tu remoto configurado. Ejemplo:

```bash
rclone config
rclone ls Herinube:
```

Y en `.env`, usa ese nombre para tu remoto en `backup.sh`.

---

## 🛡️ Seguridad

- Nunca subas tu archivo `.env` al repositorio
- GitHub lo detectará y podría revocar tus tokens
- Usa `.env.example` para compartir la estructura sin secretos

---

## ✨ Créditos

Creado por orson32 con ayuda de ChatGPT y un French Poodle supervisando el uptime.

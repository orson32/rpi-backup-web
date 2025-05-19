#!/bin/bash

set -e

# Cargar variables del entorno
set -a
source /app/.env
set +a

### CONFIGURACIÓN ###
BACKUP_DIR="/mnt/backup"
RCLONE_REMOTE="Herinube:backup_folder"
RCLONE_CONFIG="/root/.config/rclone/rclone.conf"
LOG_FILE="/app/log/backup.log"
MIN_FREE_GB=1
RETENTION_DAYS=7

### DETECCIÓN DE VARIABLES ###
BACKUP_TYPE="[MANUAL]"
ROOT_PARTITION=$(findmnt -no SOURCE /)
#ROOT_PARTITION="/app/backup_test_file" 

DATE=$(date +'%Y-%m-%d_%H-%M')
IMG_NAME="${BACKUP_TYPE}-rpi-backup-$DATE.img"
IMG_PATH="$BACKUP_DIR/$IMG_NAME"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

escape_markdown() {
    echo "$1" | sed -e 's/\\/\\\\/g' \
                    -e 's/\*/\\*/g' \
                    -e 's/_/\\_/g' \
                    -e 's/\[/\\[/g' \
                    -e 's/\]/\\]/g' \
                    -e 's/(/\\(/g' \
                    -e 's/)/\\)/g' \
                    -e 's/~\\/\\~/g' \
                    -e 's/>/\\>/g' \
                    -e 's/#/\\#/g' \
                    -e 's/\+/\\+/g' \
                    -e 's/-/\\-/g' \
                    -e 's/=/\\=/g' \
                    -e 's/|/\\|/g' \
                    -e 's/{/\\{/g' \
                    -e 's/}/\\}/g' \
                    -e 's/\./\\./g' \
                    -e 's/!/\\!/g'
}

send_telegram() {
    local MSG="$1"
    local ESCAPED_MSG
    ESCAPED_MSG=$(escape_markdown "$MSG")
    ESCAPED_MSG=${ESCAPED_MSG//$'\n'/'%0A'}
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d chat_id="$CHAT_ID" \
         -d parse_mode="MarkdownV2" \
         -d text="$ESCAPED_MSG" > /dev/null
}

log() {
    echo "[$(date +'%F %T')] $1" | tee -a "$LOG_FILE"
}

log_and_telegram() {
    log "$1"
    send_telegram "$1"
}

update_progress() {
    echo "status=$1%" | tee -a "$LOG_FILE"
}

check_space() {
    FREE_GB=$(df -BG "$BACKUP_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if (( FREE_GB < MIN_FREE_GB )); then
        log_and_telegram "🚨 Espacio insuficiente: solo ${FREE_GB}GB libres en $BACKUP_DIR"
        exit 1
    fi
}

### BACKUP ###
SECONDS=0
log_and_telegram "🚀 Iniciando backup del sistema..."
update_progress 1

check_space

log_and_telegram "📀 Creando imagen desde $ROOT_PARTITION..."
dd if="$ROOT_PARTITION" of="$IMG_PATH" bs=1M status=progress conv=fsync | while read line; do
    echo "$line" >> "$LOG_FILE"
done

update_progress 30
log_and_telegram "📦 Comprimiendo imagen..."
xz -T0 "$IMG_PATH"
COMPRESSED_IMG="$IMG_PATH.xz"

update_progress 70
log_and_telegram "☁️ Subiendo a la nube con rclone..."

if ! rclone --config "$RCLONE_CONFIG" copy "$COMPRESSED_IMG" "$RCLONE_REMOTE" --progress 2>&1 | tee -a "$LOG_FILE"; then
    log_and_telegram "❌ Error al subir con Rclone. Verifica tu token con: \`rclone config reconnect Herinube:\`"
    echo "status=90%"
    exit 1
fi

update_progress 90
log_and_telegram "🧹 Limpiando backups antiguos..."
find "$BACKUP_DIR" -type f -name "*.img.xz" -mtime +$RETENTION_DAYS -exec rm {} \;

### REPORTE FINAL ###
ELAPSED=$SECONDS
MINUTES=$((ELAPSED / 60))
SECONDS_REMAINING=$((ELAPSED % 60))
SIZE=$(du -h "$COMPRESSED_IMG" | cut -f1)
SIZE_MB=$(du -m "$COMPRESSED_IMG" | cut -f1)
TOTAL_SECONDS=$(( MINUTES * 60 + SECONDS_REMAINING ))
SPEED_MBPS=$(( TOTAL_SECONDS > 0 ? SIZE_MB / TOTAL_SECONDS : SIZE_MB ))

FINAL_MESSAGE=$(printf "🎉 *Backup RPi Completado* 🎉\n\n\
🏷️ *Tipo:* *%s*\n\
📦 *Archivo:* \`%s\`\n\
📏 *Tamaño:* *%s*\n\
⏱️ *Duración:* *%dm %ds*\n\
🚀 *Velocidad Promedio:* *%d MB/s*\n\
💾 *Destino:* *%s*\n\n\
✅ *Estado:* *Éxito*\n\
────────────────────────\n\
📈 *Progreso:* [██████████] 100%%" \
"$BACKUP_TYPE" \
"$(basename "$COMPRESSED_IMG")" \
"$SIZE" \
"$MINUTES" "$SECONDS_REMAINING" \
"$SPEED_MBPS" \
"$RCLONE_REMOTE")

log_and_telegram "$FINAL_MESSAGE"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
     -d chat_id="$CHAT_ID" \
     -d sticker="CAACAgEAAxkBAAEBgGZlRYnW1c5bt0bXq--rM2W-cfcoOgACVgEAAm4wCQUWzPfu2-iVAx4E" > /dev/null

update_progress 100

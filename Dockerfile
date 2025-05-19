FROM python:3.11-slim

WORKDIR /app

COPY app /app

RUN apt-get update && apt-get install -y \
    curl xz-utils rclone sudo coreutils \
    && pip install flask \
    && chmod +x /app/backup.sh

EXPOSE 5000

RUN pip install flask flask_apscheduler psutil


CMD ["python", "main.py"]

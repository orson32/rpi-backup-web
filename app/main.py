from flask import Flask, render_template, jsonify, request, send_file
import subprocess, threading, os, psutil, glob
from datetime import datetime
from flask_apscheduler import APScheduler
from apscheduler.triggers.date import DateTrigger
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger

app = Flask(__name__)
scheduler = APScheduler()
scheduler.api_enabled = True
scheduler.init_app(app)
scheduler.start()

backup_status = {"running": False, "log": "", "progress": 0}
LOG_FILE = "/app/log/backup.log"
BACKUP_DIR = "/mnt/backup"
JOB_ID = "scheduled_backup"

# BACKUP THREAD
def run_backup():
    global backup_status
    backup_status = {"running": True, "log": "", "progress": 0}

    process = subprocess.Popen(
        ["bash", "backup.sh"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    for line in process.stdout:
        backup_status["log"] += line
        if "status=" in line:
            try:
                percent = int(line.strip().split("status=")[-1].split("%")[0])
                backup_status["progress"] = percent
            except:
                pass

    process.wait()
    backup_status["running"] = False
    backup_status["progress"] = 100

# HELPERS
def get_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            return round(int(f.read()) / 1000, 1)
    except:
        return 0.0

def get_backup_history():
    files = sorted(glob.glob(f"{BACKUP_DIR}/*.img*"), reverse=True)
    history = []
    for f in files:
        size = round(os.path.getsize(f) / (1024 * 1024), 1)
        date = datetime.fromtimestamp(os.path.getmtime(f)).strftime("%Y-%m-%d %H:%M")
        history.append({
            "filename": os.path.basename(f),
            "size": f"{size} MB",
            "date": date
        })
    return history

# ROUTES
@app.route("/")
def index():
    return render_template("index.html")

@app.route("/start", methods=["POST"])
def start():
    if not backup_status["running"]:
        threading.Thread(target=run_backup).start()
        return jsonify({"status": "started"})
    return jsonify({"status": "already_running"})

@app.route("/status")
def status():
    return jsonify(backup_status)

@app.route("/download-log")
def download_log():
    return send_file(LOG_FILE, as_attachment=True)

@app.route("/metrics")
def metrics():
    return jsonify({
        "cpu": psutil.cpu_percent(),
        "ram": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage("/").percent,
        "temp": get_temp()
    })

@app.route("/info")
def info():
    job = scheduler.get_job(JOB_ID)
    next_run = job.next_run_time.strftime("%Y-%m-%dT%H:%M") if job else datetime.now().strftime("%Y-%m-%dT%H:%M")
    return jsonify({
        "cron_status": job is not None,
        "next_run": next_run,
        "history": get_backup_history()
    })

@app.route("/schedule", methods=["POST"])
def schedule():
    data = request.get_json()
    enabled = data.get("enabled", False)
    next_time = data.get("next")
    schedule_type = data.get("type")
    custom = data.get("custom")

    # Borrar tarea anterior si existe
    if scheduler.get_job(JOB_ID):
        scheduler.remove_job(JOB_ID)

    if not enabled:
        return jsonify({"status": "disabled"})

    # Convertir string a datetime
    start_dt = datetime.strptime(next_time, "%Y-%m-%dT%H:%M")

    if schedule_type == "once":
        trigger = DateTrigger(run_date=start_dt)
    elif schedule_type == "hourly":
        trigger = IntervalTrigger(hours=1, start_date=start_dt)
    elif schedule_type == "daily":
        hour, minute = map(int, next_time.split("T")[1].split(":"))
        trigger = CronTrigger(hour=hour, minute=minute)
    elif schedule_type == "custom" and custom:
        kwargs = {custom["unit"]: int(custom["value"])}
        trigger = IntervalTrigger(**kwargs, start_date=start_dt)
    else:
        return jsonify({"error": "Tipo de programación inválido"}), 400

    scheduler.add_job(func=run_backup, trigger=trigger, id=JOB_ID, replace_existing=True)
    return jsonify({"status": "scheduled"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

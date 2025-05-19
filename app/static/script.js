console.log("✅ script.js fue cargado correctamente");

function startBackup() {
  const btn = document.getElementById("startBtn");
  btn.disabled = true;
  btn.textContent = "En progreso...";

  fetch("/start", { method: "POST" });

  const interval = setInterval(() => {
    fetch("/status").then(res => res.json()).then(data => {
      document.getElementById("log").textContent = data.log;
      const p = data.progress;
      const bar = document.getElementById("progressBar");
      bar.style.width = p + "%";
      bar.textContent = p + "%";
    if (!data.running) {
      clearInterval(interval);
      btn.disabled = false;
      btn.textContent = "Iniciar Backup Manual";

      if (data.log.includes("❌ Error al subir con Rclone")) {
        showErrorToast("❌ Hubo un problema al subir el backup a la nube. Revisa el log.");
      } else {
        showToast("✅ Backup finalizado");
  }
}
    });
  }, 1000);
}

function downloadLog() {
  window.location = "/download-log";
}

function showToast(msg) {
  const alerts = document.getElementById("alerts");
  alerts.innerHTML = `
    <div class="alert alert-success alert-dismissible fade show" role="alert">
      ${msg}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
  `;
}

function refreshWidgets() {
  fetch("/metrics").then(res => res.json()).then(data => {
    document.getElementById("cpu").textContent = data.cpu + "%";
    document.getElementById("ram").textContent = data.ram + "%";
    document.getElementById("disk").textContent = data.disk + "%";
    document.getElementById("temp").textContent = data.temp + " °C";
  });
}

function loadHistoryAndCron() {
  fetch("/info").then(res => res.json()).then(data => {
    const list = document.getElementById("backupHistory");
    list.innerHTML = "";
    data.history.forEach(b => {
      const li = document.createElement("li");
      li.className = "list-group-item bg-dark text-light";
      li.textContent = `${b.date} — ${b.filename} (${b.size})`;
      list.appendChild(li);
    });

    document.getElementById("autoToggle").checked = data.cron_status;
    document.getElementById("nextRun").value = data.next_run.replace(" ", "T");
  });
}
function setSchedule() {
  const time = document.getElementById("nextRun").value;
  const auto = document.getElementById("autoToggle").checked;
  const type = document.getElementById("scheduleType").value;
  let custom = null;

  if (type === "custom") {
    const val = parseInt(document.getElementById("customValue").value);
    const unit = document.getElementById("customUnit").value;
    if (isNaN(val) || val <= 0) {
      showErrorToast("❌ Intervalo inválido");
      return;
    }
    custom = { value: val, unit: unit };
  }

  fetch("/schedule", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ next: time, enabled: auto, type: type, custom: custom })
  }).then(() => showToast("🕒 Programación actualizada"));
}

document.getElementById("scheduleType").addEventListener("change", () => {
  const type = document.getElementById("scheduleType").value;
  document.getElementById("customIntervalGroup").style.display = (type === "custom") ? "block" : "none";
});


document.addEventListener("DOMContentLoaded", () => {
  const startBtn = document.getElementById("startBtn");
  const logBtn = document.getElementById("logBtn");

  if (startBtn) {
    startBtn.addEventListener("click", startBackup);
  }
  if (logBtn) {
    logBtn.addEventListener("click", downloadLog);
  }

  setInterval(refreshWidgets, 5000);
  loadHistoryAndCron();
});

function showErrorToast(msg) {
  const alerts = document.getElementById("alerts");
  alerts.innerHTML = `
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
      ${msg}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
  `;
}

"""
The Enigma Labyrinth - Launcher & Auto-Updater
================================================
Lanzador con interfaz gráfica oscura/elegante (Tkinter) y sistema de
auto-actualización integrado vía GitHub Releases.

Requisitos: Python 3.8+, tkinter (incluido en la mayoría de instalaciones).
"""

import json
import os
import platform
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import messagebox
from io import BytesIO
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen
from zipfile import ZipFile

# ──────────────────────────── Configuración ────────────────────────────
VERSION_URL = (
    "https://raw.githubusercontent.com/JulioDelToro/VideoJuegoToroCorp/"
    "main/version.json"
)
BASE_DIR = Path(__file__).resolve().parent
LOCAL_VERSION_FILE = BASE_DIR / "version.json"
GODOT_EXE = Path(r"C:\Godot\Godot_v4.7.2-stable_win64.exe")
PROJECT_DIR = BASE_DIR

# ──────────────────────────── Paleta de colores ────────────────────────
BG_DARK      = "#0d1117"
BG_MID       = "#161b22"
BG_LIGHT     = "#21262d"
FG_PRIMARY   = "#e6edf3"
FG_SECONDARY = "#8b949e"
ACCENT       = "#58a6ff"
ACCENT_HOVER = "#79c0ff"
SUCCESS      = "#3fb950"
ERROR        = "#f85149"
BTN_PLAY     = "#238636"
BTN_PLAY_HV  = "#2ea043"
BTN_EXIT     = "#da3633"
BTN_EXIT_HV  = "#f85149"


# ──────────────────────── Funciones auxiliares ─────────────────────────

def read_local_version() -> str:
    """Lee la versión local desde version.json."""
    try:
        with open(LOCAL_VERSION_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("version", "0.0.0")
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        return "0.0.0"


def write_local_version(version: str) -> None:
    """Escribe la nueva versión en el archivo local."""
    with open(LOCAL_VERSION_FILE, "w", encoding="utf-8") as f:
        json.dump({"version": version}, f, indent=2)


def compare_versions(local: str, remote: str) -> bool:
    """Devuelve True si la versión remota es mayor a la local."""
    def _parse(v: str):
        return tuple(int(x) for x in v.strip().split("."))
    try:
        return _parse(remote) > _parse(local)
    except (ValueError, TypeError):
        return False


# ──────────────────────────── Clase Launcher ──────────────────────────

class Launcher(tk.Tk):
    """Ventana principal del lanzador."""

    WIDTH = 520
    HEIGHT = 420

    def __init__(self):
        super().__init__()

        # ── Ventana ────────────────────────────────────────────────────
        self.title("The Enigma Labyrinth - Launcher")
        self.configure(bg=BG_DARK)
        self.resizable(False, False)
        self._center_window()

        # ── Título ─────────────────────────────────────────────────────
        title_frame = tk.Frame(self, bg=BG_DARK)
        title_frame.pack(pady=(30, 5))

        tk.Label(
            title_frame,
            text="THE ENIGMA",
            font=("Segoe UI", 28, "bold"),
            fg=ACCENT,
            bg=BG_DARK,
        ).pack()

        tk.Label(
            title_frame,
            text="LABYRINTH",
            font=("Segoe UI", 18),
            fg=FG_PRIMARY,
            bg=BG_DARK,
        ).pack()

        # ── Separador decorativo ───────────────────────────────────────
        sep = tk.Frame(self, bg=ACCENT, height=2, width=260)
        sep.pack(pady=(5, 15))

        # ── Versión local ──────────────────────────────────────────────
        self.local_version = read_local_version()
        self.lbl_version = tk.Label(
            self,
            text=f"Versión local: {self.local_version}",
            font=("Segoe UI", 10),
            fg=FG_SECONDARY,
            bg=BG_DARK,
        )
        self.lbl_version.pack()

        # ── Estado ─────────────────────────────────────────────────────
        self.lbl_status = tk.Label(
            self,
            text="Verificando actualizaciones…",
            font=("Segoe UI", 11),
            fg=FG_PRIMARY,
            bg=BG_DARK,
        )
        self.lbl_status.pack(pady=(15, 5))

        # ── Barra de progreso (canvas sencillo) ───────────────────────
        self.canvas_bar = tk.Canvas(
            self, width=360, height=18, bg=BG_LIGHT, highlightthickness=0
        )
        self.canvas_bar.pack(pady=(0, 20))
        self._bar_rect = self.canvas_bar.create_rectangle(
            0, 0, 0, 18, fill=ACCENT, width=0
        )

        # ── Botones ────────────────────────────────────────────────────
        btn_frame = tk.Frame(self, bg=BG_DARK)
        btn_frame.pack(pady=(5, 25))

        self.btn_play = tk.Button(
            btn_frame,
            text="  ▶  JUGAR  ",
            font=("Segoe UI", 14, "bold"),
            fg="#ffffff",
            bg=BTN_PLAY,
            activeforeground="#ffffff",
            activebackground=BTN_PLAY_HV,
            relief="flat",
            cursor="hand2",
            state="disabled",
            command=self._launch_game,
        )
        self.btn_play.pack(side="left", padx=12, ipady=6)
        self.btn_play.bind("<Enter>", lambda e: self.btn_play.config(bg=BTN_PLAY_HV))
        self.btn_play.bind("<Leave>", lambda e: self.btn_play.config(bg=BTN_PLAY))

        self.btn_exit = tk.Button(
            btn_frame,
            text="  ✕  SALIR  ",
            font=("Segoe UI", 12),
            fg="#ffffff",
            bg=BTN_EXIT,
            activeforeground="#ffffff",
            activebackground=BTN_EXIT_HV,
            relief="flat",
            cursor="hand2",
            command=self.destroy,
        )
        self.btn_exit.pack(side="left", padx=12, ipady=4)
        self.btn_exit.bind("<Enter>", lambda e: self.btn_exit.config(bg=BTN_EXIT_HV))
        self.btn_exit.bind("<Leave>", lambda e: self.btn_exit.config(bg=BTN_EXIT))

        # ── Inicia verificación en hilo secundario ─────────────────────
        threading.Thread(target=self._check_update, daemon=True).start()

    # ── Centrar ventana ───────────────────────────────────────────────
    def _center_window(self):
        self.update_idletasks()
        x = (self.winfo_screenwidth() - self.WIDTH) // 2
        y = (self.winfo_screenheight() - self.HEIGHT) // 2
        self.geometry(f"{self.WIDTH}x{self.HEIGHT}+{x}+{y}")

    # ── Barra de progreso ─────────────────────────────────────────────
    def _set_progress(self, pct: float):
        """Establece la barra de progreso (0-100)."""
        width = int(360 * min(pct, 100) / 100)
        self.canvas_bar.coords(self._bar_rect, 0, 0, width, 18)

    # ── Verificación + descarga ───────────────────────────────────────
    def _check_update(self):
        """Hilo: compara versiones y descarga si es necesario."""
        self.after(0, lambda: self._set_progress(10))

        try:
            with urlopen(VERSION_URL, timeout=10) as resp:
                remote_data = json.loads(resp.read().decode("utf-8"))
        except (URLError, OSError, json.JSONDecodeError):
            # Sin conexión → modo offline
            self.after(0, lambda: self.lbl_status.config(
                text="Sin conexión – Modo offline", fg=FG_SECONDARY
            ))
            self.after(0, lambda: self._set_progress(100))
            self.after(0, lambda: self._enable_play())
            return

        remote_version = remote_data.get("version", "0.0.0")
        download_url = remote_data.get("download_url", "")

        self.after(0, lambda: self._set_progress(30))

        if compare_versions(self.local_version, remote_version):
            # ── Hay actualización disponible ───────────────────────────
            self.after(0, lambda: self.lbl_status.config(
                text=f"Nueva versión {remote_version} encontrada. Descargando…",
                fg=ACCENT,
            ))
            try:
                self._download_and_extract(download_url, remote_version)
            except Exception as exc:
                self.after(0, lambda: self.lbl_status.config(
                    text=f"Error al actualizar: {exc}", fg=ERROR
                ))
                self.after(0, lambda: self._set_progress(100))
                self.after(0, lambda: self._enable_play())
                return
        else:
            self.after(0, lambda: self.lbl_status.config(
                text="✓ El juego está actualizado", fg=SUCCESS
            ))

        self.after(0, lambda: self._set_progress(100))
        self.after(0, lambda: self._enable_play())

    def _download_and_extract(self, url: str, new_version: str):
        """Descarga el zip y extrae en BASE_DIR."""
        if not url:
            raise RuntimeError("URL de descarga vacía")

        self.after(0, lambda: self.lbl_status.config(
            text="Descargando actualización…", fg=ACCENT
        ))

        # Descarga completa en memoria
        with urlopen(url, timeout=60) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            data = bytearray()
            downloaded = 0
            chunk_size = 1024 * 64

            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                data.extend(chunk)
                downloaded += len(chunk)
                if total > 0:
                    pct = 30 + int(50 * downloaded / total)
                    self.after(0, lambda p=pct: self._set_progress(p))

        # Extracción
        self.after(0, lambda: self.lbl_status.config(
            text="Extrayendo archivos…", fg=ACCENT
        ))
        self.after(0, lambda: self._set_progress(85))

        with ZipFile(BytesIO(data)) as zf:
            zf.extractall(BASE_DIR)

        # Actualizar versión local
        write_local_version(new_version)
        self.local_version = new_version

        self.after(0, lambda: self.lbl_version.config(
            text=f"Versión local: {self.local_version}"
        ))
        self.after(0, lambda: self.lbl_status.config(
            text=f"✓ Actualizado a v{new_version}", fg=SUCCESS
        ))
        self.after(0, lambda: self._set_progress(100))

    # ── Habilitar botón JUGAR ─────────────────────────────────────────
    def _enable_play(self):
        self.btn_play.config(state="normal")

    # ── Lanzar el juego ───────────────────────────────────────────────
    def _launch_game(self):
        if not GODOT_EXE.exists():
            messagebox.showerror(
                "Error",
                f"No se encontró Godot Engine:\n{GODOT_EXE}\n\n"
                "Descárgalo de https://godotengine.org/download",
            )
            return

        # Lanzar Godot con el proyecto
        try:
            if platform.system() == "Windows":
                subprocess.Popen(
                    [str(GODOT_EXE), "--path", str(PROJECT_DIR)],
                    creationflags=subprocess.DETACHED_PROCESS,
                )
            else:
                subprocess.Popen(
                    [str(GODOT_EXE), "--path", str(PROJECT_DIR)],
                    start_new_session=True,
                )
        except OSError as exc:
            messagebox.showerror("Error", f"No se pudo iniciar el juego:\n{exc}")
            return

        self.destroy()


# ────────────────────────────── Main ──────────────────────────────────
if __name__ == "__main__":
    app = Launcher()
    app.mainloop()

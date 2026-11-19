# ⚙️ Guía de Instalación y Ejecución — ToroCorp

Instrucciones oficiales para jugar en PC con el Instalador Setup, en dispositivos móviles Android con APK, o abrir y compilar el proyecto fuente desde Godot Engine 4.

---

## 💻 1. Instalación en PC Windows

### Opción A: Usando el Instalador Oficial (Recomendado)
1. Localiza el instalador en:  
   `builds/windows/Setup_ToroCorp_Rutas_de_Poder.exe`
2. Haz doble clic para iniciar el **Asistente de Instalación de ToroCorp**.
3. Selecciona la carpeta de destino deseada (por defecto en tu carpeta de usuario local).
4. Elige si deseas accesos directos en el **Escritorio** y en el **Menú Inicio**.
5. Haz clic en **Instalar**. En pocos segundos el juego quedará instalado con su icono oficial y registrado en las aplicaciones de Windows.
6. Marca la casilla *"Ejecutar ToroCorp: Rutas de Poder ahora"* y presiona **Finalizar**.

### Opción B: Paquete Portable (Sin instalación)
1. Descomprime el archivo `builds/windows/ToroCorp_Rutas_de_Poder_PC_Windows.zip` en cualquier carpeta.
2. Ejecuta directamente `ToroCorp_Rutas_de_Poder.exe`.

---

## 📱 2. Instalación en Celulares y Tablets Android

1. Copia el archivo `builds/android/ToroCorp_Rutas_de_Poder.apk` a tu teléfono (mediante cable USB, Drive o enviándotelo por WhatsApp/Telegram).
2. Abre el archivo en el administrador de descargas o archivos de tu teléfono.
3. Si el sistema te lo solicita, concede el permiso de *"Instalar aplicaciones de fuentes desconocidas"*.
4. Presiona **Instalar** y ¡listo! El juego aparecerá en tu cajón de aplicaciones con el icono de ToroCorp.

---

## 🛠️ 3. Ejecución y Desarrollo desde el Código Fuente (Godot 4)

Si deseas inspeccionar el código o compilar nuevas versiones:
1. Descarga e instala **Godot Engine 4.3 o 4.7+** (versión Standard de 64 bits) desde [godotengine.org](https://godotengine.org).
2. Abre el **Project Manager** de Godot y presiona **Importar**.
3. Navega hasta esta carpeta y selecciona el archivo `project.godot`.
4. Presiona **Editar y Ejecutar**.
5. Presiona la tecla **F5** para iniciar el juego desde la escena principal (`scenes/ui/intro_splash.tscn`).

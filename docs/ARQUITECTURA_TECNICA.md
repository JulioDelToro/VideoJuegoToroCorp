# 🛠️ Arquitectura Técnica y Estructura de Código — ToroCorp

Documento técnico para desarrolladores, colaboradores y evaluadores sobre la arquitectura interna en **Godot Engine 4.x** (GDScript 2.0).

---

## 1. Patrón Arquitectónico General

El proyecto sigue una arquitectura modular desacoplada basada en **Singletons Autoload** para el estado global y **Composición de Nodos** para la simulación física:

```mermaid
graph TD
    GM[Autoload: GameManager] --> Game[Escena Principal: game.gd]
    SM[Autoload: SoundManager] --> Game
    Game --> TG[TerrainGenerator]
    TG --> TC[TerrainChunk (Object Pool)]
    Game --> V[Vehicle (RigidBody2D)]
    Game --> HUD[HUD y Tacómetro]
    Game --> Cam[Camera2D con Zoom Dinámico]
```

---

## 2. Descripción de Módulos Principales

### 2.1 GameManager (`scripts/autoload/game_manager.gd`)
- **Responsabilidad:** Singleton global que gestiona el estado de partida, inventario de monedas, rubíes, distancias récord, vehículo actualmente seleccionado, mejoras activas y persistencia.
- **Persistencia en Disco:** Guarda y carga de forma segura en `user://savegame.json` utilizando `FileAccess` nativo de Godot 4.
- **Señales Globales:**
  - `coins_changed(new_coins: int)`
  - `rubies_changed(new_rubies: int)`
  - `distance_updated(distance_m: float)`
  - `game_over_triggered(reason: String)`
  - `upgrades_updated()`
  - `vehicle_changed(vehicle_id: String)`
  - `route_changed(route_id: String)`
  - `level_completed(level_num: int, unlocked_route_id: String, reward_coins: int)`

### 2.2 SoundManager (`scripts/autoload/sound_manager.gd`)
- **Responsabilidad:** Controlador centralizado de audio en tiempo real.
- **Carga Directa en Memoria (Bypass de Importador):** Implementa la función `_load_wav_safe()` que lee los bytes brutos del archivo `.wav` y construye un `AudioStreamWAV` directamente en memoria, eliminando dependencias y bloqueos de importación del editor de Godot.
- **Modulación Dinámica de Pitch:** El motor adapta su frecuencia de reproducción (`pitch_scale`) entre `0.7` y `2.1` en tiempo real de acuerdo a la relación `speed_ratio` y si el pedal de aceleración está oprimido.

### 2.3 Simulación Física del Vehículo (`scenes/vehicle/vehicle.gd`)
- **Tipo de Nodo:** `RigidBody2D` con modo de integración de físicas personalizado (`_integrate_forces`).
- **Suspensión Híbrida:** Combina `ShapeCast2D` para calcular la penetración contra la malla poligonal del terreno y fuerzas elásticas restauradoras tipo resorte amortiguado Hooke-Kelvin:
  $$F_s = -k \cdot x - c \cdot v$$
- **Detección de Cabeza del Conductor (`driver_head`):** `Area2D` con máscara de colisión contra el terreno. Si entra en contacto con velocidad relativa suficiente, emite la señal de Game Over por volcadura instantánea.

### 2.4 Generador de Terreno con Pooling (`scenes/terrain/terrain_generator.gd` y `terrain_chunk.gd`)
- **Sistema de Object Pooling (`_chunk_pool`):** En lugar de instanciar y destruir nodos continuamente (lo que provocaría pausas de Garbage Collector), los chunks que quedan atrás del jugador son reciclados, reposicionados al frente y reinicializados mediante la función `setup()`.
- **Perfilado Matemático Suave:** Cada chunk calcula su superficie mediante funciones sinusoidales compuestas combinadas con curvas Bézier para rampas y obstáculos, garantizando que el punto de salida de un chunk coincida exactamente en posición y tangente con el punto de entrada del siguiente ($C^1$ continuidad geométrica).

---

## 3. Optimizaciones de Rendimiento
1. **Compresión VRAM ETC2/ASTC:** Habilitada en `project.godot` para garantizar tiempos de carga instantáneos y bajo consumo de memoria gráfica en dispositivos móviles Android y PCs con GPUs integradas.
2. **Object Pooling en Coleccionables:** Las monedas y bidones de gasolina son generados dentro de los contenedores locales de cada chunk, destruyéndose de forma limpia cuando el chunk se desactiva.
3. **Framerate Estable a 60 FPS:** Física bloqueada a 60 ticks por segundo (`physics/common/physics_ticks_per_second = 60`) con suavizado de interpolación activado.

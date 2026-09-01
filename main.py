"""
El Laberinto de Acertijos — Juego 2D (Pygame)
==============================================
Juego de acertijos top-down basado en cuadrícula.

Requisitos: Python 3.8+, pygame (`pip install pygame`)
"""

import sys
import random

try:
    import pygame
except ImportError:
    print("ERROR: Se requiere pygame.  Instálalo con:  pip install pygame")
    sys.exit(1)

# ════════════════════════════ CONSTANTES ════════════════════════════════

# Pantalla
SCREEN_W, SCREEN_H = 800, 600
FPS = 60

# Cuadrícula
TILE_SIZE = 48

# Colores
COL_BG          = (13, 17, 23)
COL_FLOOR       = (30, 38, 50)
COL_WALL        = (55, 62, 78)
COL_DOOR        = (180, 120, 40)
COL_DOOR_GLOW   = (220, 170, 60)
COL_EXIT        = (63, 185, 80)
COL_EXIT_GLOW   = (100, 220, 120)
COL_PLAYER      = (88, 166, 255)
COL_PLAYER_EDGE = (50, 120, 210)
COL_TEXT         = (230, 237, 243)
COL_TEXT_DIM     = (139, 148, 158)
COL_ACCENT       = (88, 166, 255)
COL_OVERLAY      = (0, 0, 0, 180)
COL_BTN          = (35, 134, 54)
COL_BTN_HV       = (46, 160, 67)
COL_BTN_EXIT     = (218, 54, 51)
COL_BTN_EXIT_HV  = (248, 81, 73)
COL_DIALOG_BG    = (22, 27, 34)
COL_DIALOG_BD    = (88, 166, 255)
COL_INPUT_BG     = (13, 17, 23)
COL_CORRECT      = (63, 185, 80)
COL_WRONG        = (248, 81, 73)

# ════════════════════════════ MAPA ═════════════════════════════════════

# 0 = suelo, 1 = muro, 2 = puerta (acertijo), 3 = meta/salida
GAME_MAP = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 0, 0, 0, 1, 0, 2, 0, 0, 0, 1, 0, 1],
    [1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 1, 0, 1],
    [1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1],
    [1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 3, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
]

MAP_ROWS = len(GAME_MAP)
MAP_COLS = len(GAME_MAP[0])

# Posición inicial del jugador (fila, columna)
PLAYER_START = (1, 1)

# ═══════════════════════ BANCO DE ACERTIJOS ════════════════════════════

RIDDLES = [
    {
        "pregunta": "Tengo ciudades, pero no casas;\nbosques, pero no árboles;\ny agua, pero no peces.\n¿Qué soy?",
        "respuesta": "mapa",
    },
    {
        "pregunta": "Si me nombras, desaparezco.\n¿Qué soy?",
        "respuesta": "silencio",
    },
    {
        "pregunta": "Cuanto más seco, más mojo.\n¿Qué soy?",
        "respuesta": "toalla",
    },
    {
        "pregunta": "Oro parece, plata no es.\n¿Qué es?",
        "respuesta": "platano",
    },
    {
        "pregunta": "¿Qué tiene un ojo pero no puede ver?",
        "respuesta": "aguja",
    },
    {
        "pregunta": "Soy tuyo pero los demás\nme usan más que tú.\n¿Qué soy?",
        "respuesta": "nombre",
    },
    {
        "pregunta": "Camino sin pies,\nhablo sin boca.\n¿Qué soy?",
        "respuesta": "carta",
    },
    {
        "pregunta": "Blanca por dentro,\nverde por fuera.\nSi quieres que te lo diga, espera.\n¿Qué es?",
        "respuesta": "pera",
    },
]


# ═══════════════════════ FUNCIONES AUXILIARES ══════════════════════════

def deep_copy_map(src):
    """Devuelve una copia profunda del mapa."""
    return [row[:] for row in src]


def draw_text_centered(surface, text, font, color, y):
    """Dibuja texto centrado horizontalmente."""
    rendered = font.render(text, True, color)
    rect = rendered.get_rect(center=(SCREEN_W // 2, y))
    surface.blit(rendered, rect)


def make_overlay(alpha=180):
    """Genera una superficie semi-transparente para superposiciones."""
    overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, alpha))
    return overlay


class Button:
    """Botón interactivo con efecto hover."""

    def __init__(self, text, x, y, w, h, color, hover_color, font, text_color=COL_TEXT):
        self.text = text
        self.rect = pygame.Rect(x, y, w, h)
        self.color = color
        self.hover_color = hover_color
        self.font = font
        self.text_color = text_color
        self.hovered = False

    def draw(self, surface):
        col = self.hover_color if self.hovered else self.color
        pygame.draw.rect(surface, col, self.rect, border_radius=8)
        pygame.draw.rect(surface, COL_ACCENT, self.rect, width=2, border_radius=8)
        txt = self.font.render(self.text, True, self.text_color)
        txt_rect = txt.get_rect(center=self.rect.center)
        surface.blit(txt, txt_rect)

    def update(self, mouse_pos):
        self.hovered = self.rect.collidepoint(mouse_pos)

    def clicked(self, event):
        return (
            event.type == pygame.MOUSEBUTTONDOWN
            and event.button == 1
            and self.hovered
        )


# ════════════════════════════ CLASE JUEGO ══════════════════════════════

class Game:
    """Clase principal que gestiona el ciclo del juego."""

    # Estados
    STATE_MENU    = "menu"
    STATE_PLAYING = "playing"
    STATE_RIDDLE  = "riddle"
    STATE_PAUSE   = "pause"
    STATE_WIN     = "win"

    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
        pygame.display.set_caption("El Laberinto de Acertijos")
        self.clock = pygame.time.Clock()

        # Fuentes
        self.font_title = pygame.font.SysFont("Segoe UI", 52, bold=True)
        self.font_sub   = pygame.font.SysFont("Segoe UI", 26)
        self.font_btn   = pygame.font.SysFont("Segoe UI", 22, bold=True)
        self.font_small = pygame.font.SysFont("Segoe UI", 18)
        self.font_riddle = pygame.font.SysFont("Segoe UI", 20)
        self.font_input = pygame.font.SysFont("Segoe UI", 22)

        # Estado
        self.state = self.STATE_MENU
        self.running = True

        # Mapa / jugador
        self.game_map = None
        self.player_row = 0
        self.player_col = 0

        # Acertijos — asignar uno por puerta
        self._riddle_pool = []
        self._door_riddles: dict[tuple[int, int], dict] = {}

        # Estado del diálogo de acertijo
        self.current_riddle = None
        self.riddle_input = ""
        self.riddle_feedback = ""
        self.riddle_door_pos = (0, 0)
        self.riddle_feedback_timer = 0

        # Transición alpha para fade-in sutil
        self.transition_alpha = 255

        # Botones de menú
        bx = SCREEN_W // 2 - 100
        self.btn_play = Button("JUGAR", bx, 320, 200, 55, COL_BTN, COL_BTN_HV, self.font_btn)
        self.btn_exit = Button("SALIR", bx, 400, 200, 55, COL_BTN_EXIT, COL_BTN_EXIT_HV, self.font_btn)

        # Botones de pausa
        self.btn_resume = Button("CONTINUAR", bx, 280, 200, 50, COL_BTN, COL_BTN_HV, self.font_btn)
        self.btn_menu   = Button("MENÚ", bx, 350, 200, 50, COL_BTN_EXIT, COL_BTN_EXIT_HV, self.font_btn)

        # Botones de victoria
        self.btn_win_menu = Button("MENÚ PRINCIPAL", bx - 20, 380, 240, 55, COL_BTN, COL_BTN_HV, self.font_btn)

        # Offset de cámara para centrar el mapa
        self.cam_x = 0
        self.cam_y = 0

        # Animación del jugador (interpolación suave)
        self.player_visual_x = 0.0
        self.player_visual_y = 0.0
        self.move_speed = 10.0  # tiles/seg

    # ───────────────── Inicializar partida ─────────────────────────────
    def _start_game(self):
        self.game_map = deep_copy_map(GAME_MAP)
        self.player_row, self.player_col = PLAYER_START
        self.player_visual_x = float(self.player_col)
        self.player_visual_y = float(self.player_row)

        # Asignar acertijos a puertas
        self._riddle_pool = list(RIDDLES)
        random.shuffle(self._riddle_pool)
        self._door_riddles.clear()
        idx = 0
        for r in range(MAP_ROWS):
            for c in range(MAP_COLS):
                if self.game_map[r][c] == 2:
                    riddle = self._riddle_pool[idx % len(self._riddle_pool)]
                    self._door_riddles[(r, c)] = riddle
                    idx += 1

        self.state = self.STATE_PLAYING
        self.transition_alpha = 255

        # Calcular offset de cámara
        map_pixel_w = MAP_COLS * TILE_SIZE
        map_pixel_h = MAP_ROWS * TILE_SIZE
        self.cam_x = (SCREEN_W - map_pixel_w) // 2
        self.cam_y = (SCREEN_H - map_pixel_h) // 2

    # ───────────────── Movimiento ──────────────────────────────────────
    def _try_move(self, dr, dc):
        """Intenta mover al jugador una celda."""
        nr, nc = self.player_row + dr, self.player_col + dc
        if not (0 <= nr < MAP_ROWS and 0 <= nc < MAP_COLS):
            return

        cell = self.game_map[nr][nc]

        if cell == 1:
            return  # muro

        if cell == 2:
            # Puerta: abrir diálogo de acertijo
            self._open_riddle(nr, nc)
            return

        if cell == 3:
            # Meta: victoria
            self.player_row, self.player_col = nr, nc
            self.state = self.STATE_WIN
            return

        # Suelo libre
        self.player_row, self.player_col = nr, nc

    def _open_riddle(self, row, col):
        key = (row, col)
        self.current_riddle = self._door_riddles.get(key)
        if self.current_riddle is None:
            # Sin acertijo → desbloquear
            self.game_map[row][col] = 0
            return
        self.riddle_door_pos = key
        self.riddle_input = ""
        self.riddle_feedback = ""
        self.riddle_feedback_timer = 0
        self.state = self.STATE_RIDDLE

    def _check_riddle_answer(self):
        answer = self.riddle_input.strip().lower()
        correct = self.current_riddle["respuesta"].strip().lower()
        # Aceptar con o sin acentos simples
        import unicodedata
        def _normalize(s):
            return "".join(
                c for c in unicodedata.normalize("NFD", s)
                if unicodedata.category(c) != "Mn"
            )
        if _normalize(answer) == _normalize(correct):
            # Correcto
            r, c = self.riddle_door_pos
            self.game_map[r][c] = 0
            self.riddle_feedback = "¡Correcto!"
            self.riddle_feedback_timer = FPS * 1  # 1 segundo
            self.state = self.STATE_PLAYING
            self.current_riddle = None
        else:
            self.riddle_feedback = "Incorrecto. Intenta de nuevo."
            self.riddle_feedback_timer = FPS * 2

    # ───────────────── Bucle principal ─────────────────────────────────
    def run(self):
        while self.running:
            dt = self.clock.tick(FPS) / 1000.0
            events = pygame.event.get()
            mouse_pos = pygame.mouse.get_pos()

            for event in events:
                if event.type == pygame.QUIT:
                    self.running = False
                    break

            if not self.running:
                break

            if self.state == self.STATE_MENU:
                self._update_menu(events, mouse_pos)
                self._draw_menu(mouse_pos)
            elif self.state == self.STATE_PLAYING:
                self._update_playing(events, dt)
                self._draw_playing(dt)
            elif self.state == self.STATE_RIDDLE:
                self._update_riddle(events)
                self._draw_riddle()
            elif self.state == self.STATE_PAUSE:
                self._update_pause(events, mouse_pos)
                self._draw_pause(mouse_pos)
            elif self.state == self.STATE_WIN:
                self._update_win(events, mouse_pos)
                self._draw_win(mouse_pos)

            pygame.display.flip()

        pygame.quit()

    # ═══════════════ MENÚ PRINCIPAL ════════════════════════════════════

    def _update_menu(self, events, mouse_pos):
        self.btn_play.update(mouse_pos)
        self.btn_exit.update(mouse_pos)
        for event in events:
            if self.btn_play.clicked(event):
                self._start_game()
            elif self.btn_exit.clicked(event):
                self.running = False

    def _draw_menu(self, mouse_pos):
        self.screen.fill(COL_BG)

        # Líneas decorativas de fondo
        for i in range(0, SCREEN_W, 60):
            pygame.draw.line(self.screen, (18, 24, 33), (i, 0), (i, SCREEN_H))
        for j in range(0, SCREEN_H, 60):
            pygame.draw.line(self.screen, (18, 24, 33), (0, j), (SCREEN_W, j))

        # Título
        draw_text_centered(self.screen, "EL LABERINTO", self.font_title, COL_ACCENT, 160)
        draw_text_centered(self.screen, "DE ACERTIJOS", self.font_sub, COL_TEXT, 220)

        # Separador
        pygame.draw.line(
            self.screen, COL_ACCENT,
            (SCREEN_W // 2 - 120, 265), (SCREEN_W // 2 + 120, 265), 2
        )

        self.btn_play.draw(self.screen)
        self.btn_exit.draw(self.screen)

        # Créditos
        draw_text_centered(self.screen, "Controles: Flechas / WASD  |  ESC = Pausa",
                           self.font_small, COL_TEXT_DIM, SCREEN_H - 40)

    # ═══════════════ JUGANDO ═══════════════════════════════════════════

    def _update_playing(self, events, dt):
        for event in events:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.state = self.STATE_PAUSE
                    return
                elif event.key in (pygame.K_UP, pygame.K_w):
                    self._try_move(-1, 0)
                elif event.key in (pygame.K_DOWN, pygame.K_s):
                    self._try_move(1, 0)
                elif event.key in (pygame.K_LEFT, pygame.K_a):
                    self._try_move(0, -1)
                elif event.key in (pygame.K_RIGHT, pygame.K_d):
                    self._try_move(0, 1)

        # Interpolación suave del jugador
        target_x = float(self.player_col)
        target_y = float(self.player_row)
        speed = self.move_speed * dt * TILE_SIZE
        dx = target_x - self.player_visual_x
        dy = target_y - self.player_visual_y
        if abs(dx) > 0.01:
            self.player_visual_x += (1 if dx > 0 else -1) * min(abs(dx), speed / TILE_SIZE)
        else:
            self.player_visual_x = target_x
        if abs(dy) > 0.01:
            self.player_visual_y += (1 if dy > 0 else -1) * min(abs(dy), speed / TILE_SIZE)
        else:
            self.player_visual_y = target_y

        # Reducir timer de feedback
        if self.riddle_feedback_timer > 0:
            self.riddle_feedback_timer -= 1

        # Transición fade-in
        if self.transition_alpha > 0:
            self.transition_alpha = max(0, self.transition_alpha - 8)

    def _draw_playing(self, dt):
        self.screen.fill(COL_BG)

        # Dibujar mapa
        for r in range(MAP_ROWS):
            for c in range(MAP_COLS):
                x = self.cam_x + c * TILE_SIZE
                y = self.cam_y + r * TILE_SIZE
                cell = self.game_map[r][c]

                if cell == 0:
                    pygame.draw.rect(self.screen, COL_FLOOR, (x, y, TILE_SIZE, TILE_SIZE))
                    pygame.draw.rect(self.screen, (25, 32, 42), (x, y, TILE_SIZE, TILE_SIZE), 1)
                elif cell == 1:
                    pygame.draw.rect(self.screen, COL_WALL, (x, y, TILE_SIZE, TILE_SIZE))
                    # Detalle del muro
                    pygame.draw.rect(self.screen, (45, 52, 68), (x + 2, y + 2, TILE_SIZE - 4, TILE_SIZE - 4))
                    pygame.draw.line(self.screen, (65, 72, 88), (x, y), (x + TILE_SIZE, y))
                elif cell == 2:
                    pygame.draw.rect(self.screen, COL_FLOOR, (x, y, TILE_SIZE, TILE_SIZE))
                    inner = pygame.Rect(x + 4, y + 4, TILE_SIZE - 8, TILE_SIZE - 8)
                    pygame.draw.rect(self.screen, COL_DOOR, inner, border_radius=4)
                    pygame.draw.rect(self.screen, COL_DOOR_GLOW, inner, width=2, border_radius=4)
                    # Icono candado (círculo + rectángulo)
                    cx, cy = x + TILE_SIZE // 2, y + TILE_SIZE // 2
                    pygame.draw.circle(self.screen, COL_DOOR_GLOW, (cx, cy - 4), 6, 2)
                    pygame.draw.rect(self.screen, COL_DOOR_GLOW, (cx - 5, cy, 10, 8))
                elif cell == 3:
                    pygame.draw.rect(self.screen, COL_FLOOR, (x, y, TILE_SIZE, TILE_SIZE))
                    inner = pygame.Rect(x + 3, y + 3, TILE_SIZE - 6, TILE_SIZE - 6)
                    pygame.draw.rect(self.screen, COL_EXIT, inner, border_radius=6)
                    pygame.draw.rect(self.screen, COL_EXIT_GLOW, inner, width=2, border_radius=6)
                    # Estrella simple
                    txt = self.font_small.render("★", True, (255, 255, 255))
                    self.screen.blit(txt, txt.get_rect(center=(x + TILE_SIZE // 2, y + TILE_SIZE // 2)))

        # Jugador
        px = self.cam_x + self.player_visual_x * TILE_SIZE + TILE_SIZE // 2
        py = self.cam_y + self.player_visual_y * TILE_SIZE + TILE_SIZE // 2
        radius = TILE_SIZE // 2 - 6
        pygame.draw.circle(self.screen, COL_PLAYER_EDGE, (int(px), int(py)), radius + 2)
        pygame.draw.circle(self.screen, COL_PLAYER, (int(px), int(py)), radius)
        # Brillo
        pygame.draw.circle(self.screen, (140, 200, 255), (int(px) - 3, int(py) - 3), radius // 3)

        # HUD
        hud_txt = self.font_small.render("ESC = Pausa  |  Flechas/WASD = Mover", True, COL_TEXT_DIM)
        self.screen.blit(hud_txt, (10, SCREEN_H - 30))

        # Feedback del acertijo (superpuesto brevemente)
        if self.riddle_feedback_timer > 0 and self.riddle_feedback:
            col = COL_CORRECT if "Correcto" in self.riddle_feedback else COL_WRONG
            fb_txt = self.font_btn.render(self.riddle_feedback, True, col)
            fb_rect = fb_txt.get_rect(center=(SCREEN_W // 2, 30))
            bg_rect = fb_rect.inflate(20, 10)
            pygame.draw.rect(self.screen, COL_DIALOG_BG, bg_rect, border_radius=6)
            pygame.draw.rect(self.screen, col, bg_rect, width=2, border_radius=6)
            self.screen.blit(fb_txt, fb_rect)

        # Transición fade-in
        if self.transition_alpha > 0:
            fade = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
            fade.fill((0, 0, 0, self.transition_alpha))
            self.screen.blit(fade, (0, 0))

    # ═══════════════ DIÁLOGO DE ACERTIJO ══════════════════════════════

    def _update_riddle(self, events):
        for event in events:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    # Cerrar diálogo sin responder
                    self.state = self.STATE_PLAYING
                    self.current_riddle = None
                    return
                elif event.key == pygame.K_RETURN:
                    self._check_riddle_answer()
                    return
                elif event.key == pygame.K_BACKSPACE:
                    self.riddle_input = self.riddle_input[:-1]
                else:
                    if event.unicode and event.unicode.isprintable():
                        self.riddle_input += event.unicode

    def _draw_riddle(self):
        # Dibujar el mapa debajo con overlay oscuro
        self._draw_playing(0)
        overlay = make_overlay(200)
        self.screen.blit(overlay, (0, 0))

        if not self.current_riddle:
            return

        # Cuadro de diálogo centrado
        dw, dh = 500, 320
        dx = (SCREEN_W - dw) // 2
        dy = (SCREEN_H - dh) // 2
        dialog = pygame.Rect(dx, dy, dw, dh)

        pygame.draw.rect(self.screen, COL_DIALOG_BG, dialog, border_radius=12)
        pygame.draw.rect(self.screen, COL_DIALOG_BD, dialog, width=2, border_radius=12)

        # Título
        title_txt = self.font_btn.render("🔒  ACERTIJO", True, COL_ACCENT)
        self.screen.blit(title_txt, (dx + 20, dy + 15))

        # Separador
        pygame.draw.line(self.screen, COL_ACCENT, (dx + 15, dy + 50), (dx + dw - 15, dy + 50), 1)

        # Pregunta (multilinea)
        lines = self.current_riddle["pregunta"].split("\n")
        for i, line in enumerate(lines):
            txt = self.font_riddle.render(line, True, COL_TEXT)
            self.screen.blit(txt, (dx + 25, dy + 65 + i * 28))

        # Campo de entrada
        input_y = dy + dh - 120
        input_rect = pygame.Rect(dx + 25, input_y, dw - 50, 40)
        pygame.draw.rect(self.screen, COL_INPUT_BG, input_rect, border_radius=6)
        pygame.draw.rect(self.screen, COL_ACCENT, input_rect, width=2, border_radius=6)

        prompt_txt = self.font_input.render(self.riddle_input + "│", True, COL_TEXT)
        self.screen.blit(prompt_txt, (input_rect.x + 10, input_rect.y + 8))

        # Instrucciones
        hint = self.font_small.render("Escribe tu respuesta y presiona ENTER  |  ESC = Cerrar", True, COL_TEXT_DIM)
        self.screen.blit(hint, (dx + 25, dy + dh - 60))

        # Feedback
        if self.riddle_feedback and self.riddle_feedback_timer > 0:
            col = COL_WRONG
            fb = self.font_riddle.render(self.riddle_feedback, True, col)
            self.screen.blit(fb, (dx + 25, dy + dh - 35))

    # ═══════════════ PAUSA ═════════════════════════════════════════════

    def _update_pause(self, events, mouse_pos):
        self.btn_resume.update(mouse_pos)
        self.btn_menu.update(mouse_pos)
        for event in events:
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                self.state = self.STATE_PLAYING
                return
            if self.btn_resume.clicked(event):
                self.state = self.STATE_PLAYING
                return
            if self.btn_menu.clicked(event):
                self.state = self.STATE_MENU
                return

    def _draw_pause(self, mouse_pos):
        self._draw_playing(0)
        overlay = make_overlay(200)
        self.screen.blit(overlay, (0, 0))

        draw_text_centered(self.screen, "PAUSA", self.font_title, COL_ACCENT, 200)
        self.btn_resume.draw(self.screen)
        self.btn_menu.draw(self.screen)

    # ═══════════════ VICTORIA ══════════════════════════════════════════

    def _update_win(self, events, mouse_pos):
        self.btn_win_menu.update(mouse_pos)
        for event in events:
            if self.btn_win_menu.clicked(event):
                self.state = self.STATE_MENU
                return

    def _draw_win(self, mouse_pos):
        self.screen.fill(COL_BG)

        # Líneas decorativas
        for i in range(0, SCREEN_W, 60):
            pygame.draw.line(self.screen, (18, 24, 33), (i, 0), (i, SCREEN_H))

        draw_text_centered(self.screen, "¡FELICIDADES!", self.font_title, COL_EXIT_GLOW, 180)
        draw_text_centered(self.screen, "Has escapado del laberinto", self.font_sub, COL_TEXT, 250)
        draw_text_centered(self.screen, "Resolviste todos los acertijos.", self.font_small, COL_TEXT_DIM, 300)

        self.btn_win_menu.draw(self.screen)


# ──────────────────────────── MAIN ─────────────────────────────────────
if __name__ == "__main__":
    game = Game()
    game.run()

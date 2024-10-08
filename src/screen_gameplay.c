#include "camera.h"
#include "player.h"
#include "raylib.h"

// global
static bool is_paused = false;

static void draw_grid(int size) {
  for (int x = 0; x < 10; x++) {
    for (int y = 0; y < 10; y++) {
      DrawRectangleLines(x * size, y * size, size, size, WHITE);
    }
  }
}

// Gameplay Screen Initialization logic
void init_gameplay_screen() {
  init_player();
  init_camera();
}

// Gameplay Screen Update logic
void update_gameplay_screen() {
  if (IsKeyPressed(KEY_P))
    is_paused = !is_paused;

  if (!is_paused) {
    update_player();
    update_camera();
  }
}

// Gameplay Screen Draw logic
void draw_gameplay_screen() {
  BeginMode2D(camera);

  draw_player();
  draw_grid(16);

  EndMode2D();

  if (is_paused) {
    int w = GetScreenWidth();
    int h = GetRenderHeight();
    DrawRectangle(0, 0, w, h, Fade(BLACK, 0.75f));
    int tx = (float)w / 2 - 60;
    int ty = (float)h / 2 - 30;
    DrawText("PAUSED", tx, ty, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void unload_gameplay_screen() { unload_player(); }

// Gameplay Screen should finish?
int finish_gameplay_screen() { return 0; }

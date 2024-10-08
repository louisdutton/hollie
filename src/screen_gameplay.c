#include "player.h"
#include "raylib.h"
#include "raymath.h"

// global
static bool is_paused = false;

// camera
static Camera2D camera = {.zoom = 1};

// Gameplay Screen Initialization logic
void init_gameplay_screen() { init_player(); }

void camera_follow_target() {
  camera.target.x = position.x - (float)GetScreenWidth() / 2;
  camera.target.y = position.y - (float)GetScreenHeight() / 2;
}

// Gameplay Screen Update logic
void update_gameplay_screen() {
  if (IsKeyPressed(KEY_P))
    is_paused = !is_paused;

  if (!is_paused) {
    update_player();
    camera_follow_target();
  }
}

// Gameplay Screen Draw logic
void draw_gameplay_screen() {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), BLUE);

  BeginMode2D(camera);

  draw_player();

  EndMode2D();

  if (is_paused) {
    int tx = GetScreenWidth() / 2 - 60;
    int ty = GetScreenHeight() / 2 - 30;
    DrawText("PAUSED", tx, ty, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void unload_gameplay_screen() { unload_player(); }

// Gameplay Screen should finish?
int finish_gameplay_screen() { return 0; }

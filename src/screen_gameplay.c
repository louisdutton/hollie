#include "player.h"
#include "raylib.h"
#include "raymath.h"

// global
static bool is_paused = false;

// camera
static Camera2D camera = {.zoom = 1};

// Gameplay Screen Initialization logic
void InitGameplayScreen() { InitPlayer(); }

void CameraFollowTarget() {
  camera.target.x = position.x - (float)GetScreenWidth() / 2;
  camera.target.y = position.y - (float)GetScreenHeight() / 2;
}

// Gameplay Screen Update logic
void UpdateGameplayScreen() {
  if (IsKeyPressed(KEY_P))
    is_paused = !is_paused;

  if (!is_paused) {
    UpdatePlayer();
    CameraFollowTarget();
  }
}

// Gameplay Screen Draw logic
void DrawGameplayScreen() {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), BLUE);

  BeginMode2D(camera);

  DrawPlayer();

  EndMode2D();

  if (is_paused) {
    int tx = GetScreenWidth() / 2 - 60;
    int ty = GetScreenHeight() / 2 - 30;
    DrawText("PAUSED", tx, ty, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void UnloadGameplayScreen() { UnloadPlayer(); }

// Gameplay Screen should finish?
int FinishGameplayScreen() { return 0; }

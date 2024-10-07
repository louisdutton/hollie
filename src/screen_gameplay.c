#include "raylib.h"
#include "raymath.h"
#include "screens.h"
#include <stdio.h>

static const Color bg_colour = PURPLE;
static const int MOVE_SPEED = 2;

static bool isPaused = false;
static int x = 0;
static int y = 0;
static int width = 20;
static int height = 20;

// Gameplay Screen Initialization logic
void InitGameplayScreen(void) {
  x = GetScreenWidth() / 2;
  y = GetScreenHeight() / 2;
}

// Gameplay Screen Update logic
void UpdateGameplayScreen(void) {
  if (IsKeyPressed(KEY_P))
    isPaused = !isPaused;

  if (!isPaused) {
    if (IsKeyDown(KEY_A))
      x -= MOVE_SPEED;
    if (IsKeyDown(KEY_D))
      x += MOVE_SPEED;
    if (IsKeyDown(KEY_W))
      y -= MOVE_SPEED;
    if (IsKeyDown(KEY_S))
      y += MOVE_SPEED;
  }
}

// Gameplay Screen Draw logic
void DrawGameplayScreen(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), BLUE);
  DrawRectangle(x, y, width, height, WHITE);
  if (isPaused) {
    DrawText("PAUSED", 130, 220, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void UnloadGameplayScreen(void) {}

// Gameplay Screen should finish?
int FinishGameplayScreen(void) { return false; }

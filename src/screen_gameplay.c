#include "raylib.h"
#include "raymath.h"
#include "screens.h"
#include <stdio.h>

static int finishScreen = 0;
static bool isPaused = false;
static Color bg_colour = PURPLE;

static int x = 0;
static int y = 0;
static int width = 10;
static int height = 10;

static const int MOVE_SPEED = 5;

// Gameplay Screen Initialization logic
void InitGameplayScreen(void) {
  finishScreen = 0;
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

    // Press enter or tap to change to ENDING screen
    if (IsKeyPressed(KEY_ENTER) || IsGestureDetected(GESTURE_TAP)) {
      finishScreen = 1;
      PlaySound(fxCoin);
    }
  }
}

// Gameplay Screen Draw logic
void DrawGameplayScreen(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), BLACK);
  Vector2 pos = {20, 10};
  DrawTextEx(font, "GAMEPLAY SCREEN", pos, font.baseSize * 3.0f, 4, WHITE);
  DrawRectangle(x, y, width, height, WHITE);
  if (isPaused) {
    DrawText("PAUSED", 130, 220, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void UnloadGameplayScreen(void) {}

// Gameplay Screen should finish?
int FinishGameplayScreen(void) { return finishScreen; }

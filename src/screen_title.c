#include "raylib.h"
#include "screens.h"

static int framesCounter = 0;
static int finishScreen = 0;

// Title Screen Initialization logic
void InitTitleScreen(void) {
  // TODO: Initialize TITLE screen variables here!
  framesCounter = 0;
  finishScreen = 0;
}

// Title Screen Update logic
void UpdateTitleScreen(void) {
  // TODO: Update TITLE screen variables here!

  // Press enter or tap to change to GAMEPLAY screen
  if (IsKeyPressed(KEY_ENTER) || IsGestureDetected(GESTURE_TAP)) {
    // finishScreen = 1;   // OPTIONS
    finishScreen = 2; // GAMEPLAY
    PlaySound(fxCoin);
  }
}

// Title Screen Draw logic
void DrawTitleScreen(void) {
  // TODO: Draw TITLE screen here!
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), GREEN);
  Vector2 pos = {20, 10};
  DrawTextEx(font, "TITLE SCREEN", pos, font.baseSize * 3.0f, 4, DARKGREEN);
  DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20,
           DARKGREEN);
}

// Title Screen Unload logic
void UnloadTitleScreen(void) {
  // TODO: Unload TITLE screen variables here!
}

// Title Screen should finish?
int FinishTitleScreen(void) { return finishScreen; }

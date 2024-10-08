#include "raylib.h"
#include "screens.h"

typedef struct Screen {
  int frames_counter;
  int finish_screen;
} Screen;

static Screen screen_title = {.finish_screen = 0, .frames_counter = 0};

// Title Screen Initialization logic
void InitTitleScreen(void) {
  screen_title.frames_counter = 0;
  screen_title.finish_screen = 0;
}

// Title Screen Update logic
void UpdateTitleScreen(void) {
  if (IsKeyPressed(KEY_ENTER) || IsGestureDetected(GESTURE_TAP)) {
    screen_title.finish_screen = 2; // GAMEPLAY
    PlaySound(fx_coin);
  }
}

// Title Screen Draw logic
void DrawTitleScreen(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), GREEN);
  Vector2 pos = {20, 10};
  DrawTextEx(font, "TITLE SCREEN", pos, font.baseSize * 3.0f, 4, DARKGREEN);
  DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20,
           DARKGREEN);
}

// Title Screen Unload logic
void UnloadTitleScreen(void) {}

// Title Screen should finish?
int FinishTitleScreen(void) { return screen_title.finish_screen; }

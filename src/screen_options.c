#include "raylib.h"
#include "screens.h"

static int framesCounter = 0;
static int finishScreen = 0;

// Options Screen Initialization logic
void init_options_screen(void) {
  // TODO: Initialize OPTIONS screen variables here!
  framesCounter = 0;
  finishScreen = 0;
}

// Options Screen Update logic
void UpdateOptionsScreen(void) {
  // TODO: Update OPTIONS screen variables here!
}

// Options Screen Draw logic
void DrawOptionsScreen(void) {
  // TODO: Draw OPTIONS screen here!
}

// Options Screen Unload logic
void unload_options_screen(void) {
  // TODO: Unload OPTIONS screen variables here!
}

// Options Screen should finish?
int FinishOptionsScreen(void) { return finishScreen; }

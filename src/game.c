#include "raylib.h"
#include "screens.h" // NOTE: Declares global (extern) variables and screens functions

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

//----------------------------------------------------------------------------------
// Shared Variables Definition (global)
// NOTE: Those variables are shared between modules through screens.h
//----------------------------------------------------------------------------------
GameScreen current_screen = GAMEPLAY;
Font font = {0};
Music music = {0};
Sound fx_coin = {0};

//----------------------------------------------------------------------------------
// Local Variables Definition (local to this module)
//----------------------------------------------------------------------------------
static const int SCREEN_WIDTH = 800;
static const int SCREEN_HEIGHT = 450;

// Required variables to manage screen transitions (fade-in, fade-out)
static float trans_alpha = 0.0f;
static bool on_transition = false;
static bool trans_fade_out = false;
static int trans_from_screen = -1;
static GameScreen trans_to_screen = UNKNOWN;

//----------------------------------------------------------------------------------
// Local Functions Declaration
//----------------------------------------------------------------------------------
static void ChangeToScreen(int screen);     // Change to screen, no transition
static void TransitionToScreen(int screen); // Request transition to next screen
static void UpdateTransition(void);         // Update transition effect
static void DrawTransition(void);  // Draw transition effect (full-screen rect)
static void UpdateDrawFrame(void); // Update and draw one frame

//----------------------------------------------------------------------------------
// Main entry point
//----------------------------------------------------------------------------------
int main(void) {
  // Initialization
  //---------------------------------------------------------
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "hollie");

  InitAudioDevice(); // Initialize audio device

  // Load global data (assets that must be available in all screens, i.e. font)
  font = LoadFont("resources/mecha.png");
  music = LoadMusicStream("resources/ambient.ogg");
  fx_coin = LoadSound("resources/coin.wav");

  SetMusicVolume(music, 1.0f);
  /*PlayMusicStream(music);*/

  // Setup and init first screen
  current_screen = GAMEPLAY;
  init_gameplay_screen();

#if defined(PLATFORM_WEB)
  emscripten_set_main_loop(UpdateDrawFrame, 60, 1);
#else
  SetTargetFPS(60); // Set our game to run at 60 frames-per-second
  //--------------------------------------------------------------------------------------

  // Main game loop
  while (!WindowShouldClose()) // Detect window close button or ESC key
  {
    UpdateDrawFrame();
  }
#endif

  // De-Initialization
  //--------------------------------------------------------------------------------------
  // Unload current screen data before closing
  switch (current_screen) {
  case LOGO:
    UnloadLogoScreen();
    break;
  case TITLE:
    UnloadTitleScreen();
    break;
  case OPTIONS:
    UnloadOptionsScreen();
    break;
  case GAMEPLAY:
    unload_gameplay_screen();
    break;
  case ENDING:
    UnloadEndingScreen();
    break;
  default:
    break;
  }

  // Unload global data loaded
  UnloadFont(font);
  UnloadMusicStream(music);
  UnloadSound(fx_coin);

  CloseAudioDevice(); // Close audio context

  CloseWindow(); // Close window and OpenGL context
  //--------------------------------------------------------------------------------------

  return 0;
}

//----------------------------------------------------------------------------------
// Module specific Functions Definition
//----------------------------------------------------------------------------------
// Change to next screen, no transition
static void ChangeToScreen(GameScreen screen) {
  // Unload current screen
  switch (current_screen) {
  case LOGO:
    UnloadLogoScreen();
    break;
  case TITLE:
    UnloadTitleScreen();
    break;
  case OPTIONS:
    UnloadOptionsScreen();
    break;
  case GAMEPLAY:
    unload_gameplay_screen();
    break;
  case ENDING:
    UnloadEndingScreen();
    break;
  default:
    break;
  }

  // Init next screen
  switch (screen) {
  case LOGO:
    InitLogoScreen();
    break;
  case TITLE:
    InitTitleScreen();
    break;
  case OPTIONS:
    InitOptionsScreen();
    break;
  case GAMEPLAY:
    init_gameplay_screen();
    break;
  case ENDING:
    InitEndingScreen();
    break;
  default:
    break;
  }

  current_screen = screen;
}

// Request transition to next screen
static void TransitionToScreen(GameScreen screen) {
  on_transition = true;
  trans_fade_out = false;
  trans_from_screen = current_screen;
  trans_to_screen = screen;
  trans_alpha = 0.0f;
}

// Update transition effect (fade-in, fade-out)
static void UpdateTransition(void) {
  if (!trans_fade_out) {
    trans_alpha += 0.05f;

    // NOTE: Due to float internal representation, condition jumps on 1.0f
    // instead of 1.05f For that reason we compare against 1.01f, to avoid last
    // frame loading stop
    if (trans_alpha > 1.01f) {
      trans_alpha = 1.0f;

      // Unload current screen
      switch (trans_from_screen) {
      case LOGO:
        UnloadLogoScreen();
        break;
      case TITLE:
        UnloadTitleScreen();
        break;
      case OPTIONS:
        UnloadOptionsScreen();
        break;
      case GAMEPLAY:
        unload_gameplay_screen();
        break;
      case ENDING:
        UnloadEndingScreen();
        break;
      default:
        break;
      }

      // Load next screen
      switch (trans_to_screen) {
      case LOGO:
        InitLogoScreen();
        break;
      case TITLE:
        InitTitleScreen();
        break;
      case OPTIONS:
        InitOptionsScreen();
        break;
      case GAMEPLAY:
        init_gameplay_screen();
        break;
      case ENDING:
        InitEndingScreen();
        break;
      default:
        break;
      }

      current_screen = trans_to_screen;

      // Activate fade out effect to next loaded screen
      trans_fade_out = true;
    }
  } else // Transition fade out logic
  {
    trans_alpha -= 0.02f;

    if (trans_alpha < -0.01f) {
      trans_alpha = 0.0f;
      trans_fade_out = false;
      on_transition = false;
      trans_from_screen = -1;
      trans_to_screen = UNKNOWN;
    }
  }
}

// Draw transition effect (full-screen rectangle)
static void DrawTransition(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(),
                Fade(BLACK, trans_alpha));
}

// Update and draw game frame
static void UpdateDrawFrame(void) {
  // Update
  //----------------------------------------------------------------------------------
  UpdateMusicStream(music); // NOTE: Music keeps playing between screens

  if (!on_transition) {
    switch (current_screen) {
    case LOGO: {
      UpdateLogoScreen();

      if (FinishLogoScreen())
        TransitionToScreen(TITLE);

    } break;
    case TITLE: {
      UpdateTitleScreen();

      if (FinishTitleScreen() == 1)
        TransitionToScreen(OPTIONS);
      else if (FinishTitleScreen() == 2)
        TransitionToScreen(GAMEPLAY);

    } break;
    case OPTIONS: {
      UpdateOptionsScreen();

      if (FinishOptionsScreen())
        TransitionToScreen(TITLE);

    } break;
    case GAMEPLAY: {
      update_gameplay_screen();

      if (finish_gameplay_screen() == 1)
        TransitionToScreen(ENDING);
      // else if (FinishGameplayScreen() == 2) TransitionToScreen(TITLE);

    } break;
    case ENDING: {
      UpdateEndingScreen();

      if (FinishEndingScreen() == 1)
        TransitionToScreen(TITLE);

    } break;
    default:
      break;
    }
  } else
    UpdateTransition(); // Update transition (fade-in, fade-out)
  //----------------------------------------------------------------------------------

  // Draw
  //----------------------------------------------------------------------------------
  BeginDrawing();

  ClearBackground(RAYWHITE);

  switch (current_screen) {
  case LOGO:
    DrawLogoScreen();
    break;
  case TITLE:
    DrawTitleScreen();
    break;
  case OPTIONS:
    DrawOptionsScreen();
    break;
  case GAMEPLAY:
    draw_gameplay_screen();
    break;
  case ENDING:
    DrawEndingScreen();
    break;
  default:
    break;
  }

  // Draw full screen rectangle in front of everything
  if (on_transition)
    DrawTransition();

  DrawFPS(10, 10);

  EndDrawing();
  //----------------------------------------------------------------------------------
}

#include "raylib.h"
#include "screens.h" // NOTE: Declares global (extern) variables and screens functions

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

#define SCREEN_WIDTH 800
#define SCREEN_HEIGHT 450

// globals
GameScreen current_screen = GAMEPLAY;
Font font = {0};
Music music = {0};
Sound fx_coin = {0};

// screen transitions
static float trans_alpha = 0.0f;
static bool is_transitioning = false;
static bool trans_has_fade = false;
static GameScreen trans_from_screen = UNKNOWN;
static GameScreen trans_to_screen = UNKNOWN;

// local funcs
static void init();                           // Init current screen
static void change_to_screen(int screen);     // Change to screen, no transition
static void transition_to_screen(int screen); // Request transition to screen
static void draw_transition();                // Draw transition effect
static void update_transition();              // Update transition effect
static void update_draw_frame();              // Update and draw one frame

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
  PlayMusicStream(music);

  // Setup and init first screen
  init();

#if defined(PLATFORM_WEB)
  emscripten_set_main_loop(UpdateDrawFrame, 60, 1);
#else
  SetTargetFPS(60); // Set our game to run at 60 frames-per-second
  //--------------------------------------------------------------------------------------

  // Main game loop
  while (!WindowShouldClose()) // Detect window close button or ESC key
  {
    update_draw_frame();
  }
#endif

  // De-Initialization
  //--------------------------------------------------------------------------------------
  // Unload current screen data before closing
  switch (current_screen) {
  case LOGO:
    unload_logo_screen();
    break;
  case TITLE:
    unload_title_screen();
    break;
  case OPTIONS:
    unload_options_screen();
    break;
  case GAMEPLAY:
    unload_gameplay_screen();
    break;
  case ENDING:
    unload_ending_screen();
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
static void change_to_screen(GameScreen screen) {
  // Unload current screen
  switch (current_screen) {
  case LOGO:
    unload_logo_screen();
    break;
  case TITLE:
    unload_title_screen();
    break;
  case OPTIONS:
    unload_options_screen();
    break;
  case GAMEPLAY:
    unload_gameplay_screen();
    break;
  case ENDING:
    unload_ending_screen();
    break;
  default:
    break;
  }

  // Init next screen
  switch (screen) {
  case LOGO:
    init_logo_screen();
    break;
  case TITLE:
    init_title_screen();
    break;
  case OPTIONS:
    init_options_screen();
    break;
  case GAMEPLAY:
    init_gameplay_screen();
    break;
  case ENDING:
    init_ending_screen();
    break;
  default:
    break;
  }

  current_screen = screen;
}

// Request transition to next screen
static void transition_to_screen(GameScreen screen) {
  is_transitioning = true;
  trans_has_fade = false;
  trans_from_screen = current_screen;
  trans_to_screen = screen;
  trans_alpha = 0.0f;
}

// Update transition effect (fade-in, fade-out)
static void update_transition(void) {
  if (!trans_has_fade) {
    trans_alpha += 0.05f;

    // NOTE: Due to float internal representation, condition jumps on 1.0f
    // instead of 1.05f For that reason we compare against 1.01f, to avoid last
    // frame loading stop
    if (trans_alpha > 1.01f) {
      trans_alpha = 1.0f;

      // Unload current screen
      switch (trans_from_screen) {
      case LOGO:
        unload_logo_screen();
        break;
      case TITLE:
        unload_title_screen();
        break;
      case OPTIONS:
        unload_options_screen();
        break;
      case GAMEPLAY:
        unload_gameplay_screen();
        break;
      case ENDING:
        unload_ending_screen();
        break;
      default:
        break;
      }

      // Load next screen
      switch (trans_to_screen) {
      case LOGO:
        init_logo_screen();
        break;
      case TITLE:
        init_title_screen();
        break;
      case OPTIONS:
        init_options_screen();
        break;
      case GAMEPLAY:
        init_gameplay_screen();
        break;
      case ENDING:
        init_ending_screen();
        break;
      default:
        break;
      }

      current_screen = trans_to_screen;

      // Activate fade out effect to next loaded screen
      trans_has_fade = true;
    }
  } else // Transition fade out logic
  {
    trans_alpha -= 0.02f;

    if (trans_alpha < -0.01f) {
      trans_alpha = 0.0f;
      trans_has_fade = false;
      is_transitioning = false;
      trans_from_screen = -1;
      trans_to_screen = UNKNOWN;
    }
  }
}

static void init() {
  switch (current_screen) {
  case GAMEPLAY:
    init_gameplay_screen();
    break;
  case LOGO:
    init_logo_screen();
    break;
  case TITLE:
    init_title_screen();
    break;
  case OPTIONS:
    init_options_screen();
    break;
  case ENDING:
    init_ending_screen();
    break;
  case UNKNOWN:
    break;
  }
}

// Draw transition effect (full-screen rectangle)
static void draw_transition(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(),
                Fade(BLACK, trans_alpha));
}

// Update and draw game frame
static void update_draw_frame(void) {
  // Update
  //----------------------------------------------------------------------------------
  UpdateMusicStream(music); // NOTE: Music keeps playing between screens

  if (!is_transitioning) {
    switch (current_screen) {
    case LOGO: {
      UpdateLogoScreen();

      if (FinishLogoScreen())
        transition_to_screen(TITLE);

    } break;
    case TITLE: {
      UpdateTitleScreen();

      if (FinishTitleScreen() == 1)
        transition_to_screen(OPTIONS);
      else if (FinishTitleScreen() == 2)
        transition_to_screen(GAMEPLAY);

    } break;
    case OPTIONS: {
      UpdateOptionsScreen();

      if (FinishOptionsScreen())
        transition_to_screen(TITLE);

    } break;
    case GAMEPLAY: {
      update_gameplay_screen();

      if (finish_gameplay_screen() == 1)
        transition_to_screen(ENDING);
      // else if (FinishGameplayScreen() == 2) TransitionToScreen(TITLE);

    } break;
    case ENDING: {
      UpdateEndingScreen();

      if (FinishEndingScreen() == 1)
        transition_to_screen(TITLE);

    } break;
    default:
      break;
    }
  } else
    update_transition(); // Update transition (fade-in, fade-out)
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
  if (is_transitioning)
    draw_transition();

  DrawFPS(10, 10);

  EndDrawing();
  //----------------------------------------------------------------------------------
}

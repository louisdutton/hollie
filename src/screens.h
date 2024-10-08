#ifndef SCREENS_H
#define SCREENS_H

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
#include "raylib.h"
typedef enum GameScreen {
  UNKNOWN = -1,
  LOGO = 0,
  TITLE,
  OPTIONS,
  GAMEPLAY,
  ENDING
} GameScreen;

//----------------------------------------------------------------------------------
// Global Variables Declaration (shared by several modules)
//----------------------------------------------------------------------------------
extern GameScreen current_screen;
extern Font font;
extern Music music;
extern Sound fx_coin;

#ifdef __cplusplus
extern "C" { // Prevents name mangling of functions
#endif

//----------------------------------------------------------------------------------
// Logo Screen Functions Declaration
//----------------------------------------------------------------------------------
void init_logo_screen(void);
void UpdateLogoScreen(void);
void DrawLogoScreen(void);
void unload_logo_screen(void);
int FinishLogoScreen(void);

//----------------------------------------------------------------------------------
// Title Screen Functions Declaration
//----------------------------------------------------------------------------------
void init_title_screen(void);
void UpdateTitleScreen(void);
void DrawTitleScreen(void);
void unload_title_screen(void);
int FinishTitleScreen(void);

//----------------------------------------------------------------------------------
// Options Screen Functions Declaration
//----------------------------------------------------------------------------------
void init_options_screen(void);
void UpdateOptionsScreen(void);
void DrawOptionsScreen(void);
void unload_options_screen(void);
int FinishOptionsScreen(void);

//----------------------------------------------------------------------------------
// Gameplay Screen Functions Declaration
//----------------------------------------------------------------------------------
void init_gameplay_screen(void);
void update_gameplay_screen(void);
void draw_gameplay_screen(void);
void unload_gameplay_screen(void);
int finish_gameplay_screen(void);

//----------------------------------------------------------------------------------
// Ending Screen Functions Declaration
//----------------------------------------------------------------------------------
void init_ending_screen(void);
void UpdateEndingScreen(void);
void DrawEndingScreen(void);
void unload_ending_screen(void);
int FinishEndingScreen(void);

#ifdef __cplusplus
}
#endif

#endif // SCREENS_H

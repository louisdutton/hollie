#include "raylib.h"

static const Color BG_COLOUR = PURPLE;
static const int MOVE_SPEED = 2;

static bool isPaused = false;
static int x = 0;
static int y = 0;
static int width = 20;
static int height = 20;

static Texture2D player_sprite = {0};
static Color player_colour = WHITE;
static float player_rotation;
static Rectangle frame = {0, 0, 16, 16};
static Rectangle destination = {0, 0, 16, 16};
static Vector2 origin = {0, 0};

// Gameplay Screen Initialization logic
void InitGameplayScreen(void) {
  player_sprite =
      LoadTexture("resources/characters/human/idle/base_idle_strip9.png");
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

  // player
  DrawRectangleLines(x, y, width, height, WHITE);
  DrawTexturePro(player_sprite, frame, destination, origin, player_rotation,
                 player_colour);

  if (isPaused) {
    DrawText("PAUSED", 130, 220, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void UnloadGameplayScreen(void) { UnloadTexture(player_sprite); }

// Gameplay Screen should finish?
int FinishGameplayScreen(void) { return false; }

#include "raylib.h"

// anim
#define TARGET_FPS 60
#define FPS 24
#define INTERVAL TARGET_FPS / FPS
#define FRAME_WIDTH 96
#define FRAME_HEIGHT 64
#define ANIM_COUNT 3

// player
#define MOVE_SPEED 2

typedef enum Animations {
  IDLE,
  RUN,
  JUMP,
} Animations;

// player
static int width = 20;
static int height = 20;
static Vector2 position = {0, 0};
static Vector2 velocity = {0, 0};
static Color player_colour = WHITE;
static Rectangle rect = {0, 0, FRAME_WIDTH, FRAME_HEIGHT};

static Texture2D animations[ANIM_COUNT] = {0};
static const int frame_counts[ANIM_COUNT] = {9, 8, 9};
static int frame_counter = 0;
static int frame = 0;
static int current_anim = 0;

static bool is_paused = false;

// Gameplay Screen Initialization logic
void InitGameplayScreen(void) {
  position.x = (float)GetScreenWidth() / 2;
  position.y = (float)GetScreenHeight() / 2;
  animations[0] =
      LoadTexture("resources/characters/human/idle/base_idle_strip9.png");
  animations[1] =
      LoadTexture("resources/characters/human/run/base_run_strip8.png");
  animations[2] =
      LoadTexture("resources/characters/human/jump/base_jump_strip9.png");
}

// Gameplay Screen Update logic
void UpdateGameplayScreen(void) {
  // input
  if (IsKeyPressed(KEY_P))
    is_paused = !is_paused;

  // calculate velocity
  if (!is_paused) {
    velocity.x = (IsKeyDown(KEY_D) - IsKeyDown(KEY_A)) * MOVE_SPEED;
    velocity.y = (IsKeyDown(KEY_S) - IsKeyDown(KEY_W)) * MOVE_SPEED;
  }

  // apply velocity
  position.x += velocity.x;
  position.y += velocity.y;

  // choose anim
  if (velocity.x != 0 || velocity.y != 0) {
    current_anim = 1;
  } else {
    current_anim = 0;
  }

  // anim
  frame_counter++;

  if (frame_counter > INTERVAL) {
    frame_counter = 0;
    frame++;
    if (frame > frame_counts[current_anim])
      frame = 0;
    rect.x = (float)frame * (float)FRAME_WIDTH;
  }
}

// Gameplay Screen Draw logic
void DrawGameplayScreen(void) {
  DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), BLUE);

  // player
  DrawRectangleLines(position.x - (float)width / 2,
                     position.y - (float)height / 2, width, height, WHITE);
  Vector2 tex_pos = position;
  tex_pos.x -= (float)FRAME_WIDTH / 2;
  tex_pos.y -= (float)FRAME_HEIGHT / 2;
  DrawTextureRec(animations[current_anim], rect, tex_pos, player_colour);

  if (is_paused) {
    DrawText("PAUSED", 130, 220, 20, WHITE);
  }
}

// Gameplay Screen Unload logic
void UnloadGameplayScreen(void) {
  for (int i = 0; i < ANIM_COUNT; i++) {
    UnloadTexture(animations[i]);
  }
}

// Gameplay Screen should finish?
int FinishGameplayScreen(void) { return 0; }

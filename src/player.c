#include "raylib.h"
#include "raymath.h"

// player
#define MOVE_SPEED 2

// anim
#define TARGET_FPS 60
#define FPS 24
#define INTERVAL TARGET_FPS / FPS
#define FRAME_WIDTH 96
#define FRAME_HEIGHT 64
#define ANIM_COUNT 3

typedef enum Animations {
  IDLE,
  RUN,
  JUMP,
} Animations;

// player
static int width = 20;
static int height = 20;
Vector2 position = {0, 0};
static Vector2 velocity = {0, 0};
static Color player_colour = WHITE;
static Rectangle rect = {0, 0, FRAME_WIDTH, FRAME_HEIGHT};

// anim
static Texture2D animations[ANIM_COUNT] = {0};
static const int frame_counts[ANIM_COUNT] = {9, 8, 9};
static int frame_counter = 0;
static int frame = 0;
static int current_anim = 0;
static bool is_flipped = false;

void CalculateVelocity() {
  Vector2 input = {(IsKeyDown(KEY_D) - IsKeyDown(KEY_A)),
                   (IsKeyDown(KEY_S) - IsKeyDown(KEY_W))};
  input = Vector2Normalize(input);
  velocity.x = input.x * MOVE_SPEED;
  velocity.y = input.y * MOVE_SPEED;
}

void CalculateState() {
  if (velocity.x != 0 || velocity.y != 0) {
    current_anim = 1;
    is_flipped = velocity.x < 0;
  } else {
    current_anim = 0;
  }
}

void MoveAndCollide() {
  position.x += velocity.x;
  position.y += velocity.y;
}

void Animate() {
  frame_counter++;

  if (frame_counter > INTERVAL) {
    frame_counter = 0;
    frame++;
    if (frame > frame_counts[current_anim])
      frame = 0;
    rect.x = (float)frame * (float)FRAME_WIDTH;
  }
}

void InitPlayer() {
  animations[0] =
      LoadTexture("resources/characters/human/idle/base_idle_strip9.png");
  animations[1] =
      LoadTexture("resources/characters/human/run/base_run_strip8.png");
  animations[2] =
      LoadTexture("resources/characters/human/jump/base_jump_strip9.png");
}

void UpdatePlayer() {
  CalculateVelocity();
  CalculateState();
  MoveAndCollide();
  Animate();
}

void DrawPlayer() {
  DrawRectangleLines(position.x - (float)width / 2,
                     position.y - (float)height / 2, width, height, WHITE);
  Vector2 tex_pos = position;
  tex_pos.x -= (float)FRAME_WIDTH / 2;
  tex_pos.y -= (float)FRAME_HEIGHT / 2;
  Rectangle tex_rect = rect;
  if (is_flipped) {
    tex_rect.width *= -1;
  }
  DrawTextureRec(animations[current_anim], tex_rect, tex_pos, player_colour);
}

void UnloadPlayer() {
  for (int i = 0; i < ANIM_COUNT; i++) {
    UnloadTexture(animations[i]);
  }
}

#include "player.h"
#include "raylib.h"

// camera
Camera2D camera = {.zoom = 2};

static void camera_follow_target() {
  camera.target.x = position.x - (float)GetScreenWidth() / 2 / camera.zoom;
  camera.target.y = position.y - (float)GetScreenHeight() / 2 / camera.zoom;
}

void init_camera() { camera_follow_target(); }

void update_camera() { camera_follow_target(); }

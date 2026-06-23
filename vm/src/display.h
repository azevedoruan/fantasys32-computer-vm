#pragma once
#include <SDL2/SDL.h>
#include <stdlib.h>

#define W_WIDTH 320
#define W_HEIGHT 240
#define FPS 60
#define FRAME_TIME (1000 / FPS)

class Display {
   private:
    SDL_Window* window;
    SDL_Renderer* render;
    SDL_Texture* texture;
    int width;
    int height;

    Display(int scale_factor);
    bool init();
    void update(uint32_t* buffer);
    void clean();
    ~Display();
};
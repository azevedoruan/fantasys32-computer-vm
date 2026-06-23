#include "display.h"

Display::Display(int scale_factor) {
    width = W_WIDTH * scale_factor;
    height = W_HEIGHT * scale_factor;
}

bool Display::init(const char* name) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        return false;
    }

    window = SDL_CreateWindow(
        name,
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        width,
        height,
        SDL_WINDOW_SHOWN);

    if (!window) {
        return false;
    }

    render = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!render) {
        return false;
    }

    // Criar uma textura para o framebuffer
    // A textura é criada com o formato ARGB8888 e acesso de streaming,
    //    o que nos permite atualizar os pixels diretamente.
    // Note que o formato ARGB8888 é o mesmo que usamos para o framebuffer,
    //    garantindo compatibilidade.
    texture = SDL_CreateTexture(
        render,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        width,
        height);

    if (!texture) {
        return false;
    }
}

void Display::update(uint32_t* buffer) {
    SDL_UpdateTexture(texture, NULL, buffer, width * sizeof(uint32_t));
    SDL_RenderCopy(render, texture, NULL, NULL);
    SDL_RenderPresent(render);
}

void Display::clean() {
    SDL_DestroyWindow(window);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(render);
    SDL_Quit();
}
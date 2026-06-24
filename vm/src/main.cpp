#include <argparse/argparse.hpp>
#include <filesystem>

#include "display.h"
#include "vm.h"

// Executa 10⁴ instruções por segundo.
#define INSTR_PER_SEC 10000

uint32_t setKeyDown(SDL_Keysym keysym);
uint32_t setKeyUp(SDL_Keysym keysym);
bool sleepInstructions(VirtualMachine* vm);

int main(int argc, char* argv[]) {
    argparse::ArgumentParser parser("Fantasys32 VM", "1.0");
    int verbosity = 0;
    int scale = 1;
    bool syscall_active = false;

    parser.add_argument("arquivo_jogo")
        .help("Caminho do arquivo binário do jogo para rodar.");

    parser.add_argument("scale")
        .help("Define o fator de escala da janela. Um fator de 2 resulta em uma janela de 640x480. Padrão: 1.")
        .scan<'i', int>();

    parser.add_argument("--no-syscall")
        .help("Desativa a execução da instrução SYSCALL, fazendo com que a VM ignore essa instrução.")
        .flag();

    parser.add_argument("-V", "--verbose")
        .help("Nível de debuging durante a execução da VM.")
        .action([&](const auto&) { ++verbosity; })
        .append()
        .default_value(false)
        .implicit_value(true)
        .nargs(0);

    try {
        parser.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << parser << std::endl;
        std::exit(1);
    }

    std::string file_path = parser.get<std::string>("arquivo_jogo");
    scale = parser.get<int>("scale");
    if (parser["--no-syscall"] == true) {
        syscall_active = true;
    }
    std::cout << "Opening file: " << file_path << std::endl;
    std::cout << "verbose level: " << verbosity << std::endl;
    std::cout << "Scale factor: " << scale << std::endl;
    std::cout << "Syscall: " << syscall_active << std::endl;

    if (!std::filesystem::exists(file_path)) {
        std::cerr << "Arquivo não existe." << std::endl;
        return -1;
    }

    if (std::filesystem::file_size(file_path) > TAM_MEM) {
        std::cerr << "Arquivo muito grande! O tamanho máximo para o arquivo de entrada é de 16MB." << std::endl;
        return -1;
    }

    Display* display = new Display(scale);
    if (!display->init("Fantasys32 VM")) {
        return -1;
    }
    VirtualMachine* vm = new VirtualMachine(file_path.c_str(), verbosity, W_WIDTH, W_HEIGHT, scale);

    bool running = true;
    SDL_Event e;

    while (running) {
        Uint64 start_frame = SDL_GetTicks64();
        vm->frame_count += 1;

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                running = false;
            }

            if (e.type == SDL_KEYDOWN) {
                vm->input_state |= setKeyDown(e.key.keysym);
                std::cout << "Pressionando" << vm->input_state << std::endl;
            }

            if (e.type == SDL_KEYUP) {
                vm->input_state &= ~setKeyUp(e.key.keysym);
                std::cout << "soltado" << vm->input_state << std::endl;
            }
        }

        if (!sleepInstructions(vm)) {
            for (int i = 0; i < 100; i++) {
                vm->executeInstruction(&running);
            }
        }

        display->update(vm->getBuffer());

        // FPS Handler (limit in 60)
        Uint64 delta_frame = SDL_GetTicks64() - start_frame;
        if (delta_frame < FRAME_TIME) {
            SDL_Delay(FRAME_TIME - delta_frame);
        }
    }

    display->clean();

    return 0;
}

bool sleepInstructions(VirtualMachine* vm) {
    if (vm->sleep_ms > 0) {
        vm->sleep_ms -= FRAME_TIME;
        if (vm->sleep_ms <= 0) {
            vm->sleep_ms = 0;
        }
        return true;
    }
    return false;
}

uint32_t setKeyDown(SDL_Keysym keysym) {
    switch (keysym.sym) {
        case SDLK_LEFT:     return 1 << 0;
        case SDLK_RIGHT:    return 1 << 1;
        case SDLK_UP:       return 1 << 2;
        case SDLK_DOWN:     return 1 << 3;
        case SDLK_SPACE:    return 1 << 4;
        case SDLK_KP_ENTER: return 1 << 5;
        case SDLK_n:        return 1 << 6;
        case SDLK_m:        return 1 << 7;
        case SDLK_a:        return 1 << 8;
        case SDLK_s:        return 1 << 9;
        case SDLK_d:        return 1 << 10;
        case SDLK_w:        return 1 << 11;
        case SDLK_q:        return 1 << 12;
        case SDLK_e:        return 1 << 13;
        case SDLK_c:        return 1 << 14;
        case SDLK_v:        return 1 << 15;
        default:            return 0;
    }
}

uint32_t setKeyUp(SDL_Keysym keysym) {
    switch (keysym.sym) {
        case SDLK_LEFT:     return 1 << 0;
        case SDLK_RIGHT:    return 1 << 1;
        case SDLK_UP:       return 1 << 2;
        case SDLK_DOWN:     return 1 << 3;
        case SDLK_SPACE:    return 1 << 4;
        case SDLK_KP_ENTER: return 1 << 5;
        case SDLK_n:        return 1 << 6;
        case SDLK_m:        return 1 << 7;
        case SDLK_a:        return 1 << 8;
        case SDLK_s:        return 1 << 9;
        case SDLK_d:        return 1 << 10;
        case SDLK_w:        return 1 << 11;
        case SDLK_q:        return 1 << 12;
        case SDLK_e:        return 1 << 13;
        case SDLK_c:        return 1 << 14;
        case SDLK_v:        return 1 << 15;
        default:            return 0;
    }
}
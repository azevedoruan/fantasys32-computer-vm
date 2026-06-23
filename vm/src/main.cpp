#include <argparse/argparse.hpp>
#include <filesystem>

#include "display.h"
#include "vm.h"

// Executa 10⁴ instruções por segundo.
#define INSTR_PER_SEC 10000

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
    VirtualMachine* vm = new VirtualMachine(file_path.c_str(), verbosity);

    bool running = true;
    SDL_Event e;

    while (running) {
        Uint64 start_frame = SDL_GetTicks64();

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                running = false;
            }

            if (e.type == SDL_KEYDOWN) {
                // TODO set inputs
            }

            if (e.type == SDL_KEYUP) {
                // TODO set input up
            }
        }

        for (int i = 0; i < INSTR_PER_SEC; i++) {
            vm->executeInstruction();
        }

        display->update(vm->getBuffer());

        // FPS Handler
        Uint64 delta_frame = SDL_GetTicks64() - start_frame;
        if (delta_frame < FRAME_TIME) {
            SDL_Delay(delta_frame - FRAME_TIME);
        }
    }

    return 0;
}
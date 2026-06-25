all:
	g++ -c vm/src/vm.cpp -o vm/bin/vm.o 
	g++ -c vm/src/display.cpp -o vm/bin/display.o
	g++ vm/src/main.cpp vm/bin/vm.o vm/bin/display.o -o fantasy -lSDL2


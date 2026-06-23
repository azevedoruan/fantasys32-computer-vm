all:
	g++ -c src/vm.cpp -o bin/vm.o 
	g++ -c src/display.cpp -o bin/display.o
	g++ src/main.cpp bin/vm.o bin/display.o -o vm -lSDL2


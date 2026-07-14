#include "syli/syli_state.h"

extern int syli_startup_program (int argc, char **argv);

int main(int argc, char **argv) {
    syli_state_init();
    return syli_startup_program(argc, argv);
}

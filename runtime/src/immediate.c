#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include "syli/immediate.h"

void syli_print_i64(int64_t value) {
    printf("%" PRId64, value);
}

void syli_print_f64(double value) {
    printf("%f", value);
}

void syli_print_str(SyliStr s) {
    fwrite(s.ptr, 1, s.len, stdout);
}

void syli_print_char(char value) {
    fputc(value, stdout);
}

#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>

void syli_print_i64(int64_t value) {
    printf("%" PRId64, value);
}

void syli_print_f64(double value) {
    printf("%f", value);
}

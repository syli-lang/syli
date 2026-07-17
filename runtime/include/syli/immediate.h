#ifndef IMMEDIATE_H
#define IMMEDIATE_H

#include <stdint.h>

void syli_print_i64(int64_t value);
void syli_print_f64(double value);
typedef struct { const char* ptr; int64_t len; } SyliStr;
void syli_print_str(SyliStr s);
void syli_print_char(char value);

#endif // IMMEDIATE_H

#ifndef CONFIG_H
#define CONFIG_H

#define SYLI_WORD_SIZE            8
#define SYLI_WORD_BITS            64
#define SYLI_STACK_FRAME_CAPACITY 1024
#define SYLI_BUMP_ZONE_SIZE_WORDS (512 * 1024 / 8) // 512 KB
#define BUDGET_BATCH_SIZE         1000

#endif // CONFIG_H
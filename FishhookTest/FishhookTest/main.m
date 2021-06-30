//
//  main.m
//  FishhookTest
//

#include <stdio.h>
#include <stdarg.h>
#include "fishhook.h"

static int (*ori_printf)(const char *, ...);

int yzk_printf(const char *format, ...)
{
    int ret = 0;
    ori_printf("yzk print before\n");
    va_list arg;
    va_start(arg, format);
    ret = vprintf(format, arg);
    va_end(arg);
    ori_printf("yzk print after\n");
    return ret;
}

int main(void)
{
    // rebind `printf` 符号，让它指向到自定义的 `yzk_printf` 函数
    struct rebinding printf_rebinding = { "printf", yzk_printf, (void *)&ori_printf };
    rebind_symbols((struct rebinding[1]){printf_rebinding}, 1);
    
    // 调用 `printf`，实际执行的逻辑是 `god_printf` 定义的逻辑
    printf("aaa bbb test %d\n", 42);
    return 0;
}

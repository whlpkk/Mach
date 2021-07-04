#include <stdio.h>

char *kHelloPrefix = "Hello";

void say(char *prefix, char *name)
{
    printf("%s, %s\n", prefix, name);
}


void say2(char *prefix, char *name)
{
    printf("--== %s, %s\n", prefix, name);
}

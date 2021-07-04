void say(char *prefix, char *name);
void say2(char *prefix, char *name);
extern char *kHelloPrefix;

int main(void)
{
    say(kHelloPrefix, "Jack");
    say2(kHelloPrefix, "Jack2");
    return 0;
}

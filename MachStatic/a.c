//
//  a.c
//  MachT
//
//  Created by yzkmac on 2019/10/31.
//  Copyright © 2019 yzkmac. All rights reserved.
//

#include <stdio.h>

extern int shared;
extern void swap(int *a, int *b);

int main() {
    int a = 100;
    swap(&a, &shared);
    return 0;
}

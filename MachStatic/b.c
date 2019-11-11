//
//  b.c
//  MachT
//
//  Created by yzkmac on 2019/10/31.
//  Copyright © 2019 yzkmac. All rights reserved.
//

#include <stdio.h>

int shared = 42;
void swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

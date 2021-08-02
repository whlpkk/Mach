//
//  Target.m
//  targetStaticSource
//


#import "Target.h"
#import "DependencyStaticLibrary.h"
#import <dependencyStaticFramework/DependencyStatic.h>
#import <dependencyDynamicFramework/DependencyDynamic.h>

@implementation Target

- (instancetype)init
{
    self = [super init];
    if (self) {
        DependencyStaticLibrary *l = [[DependencyStaticLibrary alloc] init];
        DependencyStatic *s = [[DependencyStatic alloc] init];
        DependencyDynamic *d = [[DependencyDynamic alloc] init];
    }
    return self;
}

@end

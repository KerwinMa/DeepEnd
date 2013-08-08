#import "DeepEnd.h"

BOOL DESIsDebugBuild(void) {
#ifdef DES_DEBUG
    return YES;
#else
    return NO;
#endif
}
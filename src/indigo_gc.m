//
//  indigo_gc.m
//  indigo
//
//  Created by zhang on 11/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_gc.h"

#if !__has_feature(objc_arc)
#error "this file must be compiled with ARC"
#endif

#if INDIGO_RIGOROUS_GC

#define INDIGO_GC_INTERVAL 2
extern void dispose_instance(void *instance);

@implementation indigo_gc

static dispatch_queue_t queue;
static dispatch_source_t timer;
static NSMapTable *table = nil;
static NSMutableArray *keys = nil;
+ (void)start
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("indigo_gc_queue", NULL);
        table = [NSMapTable weakToWeakObjectsMapTable];
        keys = [NSMutableArray array];
    });
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, INDIGO_GC_INTERVAL * NSEC_PER_SEC, INDIGO_GC_INTERVAL * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
//        CFAbsoluteTime begin = CFAbsoluteTimeGetCurrent();
        NSMutableIndexSet *keysToRemoved = [NSMutableIndexSet indexSet];
        [keys enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![table objectForKey:obj]) {
                printf("[indigo_gc] collect object: %p\n", obj.pointerValue);
                dispose_instance((__bridge void *)obj);
            }
            [keysToRemoved addIndex:idx];
        }];
        
        [keys removeObjectsAtIndexes:keysToRemoved];
//        NSLog(@"[indigo_gc] cost time: %f", CFAbsoluteTimeGetCurrent() - begin);
    });
    dispatch_resume(timer);
        
    printf("[indigo_gc] ready to serve you.\n");
}

+ (void)stop
{
    dispatch_suspend(timer);
    timer = nil;
    [table removeAllObjects];
    table = nil;
    [keys removeAllObjects];
    keys = nil;
}

+ (void)addObject:(id)obj
{
    __typeof(obj) __weak weakObj = obj;
    dispatch_async(queue, ^{
        __typeof(obj) strongObj = weakObj;
        if (!strongObj) {
            printf("[indigo_gc] object was already released\n");
            return;
        }
        
        if (!table) {
            printf("[indigo_gc] not started\n");
        }
        else {
            NSValue *key = [NSValue valueWithPointer:(__bridge void *)strongObj];
            if ([table objectForKey:key] == NULL) {
//                NSLog(@"[indigo_gc] add object: %p table.count: %lu", (__bridge void *)strongObj, (unsigned long)table.count);
                [table setObject:strongObj forKey:key];
                [keys addObject:key];
            }
            else {
//                NSLog(@"[indigo_gc] object already in: %p", (__bridge void *)strongObj);
            }
        }
    });
}
@end

#endif

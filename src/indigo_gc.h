//
//  indigo_gc.h
//  indigo
//
//  Created by zhang on 11/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 I provide two ways of lua userdata collection.
 
 1) Don't do manual collection. Let lua engine collect these userdata. And don't
    cache objc objects. Everytime we need to wrap an oc object, we create a new
    userdata. This is fine because lua objects are actually verty small. Its only
    drawback is `no-cache`, thus makes the app run a bit slower. I prefer this one.
 
 2) Do strict gabbage collection. Keep userdata in registry(thus caching it). When
    it will no longer used by objc runtime(it was dealloced), put it into an array and
    collect it from lua engine at sometime later.
    The benefits of this strategy are that your memory footprint is small, and your 
    app runs a bit(not much) faster.
    The bad side is that schedule a periodic timer and dispach the releasing job to
    main queue is time-consuming.
 
    Note that the gabbage collection I mentioned here is only for lua userdata. OC objects
    will managed by OC runtime. You don't need to worry about it.
 
    Open `INDIGO_RIGOROUS_GC` macro to use the second type of gabbage collection.
 */
#define INDIGO_RIGOROUS_GC 0

#if INDIGO_RIGOROUS_GC
@interface indigo_gc : NSObject
+ (void)start;
+ (void)stop;
+ (void)addObject:(id)obj;
@end
#endif
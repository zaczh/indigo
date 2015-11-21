//
//  indigo.h
//  indigo
//
//  Created by zhang on 7/26/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <stdio.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"


@interface IndigoEngine : NSObject

+ (instancetype)sharedEngine;

- (int)runScriptAtPath:(NSString *)filePath;
@end

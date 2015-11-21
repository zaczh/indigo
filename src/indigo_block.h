//
//  indigo_block.h
//  indigo
//
//  Created by zhang on 8/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "lua.h"

void *toBlock(lua_State *s, int functionIndex, void *owner);

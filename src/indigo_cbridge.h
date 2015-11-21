//
//  indigo_cbridge.h
//  indigo
//
//  Created by zhang on 11/8/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "lua.h"

/* Bridge for cocoa c functions */

int luaopen_indigo_cbridge(lua_State *s);

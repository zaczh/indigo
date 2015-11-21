//
//  indigo_class.h
//  indigo
//
//  Created by zhang on 8/2/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

typedef struct {
    Class cls;
    Class superCls;
    bool isInClassMethodContext;
    bool isInCategoryContext;
}IndigoClassStruct;

int luaopen_indigo_class(lua_State *s);

IndigoClassStruct *indigo_check_class_userdata(lua_State *s, int index);

//this method makes sure that only one userdata exist for one class-method pair
IndigoClassStruct *indigo_pushClassUserdata(lua_State *s, Class cls, bool isClassMethodContext, bool isInCategoryContext);

//this method must be called on main thread!!!
void bindMainLuaThread(lua_State *s);

lua_State *luaThread();

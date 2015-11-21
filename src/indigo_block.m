//
//  indigo_block.m
//  indigo
//
//  Created by zhang on 8/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_block.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <objc/runtime.h>

#import "indigo_class.h"
#import "indigo_helper.h"
#import "indigo_object.h"

extern void push_object(lua_State *s, void *buffer, const char *type, bool isDeallocing);

/*
 I simplified the block syntax so that we don't need to pass in a block parameter type(such as "B:@dd"),
 but after doing this, we need to manully convert the argument to target type, because in the block we
 have no way to figure out the type. I provide `asInoutBool`, `asInt`, `asDouble` to convert them.
 */
void *toBlock(lua_State *s, int functionIndex, void *owner)
{
    lua_pushvalue(s, functionIndex);
    int funcRef = luaL_ref(s, LUA_REGISTRYINDEX);
    
    closure_capture_arguments_owner(s, functionIndex, (id)owner);
    
    
    /*
     WARN: This is a bad trick. If the size of an argument is bigger than `void *`(such as `long long`), it will be
     truncated.
     */
    typedef int (^indigo_int_block) (void *arg1, void *arg2, void *arg3, void *arg4, void *arg5);
    indigo_int_block block =  [[^int(void *arg1, void *arg2, void *arg3, void *arg4, void *arg5) {
        
        lua_State *s = luaThread();
        assert(s);
        
        lua_rawgeti(s, LUA_REGISTRYINDEX, funcRef);
        assert(lua_isfunction(s, -1));
        
        /*
         Using debug API to get the function info
         This API is only available in lua version >= 5.2
         */
        lua_pushvalue(s, -1);
        lua_Debug ar;
        lua_getinfo(s, ">u", &ar);
        
        int nargs = ar.nparams;
        
        for (int i=1; i<=nargs; ++i) {
            switch (i) {
                case 1:
                    push_object(s, &arg1, "%", false);//use "%" as indigo unknown type
                    break;
                case 2:
                    push_object(s, &arg2, "%", false);
                    break;
                case 3:
                    push_object(s, &arg3, "%", false);
                    break;
                case 4:
                    push_object(s, &arg4, "%", false);
                    break;
                case 5:
                    push_object(s, &arg5, "%", false);
                    break;
                    
                default:
                    printf("your block have too many arguments, add more arguments to this block(indigo_BOOL_block)\n");
                    abort();
                    break;
            }
        }
        
        if (LUA_OK != lua_pcall(s, nargs, 1, 0)) {
            luaL_error(s, lua_tostring(s, -1));
        }
        
        //get result
        
        int r = 0;
        if (lua_isnumber(s, -1)) {
            r = (int)lua_tointeger(s, -1);
        }
        else if (lua_isboolean(s, -1)) {
            r = lua_toboolean(s, -1);
        }
        
        lua_pop(s, 1);
        
        return r;
    } copy] autorelease];
    
    return block;
}

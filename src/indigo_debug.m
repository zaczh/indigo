//
//  indigo_debug.m
//  indigo
//
//  Created by zhang on 7/26/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_debug.h"
#import "indigo_class.h"
#import "indigo_object.h"

#define LOG_LUA_PRINT

#define INDIGO_DEBUG_METATABLE "indigo.debug"

extern lua_State *luaThread();
int luaopen_indigo_debug(lua_State *L)
{
    luaL_newmetatable(L, INDIGO_DEBUG_METATABLE);
    
    //set globals
    lua_pushcfunction(L, luaPrint);
    lua_setglobal(L, "print");
    
    lua_pushcfunction(L, probe);
    lua_setglobal(L, "probe");
    
    return 1;
}

static NSString *printStackAt(lua_State *L, int i)
{
    NSMutableString *info = [NSMutableString string];
    int t = lua_type(L, i);
    [info appendFormat:@"(%s) ", lua_typename(L, t)];
    
    switch (t) {
        case LUA_TSTRING:
            [info appendFormat:@"'%s'", lua_tostring(L, i)];
            break;
        case LUA_TBOOLEAN:
            [info appendString:lua_toboolean(L, i) ? @"true" : @"false"];
            break;
        case LUA_TNUMBER:
            [info appendFormat:@"'%g'", lua_tonumber(L, i)];
            break;
        default:
            [info appendFormat:@"%p", lua_topointer(L, i)];
            break;
    }
    [info appendString:@"\n"];
    
    return info;
}

NSString *stackInfo()
{
    NSMutableString *info = [NSMutableString stringWithFormat:@"lua stack info of current thread: %@\n", [NSThread currentThread].description];
    @autoreleasepool {
        lua_State *L = luaThread();
        int top = lua_gettop(L);
        if (top<1) {
            [info appendString:@"[empty]"];
        }
        else {
            for (int i = 1; i <= top; i++) {
                [info appendFormat:@"%d: ", i];
                [info appendString:printStackAt(L, i)];
            }
        }
    }
    
    return info;
}


NSString *tableInfo(lua_State *s, int tableIndex)
{
    NSMutableString *info = [NSMutableString string];
    @autoreleasepool {
        if (!lua_istable(s, tableIndex)) {
            [info appendString:@"error: item at specified index is not a table!"];
        }
        else {
            size_t len = lua_rawlen(s, tableIndex);
            for (int i=1; i <= len; ++i) {
                lua_rawgeti(s, tableIndex, i);
                [info appendString:printStackAt(s, -1)];
                lua_pop(s, 1);
            }
        }
    }
    return info;
}

int probe(lua_State *s)
{
    printf("[lua] ");
    if (lua_isnil(s, 1)) {
        printf("probe: is nil\n");
        return 0;
    }
    else if (lua_isnumber(s, 1)) {
        printf("probe: is number: %f\n", lua_tonumber(s, 1));
        return 0;
    }
    else if (lua_isboolean(s, 1)) {
        printf("probe: is boolean: %d\n", lua_toboolean(s, 1));
        return 0;
    }
    else if (lua_istable(s, 1)) {
        printf("probe: is table\n");
        return 0;
    }
    else {
        IndigoObjectUserdata *userdata = (IndigoObjectUserdata *)lua_touserdata(s, 1);
        if (userdata->ctype[0]=='@') {
            printf("probe: is oc object: %s\n", [(id)userdata->cptr description].UTF8String);
        }
        else if (userdata->ctype[0]=='{'){
            printf("probe: is struct type: %s\n", userdata->ctype);
        }
        return 0;
    }
}


int luaPrint(lua_State *s)
{
#ifdef LOG_LUA_PRINT
    int numOfArgs = lua_gettop(s);
    printf("[lua] ");
    for (int i = 0; i < numOfArgs; ++i) {
        if (lua_isnil(s, 1 + i)) {
            printf("<nil>");
        }
        else if (lua_isuserdata(s, 1 + i)) {
            IndigoObjectUserdata *userdata = (IndigoObjectUserdata *)lua_touserdata(s, 1 + i);
            if (userdata->ctype[0]=='@'||userdata->ctype[0]=='#') {
                printf("object: %s", [(id)userdata->cptr description].UTF8String);
            }
            else if (userdata->ctype[0]=='@'||userdata->ctype[0]=='#') {
                printf("struct: %s", userdata->ctype);
            }
            else {
                printf("objc type: %s ptr: %p", userdata->ctype, userdata->cptr);
            }
        }
        //you can not convert lua boolean to number
        else if (lua_isboolean(s, 1 + i)) {
            printf("%s", lua_toboolean(s, 1 + i)?"true":"false");
        }
        else {
            printf("%s", lua_tostring(s, 1 + i));
        }
    }
    printf("\n");
#endif
    return 0;
}

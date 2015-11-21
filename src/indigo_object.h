//
//  indigo_object.h
//  indigo
//
//  Created by zhang on 8/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "lua.h"

typedef struct{
    void *cptr;//pointer to the wrapped objc object
    char *ctype;
    bool isPtr;//Is this object a pointer to an object, such as `NSError **`
    bool isStruct;
    bool isInSuperMethodContext;
    bool isInClassMethodContext;
}IndigoObjectUserdata;

int luaopen_indigo_object(lua_State *s);

IndigoObjectUserdata *indigo_check_object_userdata(lua_State *s, int stackIndex);

/*
    The return value should only be used in -[NSInvocation setArgument:atIndex:] method,
    and needs to be freed after using.
 */
void *lua2oc(lua_State *s, int stackIndex, const char *targetType, void *owner);//[-0,+0]

/*
    buffer holds the address of objc instance(of type 'id *'), it must not be NULL
 */
void push_object(lua_State *s, void *instance, const char *type, bool isDeallocing);//[-0,+1]

/*
    Retain the arguments captured by this block on behalf of YOU.
    You must call `closure_release_arguments_without_owner` manually to release the arguments.
 */
void closure_capture_arguments_without_owner(lua_State *s, int functionIndex);//[-0,+0]

/*
    Manually release the captured arguments.
*/
void closure_release_arguments_without_owner(lua_State *s, int functionIndex);//[-0,+0]

/*
    Retain the arguments captured by this block on behalf of the an `owner`
    When the owner deallocs, the captured arguments will be released at the same time.
    You MUST NOT do a manual releasing.
 */
void closure_capture_arguments_owner(lua_State *s, int functionIndex, id owner);//[-0,+0]

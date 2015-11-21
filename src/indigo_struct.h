//
//  indigo_struct.h
//  indigo
//
//  Created by zhang on 11/8/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "lua.h"

//NOTE: keep struct type definition same as instance!!!
typedef struct{
    void *cptr;//pointer to the wrapped struct
    char *ctype;
    bool isPtr;
    bool isStruct;
    bool asSuper;
    bool asClass;
}IndigoStructUserdata;

int luaopen_indigo_struct(lua_State *L);

IndigoStructUserdata *indigo_check_struct_userdata(lua_State *s, int stackIndex);

/*
    Usually ptr is of type `Struct Foo *`(such as CGRect *). 
    When isPointer is true, ptr then is of type 'Struct Foo **'
 */
void push_struct(lua_State *s, void *ptr, const char *structTypeDescription, bool isPointer);
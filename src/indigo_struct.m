//
//  indigo_struct.m
//  indigo
//
//  Created by zhang on 11/8/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_struct.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <string.h>

#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGAffineTransform.h>
#import "indigo_helper.h"

#define INDIGO_STRUCT_METATABLE "indigo.struct"

static int _struct_index(lua_State *L);
static int _struct_newindex(lua_State *L);
static int _struct_call(lua_State *L);
static int _struct_gc(lua_State *L);

static const struct luaL_Reg structMetaFunctions[] = {
    {"__index", _struct_index},
    {"__newindex", _struct_newindex},
    {"__call", _struct_call},
    {"__gc", _struct_gc},
    {NULL, NULL}
};
static int struct_create_cgrect(lua_State *s);
static int struct_create_cgsize(lua_State *s);
static int struct_create_cgpoint(lua_State *s);
static int struct_create_cgaffinetransform(lua_State *s);
static int struct_create_cgvector(lua_State *s);

extern void push_object(lua_State *s, void *instance, const char *type, bool isDeallocing);

static const struct luaL_Reg struct_global_functions[] = {
    {"CGRect", struct_create_cgrect},
    {"CGSize", struct_create_cgsize},
    {"CGPoint", struct_create_cgpoint},
    {"CGAffineTransform", struct_create_cgaffinetransform},
    {"CGVector", struct_create_cgvector},
    
    {NULL, NULL}
};

int luaopen_indigo_struct(lua_State *L)
{
    luaL_newmetatable(L, INDIGO_STRUCT_METATABLE);
    luaL_setfuncs(L, structMetaFunctions, 0);
    
    //set globals
    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    luaL_setfuncs(L, struct_global_functions, 0);
    lua_pop(L, 1);
    
    return 1;
}

static int _struct_gc(lua_State *s)
{
    IndigoStructUserdata *userdata = luaL_checkudata(s, 1, INDIGO_STRUCT_METATABLE);
    
    //NSLog(@"struct gc: %p cptr: %p ctype: %s", userdata, userdata->cptr, userdata->ctype);
    
    free(userdata->ctype);
    free(userdata->cptr);
    
    lua_pushnil(s);
    lua_setuservalue(s, 1);
    
    return 0;
}

#pragma mark - struct create methods
static int struct_create_cgrect(lua_State *s)
{
    if (!lua_istable(s, 1)) luaL_error(s, "CGRect accept only one lua table parameter: CGRect{origin.x, orgin.y, size.width, size.height}.");
    
    CGRect frame;
    size_t len = lua_rawlen(s, 1);
    for (int i=1; i<=len; ++i) {
        lua_rawgeti(s, 1, i);
        if (i == 1) {
            frame.origin.x = lua_tonumber(s, -1);
        }
        else if (i == 2) {
            frame.origin.y = lua_tonumber(s, -1);
        }
        else if (i == 3) {
            frame.size.width = lua_tonumber(s, -1);
        }
        else {
            frame.size.height = lua_tonumber(s, -1);
        }
        
        lua_pop(s, 1);
    }
    push_object(s, &frame, @encode(CGRect), false);
    return 1;
}

static int struct_create_cgsize(lua_State *s)
{
    if (!lua_istable(s, 1)) luaL_error(s, "CGSize accept only one lua table parameter: CGSize{width, height}.");
    
    CGSize size;
    size_t len = lua_rawlen(s, 1);
    for (int i=1; i<=len; ++i) {
        lua_rawgeti(s, 1, i);
        if (i == 1) {
            size.width = lua_tonumber(s, -1);
        }
        else if (i == 2) {
            size.height = lua_tonumber(s, -1);
        }
        
        lua_pop(s, 1);
    }
    
    push_object(s, &size, @encode(CGSize), false);
    return 1;
}

static int struct_create_cgpoint(lua_State *s)
{
    if (!lua_istable(s, 1)) luaL_error(s, "CGPoint accept only one lua table parameter: CGPoint{x, y}.");
    
    CGPoint point;
    size_t len = lua_rawlen(s, 1);
    for (int i=1; i<=len; ++i) {
        lua_rawgeti(s, 1, i);
        if (i == 1) {
            point.x = lua_tonumber(s, -1);
        }
        else if (i == 2) {
            point.y = lua_tonumber(s, -1);
        }
        
        lua_pop(s, 1);
    }
    
    push_object(s, &point, @encode(CGPoint), false);
    return 1;
}

static int struct_create_cgaffinetransform(lua_State *s)
{
    if (!lua_istable(s, 1)) luaL_error(s, "CGAffineTransform accept only one lua table parameter: CGAffineTransform{a, b, c, d, dx, dy}.");
    
    CGAffineTransform transform;
    size_t len = lua_rawlen(s, 1);
    for (int i=1; i<=len; ++i) {
        lua_rawgeti(s, 1, i);
        if (i == 1) {
            transform.a = lua_tonumber(s, -1);
        }
        else if (i == 2) {
            transform.b = lua_tonumber(s, -1);
        }
        else if (i == 3) {
            transform.c = lua_tonumber(s, -1);
        }
        else if (i == 4) {
            transform.d = lua_tonumber(s, -1);
        }
        else if (i == 5) {
            transform.tx = lua_tonumber(s, -1);
        }
        else if (i == 6) {
            transform.ty = lua_tonumber(s, -1);
        }
        
        lua_pop(s, 1);
    }
    
    push_object(s, &transform, @encode(CGPoint), false);
    return 1;
}

static int struct_create_cgvector(lua_State *s)
{
    if (!lua_istable(s, 1)) luaL_error(s, "CGRect accept only one lua table parameter: CGSize{width, height}.");
    
    CGVector vector;
    size_t len = lua_rawlen(s, 1);
    for (int i=1; i<=len; ++i) {
        lua_rawgeti(s, 1, i);
        if (i == 1) {
            vector.dx = lua_tonumber(s, -1);
        }
        else if (i == 2) {
            vector.dy = lua_tonumber(s, -1);
        }
        
        lua_pop(s, 1);
    }
    
    push_object(s, &vector, @encode(CGPoint), false);
    return 1;
}

//FIXME: maybe we could do this not by hard-coding
int _struct_index(lua_State *s)
{
    IndigoStructUserdata *userdata = indigo_check_struct_userdata(s, 1);
    const char *methodName = luaL_checkstring(s, 2);
    const char *structType = strstr(userdata->ctype, "{");
    if (!strcmp(structType, @encode(CGRect))) {
        CGRect *r = (CGRect *)userdata->cptr;
        if (!strcmp(methodName, "origin")) {
            push_struct(s, &(r->origin), @encode(CGPoint), false);
        }
        else if (!strcmp(methodName, "size")) {
            push_struct(s, &(r->size), @encode(CGSize), false);
        }
        else {
            luaL_error(s, "CGRect has no member named `%s`", methodName);
        }
    }
    else if (!strcmp(structType, @encode(CGPoint))) {
        CGPoint *r = (CGPoint *)userdata->cptr;
        if (!strcmp(methodName, "x")) {
            lua_pushnumber(s, r->x);
        }
        else if (!strcmp(methodName, "y")) {
            lua_pushnumber(s, r->y);
        }
        else {
            luaL_error(s, "CGPoint has no member named `%s`", methodName);
        }
    }
    else if (!strcmp(structType, @encode(CGSize))) {
        CGSize *r = (CGSize *)userdata->cptr;
        if (!strcmp(methodName, "width")) {
            lua_pushnumber(s, r->width);
        }
        else if (!strcmp(methodName, "height")) {
            lua_pushnumber(s, r->height);
        }
        else {
            luaL_error(s, "CGPoint has no member named `%s`", methodName);
        }
    }
    else if (!strcmp(structType, @encode(CGVector))) {
        CGVector *r = (CGVector *)userdata->cptr;
        if (!strcmp(methodName, "dx")) {
            lua_pushnumber(s, r->dx);
        }
        else if (!strcmp(methodName, "dy")) {
            lua_pushnumber(s, r->dy);
        }
        else {
            luaL_error(s, "CGPoint has no member named `%s`", methodName);
        }
    }
    else if (!strcmp(structType, @encode(CGAffineTransform))) {
        CGAffineTransform *r = (CGAffineTransform *)userdata->cptr;
        if (!strcmp(methodName, "a")) {
            lua_pushnumber(s, r->a);
        }
        else if (!strcmp(methodName, "b")) {
            lua_pushnumber(s, r->b);
        }
        else if (!strcmp(methodName, "c")) {
            lua_pushnumber(s, r->c);
        }
        else if (!strcmp(methodName, "d")) {
            lua_pushnumber(s, r->d);
        }
        else if (!strcmp(methodName, "tx")) {
            lua_pushnumber(s, r->tx);
        }
        else if (!strcmp(methodName, "ty")) {
            lua_pushnumber(s, r->ty);
        }
        else {
            luaL_error(s, "CGPoint has no member named `%s`", methodName);
        }
    }
    else luaL_error(s, "unknown struct type `%s`, you need to add it manually.", structType);
    
    return 1;
}

//FIXME: maybe we could do this not by hard-coding
int _struct_newindex(lua_State *s)
{
    IndigoStructUserdata *instanceUdata = indigo_check_struct_userdata(s, 1);
    const char *propertyName = luaL_checkstring(s, -2);
    const char *structTypeDescription = strstr(instanceUdata->ctype, "{");
    
    //set struct member
    if (!strcmp(structTypeDescription, @encode(CGRect))) {
        CGRect *r = *(CGRect **)instanceUdata->cptr;
        if (!strcmp(propertyName, "origin")) {
            //CGRect.origin
            IndigoStructUserdata *param = indigo_check_struct_userdata(s, -1);
            r->origin = *(CGPoint *)param->cptr;
        }
        else if (!strcmp(propertyName, "size")) {
            //CGRect.origin
            IndigoStructUserdata *param = indigo_check_struct_userdata(s, -1);
            r->size = *(CGSize *)param->cptr;
        }
        else {
            luaL_error(s, "struct has no member named `%s`", propertyName);
        }
    }
    else if (!strcmp(structTypeDescription, @encode(CGPoint))) {
        CGPoint *r = *(CGPoint **)instanceUdata->cptr;
        lua_Number value = lua_tonumber(s, -1);
        if (!strcmp(propertyName, "x")) {
            r->x = value;
        }
        else if (!strcmp(propertyName, "y")) {
            r->y = value;
        }
    }
    else if (!strcmp(structTypeDescription, @encode(CGSize))) {
        CGSize *r = *(CGSize **)instanceUdata->cptr;
        lua_Number value = lua_tonumber(s, -1);
        if (!strcmp(propertyName, "width")) {
            r->width = value;
        }
        else if (!strcmp(propertyName, "height")) {
            r->height = value;
        }
    }
    else if (!strcmp(structTypeDescription, @encode(CGVector))) {
        CGVector *r = *(CGVector **)instanceUdata->cptr;
        lua_Number value = lua_tonumber(s, -1);
        if (!strcmp(propertyName, "dx")) {
            r->dx = value;
        }
        else if (!strcmp(propertyName, "dy")) {
            r->dy = value;
        }
    }
    else if (!strcmp(structTypeDescription, @encode(CGAffineTransform))) {
        CGAffineTransform *r = *(CGAffineTransform **)instanceUdata->cptr;
        lua_Number value = lua_tonumber(s, -1);
        if (!strcmp(propertyName, "a")) {
            r->a = value;
        }
        else if (!strcmp(propertyName, "b")) {
            r->b = value;
        }
        else if (!strcmp(propertyName, "c")) {
            r->c = value;
        }
        else if (!strcmp(propertyName, "d")) {
            r->d = value;
        }
        else if (!strcmp(propertyName, "tx")) {
            r->tx = value;
        }
        else if (!strcmp(propertyName, "ty")) {
            r->ty = value;
        }
    }
    else {
        luaL_error(s, "unknown struct type `%s`, you need to add it manually.", structTypeDescription);
    }
    
    return 0;
}

static int _struct_call(lua_State *s)
{
    if (lua_isnil(s, 1)) {
        //allow nil call, just like [nil doSomething] in objc
        return 0;
    }
    else {
        lua_pushvalue(s, 1);
        return 1;
    }
}

void push_struct(lua_State *s, void *ptr, const char *structTypeDescription, bool isPointer)
{
    lua_checkstack(s, 3);
    IndigoStructUserdata *userdata = (IndigoStructUserdata *)lua_newuserdata(s, sizeof(IndigoStructUserdata));
    memset(userdata, 0, sizeof(IndigoStructUserdata));
    
    char *ctype = calloc(strlen(structTypeDescription) + 1, sizeof(char));
    memcpy(ctype, structTypeDescription, strlen(structTypeDescription));
    userdata->ctype = ctype;
    
    if (isPointer) {
        void **newPtr = calloc(1, sizeof(void *));
        memcpy(newPtr, ptr, sizeof(void *));
        userdata->cptr = newPtr;
    }
    else {
        int size = structBytesFromTypeDescription(structTypeDescription);
        char *stut = calloc(1, size);
        memcpy(stut, ptr, size);
        userdata->cptr = stut;
    }
    
    userdata->isStruct = true;
    
    luaL_getmetatable(s, INDIGO_STRUCT_METATABLE);
    lua_setmetatable(s, -2);
}

IndigoStructUserdata *indigo_check_struct_userdata(lua_State *s, int stackIndex)
{
    IndigoStructUserdata *userdata = luaL_checkudata(s, stackIndex, INDIGO_STRUCT_METATABLE);
    return userdata;
}

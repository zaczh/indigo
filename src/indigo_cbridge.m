//
//  indigo_cbridge.m
//  indigo
//
//  Created by zhang on 11/8/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_cbridge.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <string.h>

#include <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGAffineTransform.h>
#import "indigo_helper.h"

#import "indigo_object.h"
#import "indigo_struct.h"

#import <UIKit/UIKit.h>

#define INDIGO_CBRIDGE_METATABLE "indigo.cbridge"

extern lua_State *luaThread();

//struct create
static int cbridge_CGSizeMake(lua_State *s);
static int cbridge_CGPointMake(lua_State *s);
static int cbridge_CGRectMake(lua_State *s);
static int cbridge_NSMakeRange(lua_State *s);

//GCD
static int cbridge_dispatch_after(lua_State *s);
static int cbridge_dispatch_sync(lua_State *s);
static int cbridge_dispatch_barrier_sync(lua_State *s);
static int cbridge_dispatch_async(lua_State *s);
static int cbridge_dispatch_get_main_queue(lua_State *s);
static int cbridge_dispatch_get_global_queue(lua_State *s);

//UIKit
static int cbridge_UIGraphicsBeginImageContext(lua_State *s);
static int cbridge_UIGraphicsGetCurrentContext(lua_State *s);
static int cbridge_UIGraphicsGetImageFromCurrentImageContext(lua_State *s);

//Quartz
static int cbridge_CGContextTranslateCTM(lua_State *s);
static int cbridge_CGContextScaleCTM(lua_State *s);
static int cbridge_CGContextSetFillColorWithColor(lua_State *s);
static int cbridge_CGContextSetLineWidth(lua_State *s);
static int cbridge_CGContextMoveToPoint(lua_State *s);
static int cbridge_CGContextAddLineToPoint(lua_State *s);
static int cbridge_CGContextClosePath(lua_State *s);
static int cbridge_CGContextFillPath(lua_State *s);
static int cbridge_CGContextFillRect(lua_State *s);

static const struct luaL_Reg cbridge_global_functions[] = {
    {"CGPointMake", cbridge_CGPointMake},
    {"CGSizeMake", cbridge_CGSizeMake},
    {"CGRectMake", cbridge_CGRectMake},
    {"NSMakeRange", cbridge_NSMakeRange},
    
    {"dispatch_after", cbridge_dispatch_after},
    {"dispatch_sync", cbridge_dispatch_sync},
    {"dispatch_barrier_sync", cbridge_dispatch_barrier_sync},
    {"dispatch_async", cbridge_dispatch_async},
    {"dispatch_get_main_queue", cbridge_dispatch_get_main_queue},
    {"dispatch_get_global_queue", cbridge_dispatch_get_global_queue},
    
    {"UIGraphicsBeginImageContext",cbridge_UIGraphicsBeginImageContext},
    {"UIGraphicsGetCurrentContext",cbridge_UIGraphicsGetCurrentContext},
    {"UIGraphicsGetImageFromCurrentImageContext",cbridge_UIGraphicsGetImageFromCurrentImageContext},
    
    {"CGContextTranslateCTM",cbridge_CGContextTranslateCTM},
    {"CGContextScaleCTM",cbridge_CGContextScaleCTM},
    {"CGContextSetFillColorWithColor",cbridge_CGContextSetFillColorWithColor},
    {"CGContextSetLineWidth",cbridge_CGContextSetLineWidth},
    {"CGContextMoveToPoint",cbridge_CGContextMoveToPoint},
    {"CGContextAddLineToPoint",cbridge_CGContextAddLineToPoint},
    {"CGContextClosePath",cbridge_CGContextClosePath},
    {"CGContextFillPath", cbridge_CGContextFillPath},
    {"CGContextFillRect", cbridge_CGContextFillRect},
    
    {NULL, NULL}
};

int luaopen_indigo_cbridge(lua_State *s)
{
    luaL_newmetatable(s, INDIGO_CBRIDGE_METATABLE);
    
    //set globals
    lua_rawgeti(s, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    luaL_setfuncs(s, cbridge_global_functions, 0);
    lua_pop(s, 1);
    
    return 1;
}

#pragma mark - struct creation functions
static int cbridge_CGSizeMake(lua_State *s)
{
    CGSize rect = CGSizeMake(lua_tonumber(s, 1), lua_tonumber(s, 2));
    push_struct(s, &rect, @encode(CGSize), false);
    return 1;
}

static int cbridge_CGPointMake(lua_State *s)
{
    CGPoint strut = CGPointMake(lua_tonumber(s, 1), lua_tonumber(s, 2));
    push_struct(s, &strut, @encode(CGPoint), false);
    return 1;
}

static int cbridge_CGRectMake(lua_State *s)
{
    CGRect rect = CGRectMake(lua_tonumber(s, 1), lua_tonumber(s, 2), lua_tonumber(s, 3), lua_tonumber(s, 4));
    push_struct(s, &rect, @encode(CGRect), false);
    return 1;
}

static int cbridge_NSMakeRange(lua_State *s)
{
    NSRange range = NSMakeRange(lua_tointeger(s, 1), lua_tointeger(s, 2));
    push_struct(s, &range, @encode(NSRange), false);
    return 1;
}

#pragma mark - GCD functions
static int cbridge_dispatch_after(lua_State *s)
{
    dispatch_time_t time = lua_tointeger(s, 1);
    IndigoObjectUserdata *queueInstance = indigo_check_object_userdata(s, 2);
    dispatch_queue_t queue = (dispatch_queue_t)queueInstance->cptr;
    
    lua_pushvalue(s, 3);
    int funcRef = luaL_ref(s, LUA_REGISTRYINDEX);
    
    closure_capture_arguments_without_owner(s, -1);
    
    dispatch_after(time, queue, ^{
        lua_State *subThread = luaThread();
        assert(subThread);
        lua_rawgeti(subThread, LUA_REGISTRYINDEX, funcRef);
        assert(lua_isfunction(subThread, -1));
        lua_pushvalue(subThread, -1);
        
        if (LUA_OK != lua_pcall(subThread, 0, 0, 0)) {
            luaL_error(subThread, lua_tostring(subThread, -1));
        }
        
        closure_release_arguments_without_owner(subThread, -1);
        lua_pop(subThread, 1);//pop the function out
    });
    return 0;
}

static int cbridge_dispatch_sync(lua_State *s)
{
    IndigoObjectUserdata *queueInstance = indigo_check_object_userdata(s, 1);
    dispatch_queue_t queue = (dispatch_queue_t)queueInstance->cptr;
    
    lua_pushvalue(s, 2);
    int funcRef = luaL_ref(s, LUA_REGISTRYINDEX);
    
    closure_capture_arguments_without_owner(s, -1);
    
    dispatch_sync(queue, ^{
        lua_State *subThread = luaThread();
        assert(subThread);
        lua_rawgeti(subThread, LUA_REGISTRYINDEX, funcRef);
        assert(lua_isfunction(subThread, -1));
        lua_pushvalue(subThread, -1);
        
        if (LUA_OK != lua_pcall(subThread, 0, 0, 0)) {
            luaL_error(subThread, lua_tostring(subThread, -1));
        }
        
        closure_release_arguments_without_owner(subThread, -1);
        lua_pop(subThread, 1);//pop the function out
    });
    return 0;
}

static int cbridge_dispatch_barrier_sync(lua_State *s)
{
    IndigoObjectUserdata *queueInstance = indigo_check_object_userdata(s, 1);
    dispatch_queue_t queue = (dispatch_queue_t)queueInstance->cptr;
    
    lua_pushvalue(s, 2);
    int funcRef = luaL_ref(s, LUA_REGISTRYINDEX);
    
    closure_capture_arguments_without_owner(s, -1);
    
    dispatch_barrier_sync(queue, ^{
        lua_State *subThread = luaThread();
        assert(subThread);
        lua_rawgeti(subThread, LUA_REGISTRYINDEX, funcRef);
        assert(lua_isfunction(subThread, -1));
        lua_pushvalue(subThread, -1);
        
        if (LUA_OK != lua_pcall(subThread, 0, 0, 0)) {
            luaL_error(subThread, lua_tostring(subThread, -1));
        }
        
        closure_release_arguments_without_owner(subThread, -1);
        lua_pop(subThread, 1);//pop the function out
    });
    return 0;
}

static int cbridge_dispatch_async(lua_State *s)
{
    IndigoObjectUserdata *queueInstance = indigo_check_object_userdata(s, 1);
    dispatch_queue_t queue = (dispatch_queue_t)queueInstance->cptr;

    lua_pushvalue(s, 2);
    int funcRef = luaL_ref(s, LUA_REGISTRYINDEX);
    
    closure_capture_arguments_without_owner(s, -1);
    
    dispatch_async(queue, ^{
        lua_State *subThread = luaThread();
        assert(subThread);
        lua_rawgeti(subThread, LUA_REGISTRYINDEX, funcRef);
        assert(lua_isfunction(subThread, -1));
        lua_pushvalue(subThread, -1);
        
        if (LUA_OK != lua_pcall(subThread, 0, 0, 0)) {
            luaL_error(subThread, lua_tostring(subThread, -1));
        }
        
        closure_release_arguments_without_owner(subThread, -1);
        lua_pop(subThread, 1);//pop the function out
    });
    return 0;
}

static int cbridge_dispatch_get_main_queue(lua_State *s)
{
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    push_object(s, &mainQueue, @encode(dispatch_queue_t), false);
    return 1;
}

static int cbridge_dispatch_get_global_queue(lua_State *s)
{
    dispatch_queue_t queue = dispatch_get_global_queue(lua_tointeger(s, 1),lua_tointeger(s, 2));
    push_object(s, &queue, @encode(dispatch_queue_t), false);
    return 1;
}

#pragma mark - UIKit functions

static int cbridge_UIGraphicsBeginImageContext(lua_State *s)
{
    IndigoStructUserdata *size = indigo_check_struct_userdata(s, 1);
    UIGraphicsBeginImageContext(*(CGSize *)size->cptr);
    return 0;
}

static int cbridge_UIGraphicsGetCurrentContext(lua_State *s)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    push_struct(s, &context, @encode(CGContextRef), true);
    return 1;
}

static int cbridge_UIGraphicsGetImageFromCurrentImageContext(lua_State *s)
{
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    push_object(s, &image, @encode(UIImage *), false);
    return 1;
}

#pragma mark - Quartz functions
static int cbridge_CGContextTranslateCTM(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextTranslateCTM(*(CGContextRef *)context->cptr, lua_tonumber(s, 2), lua_tonumber(s, 3));
    return 0;
}

static int cbridge_CGContextScaleCTM(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextScaleCTM(*(CGContextRef *)context->cptr, lua_tonumber(s, 2), lua_tonumber(s, 3));
    return 0;
}

static int cbridge_CGContextSetFillColorWithColor(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    IndigoStructUserdata *color = indigo_check_struct_userdata(s, 2);
    CGContextSetFillColorWithColor(*(CGContextRef*)context->cptr, *(CGColorRef *)color->cptr);
    return 0;
}

static int cbridge_CGContextSetLineWidth(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextSetLineWidth(*(CGContextRef*)context->cptr, lua_tonumber(s, 2));
    return 0;
}

static int cbridge_CGContextFillRect(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    IndigoStructUserdata *rect = indigo_check_struct_userdata(s, 2);

    CGContextFillRect(*(CGContextRef*)context->cptr, *(CGRect *)rect->cptr);
    return 0;
}

static int cbridge_CGContextMoveToPoint(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextMoveToPoint(*(CGContextRef*)context->cptr, lua_tonumber(s, 2), lua_tonumber(s, 3));
    return 0;
}

static int cbridge_CGContextAddLineToPoint(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextAddLineToPoint(*(CGContextRef*)context->cptr, lua_tonumber(s, 2), lua_tonumber(s, 3));
    return 0;
}

static int cbridge_CGContextClosePath(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextClosePath(*(CGContextRef*)context->cptr);
    return 0;
}

static int cbridge_CGContextFillPath(lua_State *s)
{
    IndigoStructUserdata *context = indigo_check_struct_userdata(s, 1);
    CGContextFillPath(*(CGContextRef*)context->cptr);
    return 0;
}



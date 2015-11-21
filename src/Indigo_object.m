//
//  indigo_object.m
//  indigo
//
//  Created by zhang on 8/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_object.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <objc/runtime.h>
#import "indigo_helper.h"
#import "indigo_gc.h"

#define INDIGO_OBJECT_REGISTER_KEY "indigo.object.reg"
#define INDIGO_OBJECT_METATABLE "indigo.object"


//log control macro
#ifdef DEBUG
//#define LOG_OBJECT_CREATION
//#define LOG_OBJECT_GC
//#define LOG_OBJECT_CALL
#endif

static int _object_index(lua_State *L);
static int _object_newindex(lua_State *L);
static int _object_call(lua_State *L);
static int _object_gc(lua_State *L);

static int _closure_run(lua_State *s);
static int _closure_push(lua_State *L, id receiver, SEL selector, BOOL invokeAsSuper, BOOL isClassMethod);

#ifdef INDIGO_RIGOROUS_GC
static void _object_push_uservalue(lua_State *s, int idx);
#endif

static void _object_push(lua_State *s, void *instance, const char *typeDescription, bool isPointer);

extern lua_State *luaThread();
extern void *toBlock(lua_State *s, int functionIndex, void *owner);
extern void push_struct(lua_State *s, void *ptr, const char *structTypeDescription, bool isPointer);
extern bool check_no_unknown_class_in_creation_context();

static const struct luaL_Reg ObjectMetaFunctions[] = {
    {"__index", _object_index},
    {"__newindex", _object_newindex},
    {"__call", _object_call},
    {"__gc", _object_gc},
    {NULL, NULL}
};

static const struct luaL_Reg object_global_functions[] = {
    {NULL, NULL}
};

#pragma mark - module portal
int luaopen_indigo_object(lua_State *s)
{
    luaL_newmetatable(s, INDIGO_OBJECT_METATABLE);
    luaL_setfuncs(s, ObjectMetaFunctions, 0);
    lua_pushnil(s);
    lua_pushvalue(s, -2);
    lua_setmetatable(s, -2);
    lua_pop(s, 1);
    
    //set globals
    lua_rawgeti(s, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    luaL_setfuncs(s, object_global_functions, 0);
    lua_pop(s, 1);
    
    return 1;
}

static int _object_gc(lua_State *s)
{
    IndigoObjectUserdata *userdata = luaL_checkudata(s, 1, INDIGO_OBJECT_METATABLE);
    
#ifdef LOG_OBJECT_GC
    printf("instance gc: %p cptr: %p ctype: %s\n", userdata, userdata->cptr, userdata->ctype);
#endif
    
    free(userdata->ctype);
    
    if (userdata->isPtr || userdata->isStruct) {
        free(userdata->cptr);
    }
    
    lua_pushnil(s);
    lua_setuservalue(s, 1);
    
    return 0;
}

#ifdef INDIGO_RIGOROUS_GC
static void _object_push_uservalue(lua_State *s, int idx)
{
    assert(idx>0);
    lua_getuservalue(s, idx);
    if (lua_isnil(s, -1)) {
        lua_pop(s, 1);
        lua_newtable(s);
        lua_pushvalue(s, -1);
        lua_setuservalue(s, idx);
    }
}
#endif

static int _object_index(lua_State *s)
{
    if (lua_isnil(s, 1)) {
        lua_pushnil(s);
        return 1;
    }
    
    IndigoObjectUserdata *userdata = luaL_checkudata(s, 1, INDIGO_OBJECT_METATABLE);
    const char *ctype = userdata->ctype;
    assert(strlen(ctype)>0);
    const char *methodName = luaL_checkstring(s, 2);
    
    if (ctype[0]=='%') {
        if (!strcmp("asInoutBool", methodName)) {
            BOOL *value = *(BOOL **)userdata->cptr;
            lua_pushboolean(s, *value);
            return 1;
        }
        else if (!strcmp("asBool", methodName)) {
            int value = *(int *)userdata->cptr;
            lua_pushboolean(s, value);
            return 1;
        }
        else if (!strcmp("asInt", methodName)) {
            int value = *(int *)userdata->cptr;
            lua_pushinteger(s, value);
            return 1;
        }
        else if (!strcmp("asDouble", methodName)) {
            double value = *(double *)userdata->cptr;
            lua_pushnumber(s, value);
            return 1;
        }
        else if (!strcmp("asObject", methodName)) {
            id value = *(id *)userdata->cptr;
            _object_push(s, (void *)value, @encode(id), false);
            return 1;
        }
    }
    
    if (!strcmp("class", methodName)) {
        userdata->isInClassMethodContext = true;
        lua_pushvalue(s, 1);
        return 1;
    }
    
    bool isClassMethod = userdata->isInClassMethodContext;
    id instance = (id)userdata->cptr;
    SEL selector = objcSelectorFromLuaMethodName(methodName);
    
    if (isClassMethod) {
        _closure_push(s, instance, selector, userdata->isInSuperMethodContext, true);
        userdata->isInClassMethodContext = false;
        return 1;
    }
    
#ifdef INDIGO_RIGOROUS_GC
    _object_push_uservalue(s, 1);
    
    lua_pushvalue(s, 2);
    lua_rawget(s, -2);
    if (!lua_isnil(s, -1)) {
        lua_remove(s, -2);
        return 1;
    }
    lua_pop(s, 2);
#endif
    
    if (!strcmp(methodName, "super")) {
        lua_pushvalue(s, 1);
        userdata->isInSuperMethodContext = true;
        return 1;
    }
    
    const char *structType = strstr(userdata->ctype, "{");
    if (structType) {
        //struct index should goes to _struct_index, not here
        assert(0);
        return 1;
    }
    
    if (userdata->isInSuperMethodContext) {
        _closure_push(s, instance, selector, true, isClassMethod);
        userdata->isInSuperMethodContext = false;
        return 1;
    }
    
    _closure_push(s, instance, selector, userdata->isInSuperMethodContext, false);

    return 1;
}

static int _object_newindex(lua_State *s)
{
    if (lua_isnil(s, 1)) {
        
        if (!check_no_unknown_class_in_creation_context()) {
            luaL_error(s, "Unknown class. You may have written a wrong class name.");
        }
        
        lua_pushnil(s);
        return 1;
    }
    
    IndigoObjectUserdata *instanceUdata = luaL_checkudata(s, 1, INDIGO_OBJECT_METATABLE);
    const char *propertyName = luaL_checkstring(s, 2);

    if (instanceUdata->ctype[0] == '%') {
        if (!strcmp("asInoutBool", propertyName)) {
            BOOL *value = *(BOOL **)instanceUdata->cptr;
            *value = lua_toboolean(s, -1);
            return 0;
        }
        else if (!strcmp("asInoutDouble", propertyName)) {
            double *value = (double *)instanceUdata->cptr;
            *value = lua_tonumber(s, -1);
            return 0;
        }
    }
    
    id instance = (id)(instanceUdata->cptr);
    assert(instance);
    
    Class klass = object_getClass(instance);
    SEL setter = objcSetterForProperty(propertyName);
    
    NSMethodSignature *signature = [instance methodSignatureForSelector:setter];
    if (signature) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:instance];
        [invocation setSelector:setter];
        
        const char *type = [signature getArgumentTypeAtIndex:2];
        void *arg = lua2oc(s, -1, type, NULL);
        
        [invocation setArgument:arg atIndex:2];
        [invocation invoke];
        free(arg);
        
#ifdef INDIGO_RIGOROUS_GC
        _object_push_uservalue(s, 1);
        lua_pushvalue(s, 2);//key
        lua_pushvalue(s, 3);//new value
        lua_rawset(s, -3);
        lua_pop(s, 1);//uservalue
#endif
        
        return 0;
    }
    else return luaL_error(s, "instance: %s doesn't have a property named: %s", class_getName(klass), propertyName);
}

static int _object_call(lua_State *s)
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

#ifdef INDIGO_RIGOROUS_GC
int _push_reg_table(lua_State *s)
{
    lua_pushstring(s, INDIGO_OBJECT_REGISTER_KEY);
    lua_gettable(s, LUA_REGISTRYINDEX);
    
    if (lua_isnil(s, -1)) {
        lua_pop(s, 1);
        lua_newtable(s);
        lua_pushstring(s, "k");
        lua_setfield(s, -2, "__mode");
        
        //set up object register table
        lua_pushstring(s, INDIGO_OBJECT_REGISTER_KEY);
        lua_pushvalue(s, -2);
        lua_rawset(s, LUA_REGISTRYINDEX);
    }
    
    return 1;
}
#endif

//this function must not return NULL
void *lua2oc(lua_State *s, int stackIndex, const char *targetType, void *owner)
{
    void *value = NULL;
    
    switch (targetType[0]) {
        case '@':
        case '#'://#define _C_CLASS    '#'
        {
            value = calloc(1, sizeof(id));
            if (lua_isstring(s, stackIndex)) {
                const char *d = lua_tostring(s, stackIndex);
                NSString *arg = [NSString stringWithUTF8String:d];
                *(id *)value = arg;
            }
            else if (lua_isnumber(s, stackIndex)) {
                lua_Number d = lua_tonumber(s, stackIndex);
                id arg = @(d);
                *(id *)value = arg;
            }
            else if (lua_isfunction(s, stackIndex)) {
                //pushing a block parameter
                id arg = (id)toBlock(s, stackIndex, owner);
                *(id *)value = arg;
            }
            else {
                if (lua_isnil(s, stackIndex)) {
                    *(id *)value = nil;
                }
                else {
                    id arg = ((IndigoObjectUserdata *)lua_touserdata(s, stackIndex))->cptr;
                    *(id *)value = arg;
                }
            }
            break;
        }
        case ':'://#define _C_SEL      ':'
        {
            if (lua_isstring(s, stackIndex)) {
                const char *d = lua_tostring(s, stackIndex);
                value = calloc(1, sizeof(SEL));
                *(SEL *)value = objcSelectorFromLuaMethodName(d);
            }
            break;
        }
        case 'd':
        case 'D':
        {
            if (lua_isnumber(s, stackIndex)) {
                lua_Number d = lua_tonumber(s, stackIndex);
                value = calloc(1, sizeof(double));
                *(double *)value = d;
            }
            break;
        }
        case 'q':
        case 'Q':
        {
            //FIXME: Big int is not supported yet, we always using lua int type.
            if (lua_isnumber(s, stackIndex)) {
                lua_Integer l = lua_tointeger(s, stackIndex);
                value = calloc(1, sizeof(long long));
                *(long long *)value = l;
            }
            break;
        }
        case 'B':
        {
            if (lua_isboolean(s, stackIndex)) {
                int l = lua_toboolean(s, stackIndex);
                value = calloc(1, sizeof(int));
                *(int *)value = l;
            }
            break;
            
        }
        case 's':
        case 'S':
        case 'c':
        case 'C':
        case 'i':
        case 'I':
        {
            if (lua_isnumber(s, stackIndex)) {
                lua_Integer l = lua_tointeger(s, stackIndex);
                value = calloc(1, sizeof(int));
                *(int *)value = (int)l;
            }
            break;
        }
        case '{':
        {
            int size = structBytesFromTypeDescription(targetType);
            void *stut = ((IndigoObjectUserdata *)lua_touserdata(s, stackIndex))->cptr;
            value = calloc(1, size);
            memcpy(value, stut, size);
            break;
        }
        case '^':
        {
            //it asks for a pointer parameter
            if (lua_isnil(s, stackIndex)) {
                value = calloc(1, sizeof(void **));
                *(id **)value = NULL;
            }
            else {
                //not implemented
                assert(0);
            }
            break;
        }
        default:
            break;
    }
    
    return value;
}

void push_object(lua_State *s, void *buffer, const char *type, bool isDeallocing)
{
    assert(buffer);
    const char *localType = type;
check:
    switch (localType[0]) {
        case 'N'://fall through
        {
            localType += 1;
            goto check;
        }
        case '@'://#define _C_ID       '@'
        {
            id obj = *(id *)buffer;
            
            if (!obj) {
                lua_pushnil(s);
                return;
            }
            
#if INDIGO_RIGOROUS_GC
            if (!isDeallocing) {
                [indigo_gc addObject:obj];
            }
#endif
            _object_push(s, obj, type, false);
            return;
        }
        case ':'://#define _C_SEL      ':'
        {
            SEL value= *(SEL *)buffer;
            lua_pushstring(s, sel_getName(value));
            return;
        }
        case '#':
        {
            Class klass = *(Class *)buffer;
            _object_push(s, (void *)klass, type, false);
            return;
        }
        case 'c'://#define _C_CHR      'c'
        case 'C'://#define _C_UCHR     'C'
        case 's'://#define _C_SHT      's'
        case 'S'://#define _C_USHT     'S'
        case 'i'://#define _C_INT      'i'
        case 'l'://#define _C_LNG      'l'
        case 'I'://#define _C_UINT     'I'
        case 'L'://#define _C_ULNG     'L'
        case 'q'://#define _C_LNG_LNG  'q'
        case 'Q'://#define _C_ULNG_LNG 'Q'
        {
            long value = *(long *)buffer;
            lua_pushinteger(s, value);
            return;
        }
        case 'f'://#define _C_FLT      'f'
        {
            float value = *(double*)buffer;
            lua_pushnumber(s, value);
            return;
        }
        case 'd'://#define _C_DBL      'd'
        {
            double value = *(double*)buffer;
            lua_pushnumber(s, value);
            return;
        }
        case 'B'://#define _C_BOOL     'B'
        {
            bool value = *(int*)buffer;
            lua_pushboolean(s, value);
            return;
        }
        case 'v'://#define _C_VOID     'v'
        {
            lua_pushnil(s);
            return;
        }
        case '*'://#define _C_CHARPTR  '*'
        {
            char *value = *(char **)buffer;
            _object_push(s, value, type, false);
            return;
        }
        case '{'://#define _C_STRUCT_B '{'
        {
            push_struct(s, buffer, type, false);
            return;
        }
        case '^'://#define _C_PTR      '^'
        {
            const char *realType = strstr(type, "^") + 1;
            if (realType[0] == '{') {
                push_struct(s, buffer, type, true);
            }
            else {
                _object_push(s, buffer, type, true);
            }
            return;
        }
        case '%':
        {
            _object_push(s, buffer, type, false);
            return;
        }
        default:
        {
            luaL_error(s, "[push_object] unknown type %s", type);
            break;
        }
    }
}

IndigoObjectUserdata *indigo_check_object_userdata(lua_State *s, int stackIndex)
{
    IndigoObjectUserdata *userdata = luaL_checkudata(s, stackIndex, INDIGO_OBJECT_METATABLE);
    return userdata;
}

void closure_capture_arguments_without_owner(lua_State *s, int functionIndex)
{
    int upvalueIndex = 1;
    const char *upvalueName = lua_getupvalue(s, functionIndex, upvalueIndex);
    while (upvalueName) {
        if (lua_isuserdata(s, -1)) {
            IndigoObjectUserdata *instance = lua_touserdata(s, -1);
            if (instance->ctype[0] == '@') {
                printf("block retain argument %p\n", instance->cptr);
                [(id)instance->cptr retain];
            }
        }
        
        lua_pop(s, 1);
        upvalueName = lua_getupvalue(s, functionIndex, ++upvalueIndex);
    }
}

void closure_release_arguments_without_owner(lua_State *s, int functionIndex)
{
    int upvalueIndex = 1;
    const char *upvalueName = lua_getupvalue(s, functionIndex, upvalueIndex);
    while (upvalueName) {
        if (lua_isuserdata(s, -1)) {
            IndigoObjectUserdata *instance = lua_touserdata(s, -1);
            if (instance->ctype[0] == '@') {
                printf("block release argument %p\n", instance->cptr);
                [(id)instance->cptr release];
            }
        }
        
        lua_pop(s, 1);
        upvalueName = lua_getupvalue(s, functionIndex, ++upvalueIndex);
    }
}

void closure_capture_arguments_owner(lua_State *s, int functionIndex, id owner)
{
    int upvalueIndex = 1;
    const char *upvalueName = lua_getupvalue(s, functionIndex, upvalueIndex);
    while (upvalueName) {
        if (lua_isuserdata(s, -1)) {
            IndigoObjectUserdata *instance = lua_touserdata(s, -1);
            if (instance->ctype[0] == '@') {
                printf("block retain argument %p\n", instance->cptr);
                objc_setAssociatedObject(owner, instance->cptr, (id)instance->cptr, OBJC_ASSOCIATION_RETAIN);
            }
        }
        
        lua_pop(s, 1);
        upvalueName = lua_getupvalue(s, functionIndex, ++upvalueIndex);
    }
}

#if INDIGO_RIGOROUS_GC
void dispose_instance(void *instance)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        lua_State *s = luaThread();
        
        _push_reg_table(s);
        
        lua_pushlightuserdata(s, instance);
        lua_pushnil(s);
        lua_rawset(s, -3);
        
        lua_pop(s, 1);
    });
}
#endif

#pragma mark - internal methods
/*only create userdata for object, class, pointer and struct*/
static void _object_push(lua_State *s, void *instance, const char *typeDescription, bool isPointer)
{
    
#ifdef INDIGO_RIGOROUS_GC
    lua_checkstack(s, 5);

    _push_reg_table(s);
    
    lua_pushlightuserdata(s, instance);
    lua_rawget(s, -2);
    
    if (!lua_isnil(s, -1)) {
        lua_remove(s, -2);//remove the instance register table
        //NSLog(@"[instance]->push:(cache) %p cptr: %p ctype: %s class: %s", lua_topointer(s, -1), instance, typeDescription, typeDescription[0]=='@'?class_getName([(id)instance class]):"none");
        return;
    }
    
    lua_pop(s, 1);
#else
    lua_checkstack(s, 3);
#endif

    IndigoObjectUserdata *userdata = lua_newuserdata(s, sizeof(IndigoObjectUserdata));
    
    //seems lua doesn't reset this newly allocated memory block
    memset(userdata, 0, sizeof(IndigoObjectUserdata));
    
    userdata->isPtr = isPointer;
    if (isPointer) {
        void **newPtr = calloc(1, sizeof(void *));
        memcpy(newPtr, instance, sizeof(void *));
        userdata->cptr = newPtr;
    }
    else {
        userdata->cptr = instance;
    }
    
    char *ctype = calloc(strlen(typeDescription) + 1, sizeof(char));
    memcpy(ctype, typeDescription, strlen(typeDescription));
    userdata->ctype = ctype;
    
    luaL_getmetatable(s, INDIGO_OBJECT_METATABLE);
    lua_setmetatable(s, -2);
    
#ifdef INDIGO_RIGOROUS_GC
    lua_pushlightuserdata(s, instance);
    lua_pushvalue(s, -2);
    lua_rawset(s, -4);
    
    lua_newtable(s);
    lua_setuservalue(s, -2);
    
    lua_remove(s, -2);//remove the instance register table
    
    lua_newtable(s);
    lua_setuservalue(s, -2);
#endif

    
#ifdef LOG_OBJECT_CREATION
    printf("instance new: %p cptr: %p ctype: %s class: %s\n", userdata, userdata->cptr, userdata->ctype, ctype[0]=='@'?class_getName([(id)instance class]):"none");
#endif
}

static int _closure_push(lua_State *L, id receiver, SEL selector, BOOL invokeAsSuper, BOOL isClassMethod)
{
    if (!receiver) {
        lua_pushnil(L);
        return 1;
    }
    
    if (object_isClass(receiver) && isInitSelector(selector)) {
        
#ifdef LOG_OBJECT_CREATION
        printf("lua auto alloc\n");
#endif
        //FIXME: we must make sure this object won't be dealloced before it gets an init message
        receiver = [[receiver alloc] autorelease];
    }
    
    /*
     it seems like that `methodSignatureForSelector:` will also search class methods
     */
    NSMethodSignature *signature = [receiver methodSignatureForSelector:selector];
    
    if (!signature) {
        luaL_error(L, "instance %s doesn't respond to selector: %s", [receiver description].UTF8String, selector);
        return 0;
    }
    
#ifdef LOG_OBJECT_CALL
    printf("lua call target: %s selector: %s\n", class_getName([receiver class]), sel_getName(selector));
#endif
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:receiver];
    [invocation setSelector:selector];
    
    lua_checkstack(L, 6);

    lua_pushlightuserdata(L, (void *)receiver);
    lua_pushlightuserdata(L, (void *)invocation);
    lua_pushlightuserdata(L, (void *)signature);
    lua_pushboolean(L, invokeAsSuper);
    lua_pushboolean(L, isClassMethod);
    
    lua_pushcclosure(L, _closure_run, 5);
    
    if ([signature numberOfArguments] == 2) {
        //if this method has no arguments, just call it
        if (LUA_OK != lua_pcall(L, 0, 1, 0)){
            luaL_error(L, "error call %s on %s", sel_getName(selector), receiver);
        }
    }
    
    return 1;
}

static int _closure_run(lua_State *s)
{
    lua_checkstack(s, 1);

    id receiver = (id)lua_touserdata(s, lua_upvalueindex(1));
    NSInvocation *invocation = (NSInvocation *)lua_touserdata(s, lua_upvalueindex(2));;
    NSMethodSignature *signature = (NSMethodSignature *)lua_touserdata(s, lua_upvalueindex(3));;
    bool asSuper = lua_toboolean(s, lua_upvalueindex(4));
//    bool isClassMethod = lua_toboolean(s, lua_upvalueindex(5));
    
    SEL selector = invocation.selector;
    Class klass = [receiver class];
    Class superClass = [receiver superclass];
    
    //handle array and dictionary initialization
    if (object_isClass(receiver) && [receiver isSubclassOfClass:[NSArray class]] && sel_isEqual(selector, @selector(arrayWithObjects:))) {
        int count = lua_gettop(s);
        id *objects = calloc(count, sizeof(id));
        for (int i=1; i<=count; ++i) {
            if (lua_isnumber(s, i)) {
                lua_Number n = lua_tonumber(s, i);
                objects[i-1] = @(n);
            }
            else if (lua_isstring(s, i)) {
                const char *str = lua_tostring(s, i);
                objects[i-1] = @(str);
            }
            else if (lua_isboolean(s, i)) {
                int n = lua_toboolean(s, i);
                objects[i-1] = @(n);
            }
            else if (lua_isuserdata(s, i)) {
                IndigoObjectUserdata *ud = indigo_check_object_userdata(s, i);
                objects[i-1] = (id)ud->cptr;
            }
            else {
                assert(0);
            }
        }
        NSArray *arr = [NSArray arrayWithObjects:objects count:count];
        push_object(s, &arr, @encode(NSArray *), false);
        free(objects);
        return 1;
    }
    
    if (object_isClass(receiver) && [receiver isSubclassOfClass:[NSDictionary class]] && sel_isEqual(selector, @selector(dictionaryWithObjectsAndKeys:))) {
        int count = lua_gettop(s)/2;
        id *keys = calloc(count, sizeof(id));
        id *values = calloc(count, sizeof(id));
        
        for (int i=0; i<count; i++) {
            id value = nil;
            if (lua_isnumber(s, 2*i+1)) {
                lua_Number n = lua_tonumber(s, 2*i+1);
                value = @(n);
            }
            else if (lua_isstring(s, 2*i+1)) {
                const char *str = lua_tostring(s, 2*i+1);
                value = @(str);
            }
            else if (lua_isboolean(s, 2*i+1)) {
                int n = lua_toboolean(s, 2*i+1);
                value = @(n);
            }
            else if (lua_isuserdata(s, 2*i+1)) {
                IndigoObjectUserdata *ud = indigo_check_object_userdata(s, 2*i+1);
                value = (id)ud->cptr;
            }
            values[i]=value;
            
            id key = nil;
            if (lua_isnumber(s, 2*i+2)) {
                lua_Number n = lua_tonumber(s, 2*i+2);
                key = @(n);
            }
            else if (lua_isstring(s, 2*i+2)) {
                const char *str = lua_tostring(s, 2*i+2);
                key = @(str);
            }
            else if (lua_isboolean(s, 2*i+2)) {
                int n = lua_toboolean(s, 2*i+2);
                key = @(n);
            }
            else if (lua_isuserdata(s, 2*i+2)) {
                IndigoObjectUserdata *ud = indigo_check_object_userdata(s, 2*i+2);
                key = (id)ud->cptr;
            }
            keys[i]=key;
        }
        
        NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys count:count];
        
        push_object(s, &dict, @encode(NSDictionary *), false);
        free(values);
        free(keys);
        return 1;
    }
    
    if (asSuper) {
        Method method = class_getInstanceMethod(klass, selector);
        Method superMethod = class_getInstanceMethod(superClass, selector);
        method_exchangeImplementations(method, superMethod);
    }
    
    int luaArgumentsCount = lua_gettop(s);
    int objcArgumentCount = (int)[signature numberOfArguments] - 2;
    if (luaArgumentsCount > objcArgumentCount) {
        luaL_error(s, "#argument not match, need %d, got %d", objcArgumentCount, luaArgumentsCount);
        return 0;
    }
    
    void **arguements = calloc(sizeof(void*), objcArgumentCount);
    for (int i = 0; i < objcArgumentCount; i++) {
        /*
          Here we set the invocation as the `owner` of this argument. When pushing block parameters,
          we need this owner info to retain and release the captured external variables. We should not
          consider the message receiver (the `caller`) as the owner because sometimes the receiver exists
          forever(such as +[UIView animateWithDuration:])!!!
         */
        arguements[i] = lua2oc(s, i + 1, [signature getArgumentTypeAtIndex:2 + i], (void *)invocation);
        [invocation setArgument:arguements[i] atIndex:i + 2];
    }
    
    @try {
        [invocation invoke];
    }
    @catch (NSException *exception) {
        luaL_error(s, "Error invoking method '%s' on '%s' because %s", selector, class_getName([receiver class]), [[exception description] UTF8String]);
    }
    
    for (int i = 0; i < objcArgumentCount; i++) {
        free(arguements[i]);
    }
    free(arguements);
    
    if (asSuper) {
        Method method = class_getInstanceMethod(klass, selector);
        Method superMethod = class_getInstanceMethod(superClass, selector);
        method_exchangeImplementations(method, superMethod);
    }
    
    NSUInteger methodReturnLength = [signature methodReturnLength];
    if (methodReturnLength == 0) {
        lua_pushnil(s);
        return 1;
    }
    
    const char *rt = [signature methodReturnType];
    void *buffer = calloc(1, methodReturnLength);
    [invocation getReturnValue:buffer];
    push_object(s, buffer, rt, false);
    
    free(buffer);
    return 1;
}


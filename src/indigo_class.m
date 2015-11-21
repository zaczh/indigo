//
//  indigo_class.m
//  indigo
//
//  Created by zhang on 8/2/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_class.h"
#include "indigo_helper.h"
#include <objc/runtime.h>
#include <objc/message.h>

#define INDIGO_CLASS_USERDATA_METATABLE "indigo_class_userdata_meta"
#define INDIGO_CLASS_METHOD_REG_KEY "indigo_class_userdata_reg"
#define INDIGO_INSTANCE_METHOD_REG_KEY "indigo_instance_userdata_reg"
#define INDIGO_LUA_THREAD_REG_KEY "indigo_lua_thread_reg"

//log control
#ifdef DEBUG
//#define LOG_CLASS_NEWINDEX
#endif

/* on arm64 devices, the argument passing convention has changed.
   We can no longer convert a variadic function to a fixed argument function.
   Many people think of this `message forwarding` to handle this problem.
   I have tried other ways (libffi) to handle this, but it's fruitless.
   So let's accept this since there is no better way.
 */
#define USING_MESSAGE_FORWARDING

#pragma mark - function prototypes
static BOOL isMethodReplacedByInvocation(id klass, SEL selector, BOOL isClassMethod);
static void replaceMethodAndGenerateORIG(id klass, SEL selector, BOOL isClassMethod, IMP newIMP);
static BOOL overrideMethodByInvocation(id klass, SEL selector, BOOL isClassMethod, char *typeDescription, char *returnType);
static BOOL addMethodByInvocation(id klass, SEL selector, BOOL isClassMethod, char * typeDescription) ;
static void hookForwardInvocation(id self, SEL sel, NSInvocation *anInvocation);
static int pcallUserdataARM64Invocation(lua_State *s, id self, SEL selector, NSInvocation *anInvocation);

static int indigo_class_index(lua_State *s);
static int indigo_class_newindex(lua_State *s);


static int objcClass(lua_State *s);

int _pushInstanceMethodTable(lua_State *L, Class cls);
int _pushClassMethodTable(lua_State *L, Class cls);

extern void *lua2oc(lua_State *s, int stackIndex, const char *toType, void *owner);
extern void push_object(lua_State *s, void *buffer, const char *typeDescription, bool isDeallocing);
extern bool check_class_struct_in_current_context(void *ptr);

@interface NSThread (Indigo)
- (lua_State *)luaState;
- (void)setLuaState:(lua_State *)state;
@end

@implementation NSThread (Indigo)
static char *kLuaStateProperty;
- (lua_State *)luaState
{
    NSValue *value = objc_getAssociatedObject(self, &kLuaStateProperty);
    lua_State *state = (lua_State *)value.pointerValue;
    return state;
}

- (void)setLuaState:(lua_State *)luaState
{
    NSValue *value = [NSValue valueWithPointer:(void *)luaState];
    objc_setAssociatedObject(self, &kLuaStateProperty, value, OBJC_ASSOCIATION_ASSIGN);
}
@end

static lua_State *mainThread;
void bindMainLuaThread(lua_State *s)
{
    assert([NSThread isMainThread]);
    
    if (!mainThread) {
        mainThread = s;
        [NSThread currentThread].luaState = s;
    }
    else {
        printf("main thread has already been set\n");
    }
}

lua_State *luaThread()
{
    if ([NSThread isMainThread]) {
        return [NSThread currentThread].luaState;
    }
    
    lua_State * __block s = [NSThread currentThread].luaState;
    if (!s) {
        dispatch_barrier_sync(dispatch_get_main_queue(), ^{
            lua_State *m = [NSThread currentThread].luaState;
            if (!m) {
                printf("main lua thread not set, set it using `bindMainLuaThread`\n");
            }
            else {
                luaL_getsubtable(m, LUA_REGISTRYINDEX, INDIGO_LUA_THREAD_REG_KEY);
                lua_pushlightuserdata(m, (__bridge void *)[NSThread currentThread]);
                lua_rawget(m, -2);
                
                if (!lua_isnil(m, -1)) {
                    s = lua_tothread(m, -1);
                    lua_pop(m, 2);
                }
                else {
                    lua_pop(m, 1);
                    lua_pushlightuserdata(m, (__bridge void *)[NSThread currentThread]);
                    s = lua_newthread(m);
                    lua_rawset(m, -3);
                    lua_pop(m, 1);
                }
            }
        });
    }
    
    return s;
}

static const struct luaL_Reg class_meta_functions[] = {
    {"__index", indigo_class_index},
    {"__newindex", indigo_class_newindex},
    {NULL, NULL}
};

static const struct luaL_Reg class_global_functions[] = {
    {"objcClass", objcClass},
    
    {NULL, NULL}
};

int luaopen_indigo_class(lua_State *L)
{    
    luaL_newmetatable(L, INDIGO_CLASS_USERDATA_METATABLE);
    luaL_setfuncs(L, class_meta_functions, 0);
    lua_pop(L, 1);
    
    //set globals
    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    luaL_setfuncs(L, class_global_functions, 0);
    lua_pop(L, 1);
    
    return 1;
}

#pragma mark - class meta functions
static int indigo_class_index(lua_State *s)
{
    assert(lua_isstring(s, -1));
    const char *functionName = lua_tostring(s, -1);
    if (!strcmp(functionName, "class")) {
        IndigoClassStruct *classStruct = (IndigoClassStruct *)luaL_checkudata(s, 1, INDIGO_CLASS_USERDATA_METATABLE);
        classStruct->isInClassMethodContext = true;
        lua_pushvalue(s, 1);
        return 1;
    }
    
    return 1;
}

static int indigo_class_newindex(lua_State *s)
{
    IndigoClassStruct *classStruct = (IndigoClassStruct *)luaL_checkudata(s, -3, INDIGO_CLASS_USERDATA_METATABLE);
    Class klass = classStruct->cls;
    Class superCls = classStruct->superCls;
    bool isClassMethod = classStruct->isInClassMethodContext;
    
    if (!check_class_struct_in_current_context(classStruct)) {
        luaL_error(s, "The class you add method on is not in current indigo context. You may have written the class name wrongly");
    }
    
#ifdef LOG_CLASS_NEWINDEX
    bool isCategory = classStruct->isInCategoryContext;
    printf("indigo_class_newindex: %s (%p) isCategory: (%d) isClass: (%d) \n", lua_tostring(s, -2), lua_topointer(s, -1), isCategory, isClassMethod);
#endif
    
    assert(lua_isfunction(s, -1));
    const char *methodName = lua_tostring(s, -2);
    
    if (isClassMethod) {
        _pushClassMethodTable(s, klass);
    }
    else {
        _pushInstanceMethodTable(s, klass);
    }
    
    //store this method in lua enviroment
    lua_pushvalue(s, -3);
    lua_pushvalue(s, -3);
    lua_settable(s, -3);
    lua_settop(s, -2);
    
    SEL selector = objcSelectorFromLuaMethodName(methodName);
    
    char *typeDescription = nil;
    char *returnType = nil;
    
    Method method = class_getInstanceMethod(isClassMethod?superCls:klass, selector);
    if (method) { // Is method defined in the superclass?
        typeDescription = (char *)method_getTypeEncoding(method);
        returnType = method_copyReturnType(method);
    }
    else { // Is this method implementing a protocol?
        Class currentClass = klass;
        
        while (!returnType && [currentClass superclass] != [currentClass class]) { // Walk up the object heirarchy
            uint count;
            Protocol *__unsafe_unretained *protocols = class_copyProtocolList(currentClass, &count);
            
            for (int i = 0; !returnType && i < count; i++) {
                Protocol *protocol = protocols[i];
                struct objc_method_description m_description;
                m_description = protocol_getMethodDescription(protocol, selector, YES, YES);
                if (!m_description.name) m_description = protocol_getMethodDescription(protocol, selector, NO, YES); // Check if it is not a "required" method
                
                if (m_description.name) {
                    typeDescription = m_description.types;
                    returnType = method_copyReturnType((Method)&m_description);
                }
            }
            
            free(protocols);
            
            currentClass = [currentClass superclass];
        }
    }
    
    if (returnType) {
        overrideMethodByInvocation(klass, selector, isClassMethod, typeDescription,returnType);
    }
    else {
        int argCount = 0;
        char *match = (char *)sel_getName(selector);
        while ((match = strchr(match, ':'))) {
            match += 1; // Skip past the matched char
            argCount++;
        }
        
        size_t typeDescriptionSize = 3 + argCount;
        typeDescription = calloc(typeDescriptionSize + 1, sizeof(char));
        memset(typeDescription, '@', typeDescriptionSize);//default id
        typeDescription[2] = ':'; // Never forget _cmd!
        
        addMethodByInvocation(klass, selector, isClassMethod, typeDescription);
        
        free(typeDescription);
    }

    free(returnType);
    
    if (isClassMethod) {
        classStruct->isInClassMethodContext = false;
    }
    return 0;
}


static SEL getORIGSelector(SEL selector){
    const char *selectorName = sel_getName(selector);
    char newSelectorName[strlen(selectorName) + 10];
    strcpy(newSelectorName, "ORIG");
    strcat(newSelectorName, selectorName);
    SEL newSelector = sel_getUid(newSelectorName);
    return newSelector;
}

//because i don't want to use extra dictionary to store this infomation, so judge it by _objc_msgForward or _objc_msgForward_stret
static BOOL isMethodReplacedByInvocation(id klass, SEL selector, BOOL isClassMethod){
    Method selectorMethod = class_getInstanceMethod(klass, selector);
    IMP imp = method_getImplementation(selectorMethod);
#if defined(__arm64__)
    return imp == _objc_msgForward;
#else
    return imp == _objc_msgForward || imp == (IMP)_objc_msgForward_stret;
#endif
}

static void replaceMethodAndGenerateORIG(id klass, SEL selector, BOOL isClassMethod, IMP newIMP){
    Method selectorMethod = class_getInstanceMethod(isClassMethod?class_getSuperclass(klass):klass, selector);
    const char *typeDescription =  method_getTypeEncoding(selectorMethod);
    
    IMP prevImp = class_replaceMethod(isClassMethod?class_getSuperclass(klass):klass, selector, newIMP, typeDescription);
    if(prevImp == newIMP){
        //        NSLog(@"Repetition replace but, never mind");
        return ;
    }
    
    const char *selectorName = sel_getName(selector);
    char newSelectorName[strlen(selectorName) + 10];
    strcpy(newSelectorName, "ORIG");
    strcat(newSelectorName, selectorName);
    SEL newSelector = sel_getUid(newSelectorName);
    if(!class_respondsToSelector(isClassMethod?class_getSuperclass(klass):klass, newSelector)) {
        class_addMethod(isClassMethod?class_getSuperclass(klass):klass, newSelector, prevImp, typeDescription);
    }
}

static void hookForwardInvocation(id self, SEL sel, NSInvocation *anInvocation){
    //    NSLog(@"self=%@ sel=%s", self, anInvocation.selector);
    //    NSLog(@"Fun:%s Line:%d", __PRETTY_FUNCTION__, __LINE__);
    BOOL isClassMethod = class_isMetaClass(object_getClass(self));
    assert(!isClassMethod);
    if(isMethodReplacedByInvocation(object_getClass(self), anInvocation.selector, isClassMethod)){//instance->class, class->metaClass
        //        NSLog(@"Fun:%s Line:%d", __PRETTY_FUNCTION__, __LINE__);
        lua_State *L = [NSThread currentThread].luaState;
        int result = pcallUserdataARM64Invocation(L, self, anInvocation.selector, anInvocation);
        if (result == -1) {//error
            luaL_error(L, "Error calling '%s' on '%s'\n%s", anInvocation.selector, [[self description] UTF8String], lua_tostring(L, -1));
        }
        else if (result == 1) {//have return value
            NSMethodSignature *signature = [self methodSignatureForSelector:anInvocation.selector];
            void *pReturnValue = lua2oc(L, -1, [signature methodReturnType], NULL);
            [anInvocation setReturnValue:pReturnValue];
            free(pReturnValue);
        }
    }else{//cal original forwardInvocation method
        ((void(*)(id, SEL, id))objc_msgSend)(self, getORIGSelector(@selector(forwardInvocation:)), anInvocation);
    };
}

//64 solve 1:instance method go Invocation
static int pcallUserdataARM64Invocation(lua_State *L, id self, SEL selector, NSInvocation *anInvocation) {
    
//    if (![[NSThread currentThread] isEqual:[NSThread mainThread]]) printf("PCALLUSERDATA: OH NO SEPERATE THREAD\n");
    
    // Find the function... could be in the object or in the class
    _pushInstanceMethodTable(L, [self class]);
    char *luaName = luaMethodNameFromSelector(selector);
    lua_pushstring(L, luaName);
    free(luaName);
    lua_rawget(L, -2);
    
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        //maybe it's a class method
        _pushClassMethodTable(L, [self class]);
        char *luaName = luaMethodNameFromSelector(selector);
        lua_pushstring(L, luaName);
        free(luaName);
        lua_rawget(L, -2);
    }
    
    assert(lua_type(L, -1) == LUA_TFUNCTION);

//    if (!wax_instance_pushFunction(L, self, selector)) {
//        lua_pushfstring(L, "Could not find function named \"%s\" associated with object %s(%p).(It may have been released by the GC)", selector, class_getName([self class]), self);
//        goto error; // function not found in userdata...
//    }
    
    bool isDeallocing = sel_isEqual(selector, @selector(dealloc));
    // Push userdata as the first argument
    push_object(L, &self, @encode(id), isDeallocing);
    
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSUInteger nargs = [signature numberOfArguments] - 1; // Don't send in the _cmd argument, only self
    int nresults = [signature methodReturnLength] ? 1 : 0;
    
    for (NSUInteger i = 2; i < [signature numberOfArguments]; i++) { // start at 2 because to skip the automatic self and _cmd arugments
        const char *type = [signature getArgumentTypeAtIndex:i];
        NSUInteger size = 0;
        NSGetSizeAndAlignment(type, &size, NULL);
        
        void *buffer = malloc(size);
        [anInvocation getArgument:buffer atIndex:i];
        
        push_object(L, buffer, type, isDeallocing);
        free(buffer);
    }
    
    if (LUA_OK != lua_pcall(L, (int)nargs, nresults, 0)) { // Userdata will allways be the first object sent to the function
        luaL_error(L, lua_tostring(L, -1));
    }
    
    lua_remove(L, -1-nresults);
    return nresults;
}

static BOOL overrideMethodByInvocation(id klass, SEL selector, BOOL isClassMethod, char *typeDescription, char *returnType) {
    IMP forwardImp = _objc_msgForward;
#if !defined(__arm64__)
    if(strlen(returnType) > 0 && returnType[0] == '{'){//return struct
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeDescription];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            forwardImp = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    
    replaceMethodAndGenerateORIG(klass, selector, isClassMethod, forwardImp);//trigger forwardInvocation
    
    if(!isMethodReplacedByInvocation(klass, @selector(forwardInvocation:), isClassMethod)){//just replace once
        
        replaceMethodAndGenerateORIG(klass, @selector(forwardInvocation:), isClassMethod, (IMP)hookForwardInvocation);
    }
    return YES;
}

static BOOL addMethodByInvocation(id klass, SEL selector, BOOL isClassMethod, char * typeDescription) {
    class_addMethod(klass, selector, _objc_msgForward, typeDescription);//for isMethodReplacedByInvocation
    
    if(!isMethodReplacedByInvocation(klass, @selector(forwardInvocation:), isClassMethod)){//just replace once
        
        replaceMethodAndGenerateORIG(klass, @selector(forwardInvocation:), isClassMethod, (IMP)hookForwardInvocation);
    }
    return YES;
}

#pragma mark - public methods

static int objcClass(lua_State *s)
{
    const char *className = luaL_checkstring(s, 1);
    
    Class klass = objc_getClass(className);
    if (!klass) {
        luaL_error(s, "no class named `%s` was loaded", className);
    }
    
    push_object(s, &klass, @encode(Class), false);
    
    return 1;
}



IndigoClassStruct *indigo_check_class_userdata(lua_State *s, int index)
{
    IndigoClassStruct *classStruct = (IndigoClassStruct *)luaL_checkudata(s, index, INDIGO_CLASS_USERDATA_METATABLE);
    return classStruct;
}

IndigoClassStruct *indigo_pushClassUserdata(lua_State *L, Class cls, bool isClassMethodContext, bool isInCategoryContext)
{
    lua_checkstack(L, 4);
    lua_pushlightuserdata(L, (__bridge void *)cls);
    lua_gettable(L, LUA_REGISTRYINDEX);
    if (!lua_isnil(L, -1)) {
        IndigoClassStruct *classStruct = (IndigoClassStruct *)luaL_checkudata(L, -1, INDIGO_CLASS_USERDATA_METATABLE);
        classStruct->isInClassMethodContext = isClassMethodContext;
        classStruct->isInCategoryContext = isInCategoryContext;
    }
    lua_pop(L, 1);
    
    IndigoClassStruct *classStruct = (IndigoClassStruct *)lua_newuserdata(L, sizeof(IndigoClassStruct));
    memset(classStruct, 0, sizeof(IndigoClassStruct));
    luaL_setmetatable(L, INDIGO_CLASS_USERDATA_METATABLE);
    classStruct->cls = cls;
    classStruct->superCls = class_getSuperclass(cls);
    classStruct->isInClassMethodContext = isClassMethodContext;
    classStruct->isInCategoryContext = isInCategoryContext;
    
    lua_pushlightuserdata(L, (__bridge void *)cls);//key
    lua_pushvalue(L, -2);//value
    lua_settable(L, LUA_REGISTRYINDEX);
    
    return classStruct;
}

int _pushInstanceMethodTable(lua_State *L, Class cls)
{
    lua_checkstack(L, 4);
    luaL_getsubtable(L, LUA_REGISTRYINDEX, INDIGO_INSTANCE_METHOD_REG_KEY);
    lua_pushlightuserdata(L, (__bridge void *)cls);
    lua_rawget(L, -2);
    
    if (!lua_isnil(L, -1)) {
        lua_remove(L, -2);
        return 1;
    }
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushlightuserdata(L, (__bridge void *)cls);
    lua_pushvalue(L, -2);
    lua_rawset(L, -4);
    lua_remove(L, -2);
    
    return 1;
}

int _pushClassMethodTable(lua_State *L, Class cls)
{
    lua_checkstack(L, 4);
    luaL_getsubtable(L, LUA_REGISTRYINDEX, INDIGO_CLASS_METHOD_REG_KEY);
    lua_pushlightuserdata(L, (__bridge void *)cls);
    lua_rawget(L, -2);
    
    if (!lua_isnil(L, -1)) {
        lua_remove(L, -2);
        return 1;
    }
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushlightuserdata(L, (__bridge void *)cls);
    lua_pushvalue(L, -2);
    lua_rawset(L, -4);
    lua_remove(L, -2);
    
    return 1;
}



//
//  indigo.c
//  indigo
//
//  Created by zhang on 7/26/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_engine.h"

#import "indigo_class.h"
#import "indigo_object.h"
#import "indigo_helper.h"
#import "indigo_gc.h"
#import "indigo_block.h"
#import "indigo_debug.h"
#import "indigo_struct.h"
#import "indigo_cbridge.h"

#include <objc/runtime.h>
#include <objc/message.h>

@interface IndigoEngine ()
@property (nonatomic) lua_State *luaState;
@property (nonatomic) IndigoClassStruct *operatingClassStruct;
@end

#define INDIGO_ENGINE_METATABLE "indigo_engine.meta"

extern int probe(lua_State *s);
extern int luaPrint(lua_State *s);
extern lua_State *luaThread();

static int engine_class(lua_State *L);
static int engine_extension(lua_State *L);
static int engine_finish(lua_State *L);
static int engine_property(lua_State *L);

static id getter_imp(id self, SEL cmd);
static void setter_imp(id self, SEL cmd, id value);

//key-value compliance
id valueForKey_(id self, SEL cmd, id key);
id valueForKeyPath_(id self, SEL cmd, id key);
void setValue_forKey_(id self, SEL cmd, id value, id key);
void setValue_forKeyPath_(id self, SEL cmd, id value, id key);
void setNilValueForKey_(id self, SEL cmd, id key);
id valueForUndefinedKey_(id self, SEL cmd, id key);
void setValue_forUndefinedKey_(id self, SEL cmd, id value, id key);

#pragma mark - getter && setter
static id getter_imp(id slf, SEL sel)
{
    const char *propertyName = objcPropertyFromGetter(sel);
    char *ivarName = objcIvarNameFromPropertyName(propertyName);
    Ivar ivar = class_getInstanceVariable(object_getClass(slf), ivarName);
    
    if (!ivar) {
        NSString *reason = [NSString stringWithFormat:@"class `%s` does not have a property named `%s`", class_getName([slf class]), propertyName];
        NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
        [exception raise];
        free(ivarName);
        return nil;
    }
    
    id value = object_getIvar(slf, ivar);
    free(ivarName);
    
    return [[value retain] autorelease];
}

static void setter_imp(id slf, SEL sel, id newValue)
{
    [newValue retain];
    char *propertyName = objcPropertyFromSetter(sel);
    char *ivarName = objcIvarNameFromPropertyName(propertyName);
    Ivar ivar = class_getInstanceVariable(object_getClass(slf), ivarName);
    
    if (!ivar) {
        [newValue release];
        NSString *reason = [NSString stringWithFormat:@"class `%s` does not have a property named `%s`", class_getName([slf class]), propertyName];
        NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
        [exception raise];
        
        free(ivarName);
        free(propertyName);
        return;
    }
    
    id oldValue = object_getIvar(slf, ivar);
    [oldValue release];
    object_setIvar(slf, ivar, newValue);
    
    free(ivarName);
    free(propertyName);
}

#pragma mark - key-value compliance
id valueForKey_(id self, SEL cmd, id key)
{
    if (objcSelectorIsLikelyAGetter(cmd)) {
        const char *property = objcPropertyFromGetter(cmd);
        if (classHasProperty([self class], property)) {
            return getter_imp(self, cmd);
        }
    }
    
    id undefinedReturn = valueForUndefinedKey_(self, cmd, key);
    return undefinedReturn;
}

id valueForKeyPath_(id self, SEL cmd, id key)
{
    //not implemented yet
    return nil;
}

void setValue_forKey_(id self, SEL cmd, id value, id key)
{
    if (objcSelectorIsLikelyASetter(cmd)) {
        setter_imp(self, cmd, value);
    }
    else {
        setValue_forUndefinedKey_(self, cmd, value, key);
    }
}

void setValue_forKeyPath_(id self, SEL cmd, id value, id key)
{
    //not implemented yet
}

void setNilValueForKey_(id self, SEL cmd, id key)
{
    setValue_forKey_(self, cmd, nil, key);
}

id valueForUndefinedKey_(id self, SEL cmd, id key)
{
    NSException *exception = [NSException exceptionWithName:@"KeyUndefinedException" reason:[NSString stringWithFormat:@"property: %@ not found", key] userInfo:nil];
    @throw exception;
}

void setValue_forUndefinedKey_(id self, SEL cmd, id value, id key)
{
    NSException *exception = [NSException exceptionWithName:@"KeyUndefinedException" reason:[NSString stringWithFormat:@"property: %@ not found", key] userInfo:nil];
    @throw exception;
}


static int engine_class(lua_State *L)
{
    const char *className = luaL_checkstring(L, 1);
    const char *superClassName = lua_isnoneornil(L, 2)?NULL:luaL_checkstring(L, 2);
    
    Class klass = objc_getClass(className);
    if (klass) {
        IndigoClassStruct *classStruct = indigo_pushClassUserdata(L, klass, false, false);
        [IndigoEngine sharedEngine].operatingClassStruct = classStruct;
        
        //also set the class as global
        lua_pushvalue(L, -1);
        lua_setglobal(L, className);
        
        return 1;
    }
    
    Class superClass;
    if (!superClassName) superClass = [NSObject class];
    else superClass = objc_getClass(superClassName);
    
    if (!superClass) {
        luaL_error(L, "Failed to create '%s'. Unknown superclass \"%s\" received.", className, superClassName);
    }
    
    klass = objc_allocateClassPair(superClass, className, 0);
    NSUInteger size;
    NSUInteger alignment;
    NSGetSizeAndAlignment("*", &size, &alignment);
    
    // Make Key-Value complient
    class_addMethod(klass, @selector(valueForKey:), (IMP)valueForKey_, "@@:@");
    class_addMethod(klass, @selector(valueForKeyPath:), (IMP)valueForKeyPath_, "@@:@");
    class_addMethod(klass, @selector(setValue:forKey:), (IMP)setValue_forKey_, "v@:@@");
    class_addMethod(klass, @selector(setValue:forKeyPath:), (IMP)setValue_forKeyPath_, "v@:@@");
    class_addMethod(klass, @selector(setNilValueForKey:), (IMP)setNilValueForKey_, "v@:@");
    class_addMethod(klass, @selector(valueForUndefinedKey:), (IMP)valueForUndefinedKey_, "@@:@");
    class_addMethod(klass, @selector(setValue:forUndefinedKey:), (IMP)setValue_forUndefinedKey_, "v@:@@");
    
    if (lua_istable(L, 3)) {
        size_t len = lua_rawlen(L, 3);
        for (int i=1; i<=len; ++i) {
            lua_rawgeti(L, 3, i);
            const char *protocolName = lua_tostring(L, -1);
            
            Protocol *protocol = objc_getProtocol(protocolName);
            if (!class_addProtocol(klass, protocol)) {
                printf("[info] add protocol `%s` to class `%s` failed. Maybe this class already conforms to the protocol?\n", protocolName, className);
            }
            
            lua_pop(L, 1);
        }
    }
    
    IndigoClassStruct *classStruct = indigo_pushClassUserdata(L, klass, false, false);
    [IndigoEngine sharedEngine].operatingClassStruct = classStruct;
    
    //also set the class as global
    lua_pushvalue(L, -1);
    lua_setglobal(L, className);
    
    return 1;
}

static int engine_extension(lua_State *s)
{
    const char *className = luaL_checkstring(s, 1);
    //const char *categoryName = lua_isnoneornil(L, 2)?NULL:luaL_checkstring(L, 2);
    Class klass = objc_getClass(className);
    
    if (!klass) {
        printf("no class named %s was loaded\n", className);
        return 0;
    }
    
    IndigoClassStruct *classStruct = indigo_pushClassUserdata(s, klass, false, true);
    [IndigoEngine sharedEngine].operatingClassStruct = classStruct;
    
    //also set the class as global
    lua_pushvalue(s, -1);
    lua_setglobal(s, className);
    
    return 1;
}

static int engine_property(lua_State *s)
{
    IndigoClassStruct *classStruct = [IndigoEngine sharedEngine].operatingClassStruct;
    Class klass = classStruct->cls;
    
    if (!lua_istable(s, -1)) {
        return 0;
    }
    
    lua_pushstring(s, "name");
    lua_rawget(s, -2);
    const char *propertyName = lua_tostring(s, -1);
    lua_pop(s, 1);
    
    lua_pushstring(s, "type");
    lua_rawget(s, -2);
    const char *typeName = lua_tostring(s, -1);
    (void)typeName;//not used now
    lua_pop(s, 1);
    
    
    //NSLog(@"[indigo] add property `%s` to class `%s`", propertyName, class_getName(klass));
    
    objc_property_attribute_t propertyAttrList[] ={{"T", "@\"NSObject\""},{"R", ""},{"C", ""}};
    if (!class_addProperty(klass, propertyName, propertyAttrList, 3)) {
        luaL_error(s, "add property: %s to class: %s failed. Maybe this class already has the property?", propertyName, class_getName(klass));
    }
    
    SEL getter = objcGetterForProperty(propertyName);
    SEL setter = objcSetterForProperty(propertyName);
    
    if (!class_addMethod(klass, getter, (IMP)getter_imp, "@@:")) {
        luaL_error(s, "add getter method for property :%s on class: %s failed. Maybe this class already has the property?", propertyName, class_getName(klass));
    }
    
    if (!class_addMethod(klass, setter, (IMP)setter_imp, "v@:@")) {
        luaL_error(s, "add setter method for property :%s on class: %s failed. Maybe this class already has the property?", propertyName, class_getName(klass));
    }
    
    char *ivarName = objcIvarNameFromPropertyName(propertyName);
    char *idEncoding = @encode(id);
    NSUInteger idSize, idAlign;
    NSGetSizeAndAlignment(idEncoding, &idSize, &idAlign);
    if (!class_addIvar(klass, ivarName, idSize, idAlign, idEncoding)) {
        luaL_error(s, "add setter method for property :%s on class: %s failed. Maybe this class already has the property?", propertyName, class_getName(klass));
    }
    free(ivarName);
    
    return 0;
}

static int engine_finish(lua_State *s)
{
    IndigoClassStruct *classStruct = [IndigoEngine sharedEngine].operatingClassStruct;
    Class klass = classStruct->cls;
    
    
    if (!classStruct->isInCategoryContext) {
        //creating class done
        objc_registerClassPair(klass);
    }
    
    //NOTE: non-public API here!!!
    luaL_getsubtable(s, LUA_REGISTRYINDEX, "_LOADED");
    if (lua_isnil(s, -1) || !lua_istable(s, -1)) {
        printf("package.loaded is nil\n");
        lua_pop(s, 1);
    }
    else {
        const char *className = class_getName(klass);
        lua_pushstring(s, className);
        push_object(s, &klass, @encode(Class), false);
        lua_settable(s, -3);
        lua_pop(s, 1);
    }
    
    //reset
    classStruct->isInCategoryContext = false;
    
    [IndigoEngine sharedEngine].operatingClassStruct = nil;
    
    return 0;
}

static const struct luaL_Reg engineGlobalFunctions[] = {
    {"class", engine_class},
    {"extension", engine_extension},
    {"finish", engine_finish},
    {"property", engine_property},
    {NULL, NULL}
};

#pragma mark - the module portal
int luaopen_indigo_engine(lua_State *L)
{
    luaL_newmetatable(L, INDIGO_ENGINE_METATABLE);
    
    //set globals
    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    luaL_setfuncs(L, engineGlobalFunctions, 0);
    
    return 1;
}

#pragma mark - objc public methods
@implementation IndigoEngine
+ (instancetype)sharedEngine
{
    static id sharedEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEngine = [[self alloc] init];
    });
    
    return sharedEngine;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        lua_State *L = luaL_newstate();
        luaL_openlibs(L);
        
        luaL_requiref(L, "indigo", luaopen_indigo_engine, 1);
        lua_pop(L, 1);
        
        luaL_requiref(L, "indigo.object", luaopen_indigo_object, 0);
        lua_pop(L, 1);
        
        luaL_requiref(L, "indigo.class", luaopen_indigo_class, 0);
        lua_pop(L, 1);
        
        luaL_requiref(L, "indigo.debug", luaopen_indigo_debug, 0);
        lua_pop(L, 1);
        
        luaL_requiref(L, "indigo.struct", luaopen_indigo_struct, 0);
        lua_pop(L, 1);
        
        luaL_requiref(L, "indigo.cbridge", luaopen_indigo_cbridge, 0);
        lua_pop(L, 1);

#if INDIGO_RIGOROUS_GC
        [indigo_gc start];
#endif
        
        self.luaState = L;
        
        bindMainLuaThread(L);
    }
    return self;
}

- (int)runScriptAtPath:(NSString *)filePath
{
    assert(filePath);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:filePath isDirectory:&isDirectory]) {
        if (isDirectory) printf("The script file path: %s is a directory\n", filePath.UTF8String);
        else printf("File does not exist at path: %s\n", filePath.UTF8String);
        return 0;
    }
    
    NSError *readFileError = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&readFileError];
    if (readFileError) {
        printf("Read file error! file path: %s\n", filePath.UTF8String);
        return 0;
    }
    
//    NSString *initScript = [NSString stringWithFormat:@"%@ %@",
//    @"setmetatable(_G, { "
//        "__index = function(self, key) "
//            "local class = objcClass(key) "
//            "if class then self[key] = class elseif key:match(\"^[A-Z][A-Z][A-Z][^A-Z]\") then print(\"WARNING: No object named \" .. key .. \" found.\") end "
//            "return class "
//        "end})", fileContents];
    
    int ret = luaL_dostring(self.luaState, fileContents.UTF8String);
    
    if (ret != 0) {
        const char *error = lua_tostring(self.luaState, -1);
        if (error) {
            printf("run script file: %s error, description: %s\n", filePath.UTF8String, error);
        }
    }
    
    return ret;
}

- (void)dealloc
{
    lua_close(self.luaState);
    self.luaState = NULL;
    [super dealloc];
}

@end

#pragma mark - export function

//show error when you declare a class method for class not in current context(You have mistaken the class name)
bool check_class_struct_in_current_context(void *ptr)
{
    return [IndigoEngine sharedEngine].operatingClassStruct == ptr;
}

//show error when you write a wrong class name when declare a class.
bool check_no_unknown_class_in_creation_context()
{
    return [IndigoEngine sharedEngine].operatingClassStruct == NULL;
}
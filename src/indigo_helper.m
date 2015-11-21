//
//  indigo_helper.m
//  indigo
//
//  Created by zhang on 8/1/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import "indigo_helper.h"

#include <objc/runtime.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <string.h>

char *const luaMethodNameFromSelector(SEL selector)
{
    if (!selector) {
        return NULL;
    }
    
    const char *objcName = sel_getName(selector);
    char *luaName = (char *)calloc(strlen(objcName) + 1, sizeof(char));
    int i=0;
    while (objcName[i]) {
        if (objcName[i] != ':') {
            luaName[i] = objcName[i];
        }
        else {
            luaName[i] = '_';
        }
        
        ++i;
    }
    
    return luaName;
}

//the return value should be freed after use
char *objcMethodNameFromLuaMethodName(const char *luaName)
{
    assert(luaName);
    
    if (strlen(luaName) == 0) return NULL;
    
    char *strippedMethodName = calloc(strlen(luaName) + 1, sizeof(char));
    //replace double underscore
    for (int i = 0, j = 0; i < strlen(luaName);) {
        if (luaName[i] == '_') {
            if ((i+1 < strlen(luaName)) && luaName[i+1] == '_') {
                strippedMethodName[j++] = '_';
                i += 2;
            }
            else {
                strippedMethodName[j++] = ':';
                i++;
            }
        }
        else {
            strippedMethodName[j++]=luaName[i];
            i++;
        }
    }
    
    return strippedMethodName;
}

SEL objcSelectorFromLuaMethodName(const char *luaName)
{
    assert(luaName);
    
    if (strlen(luaName) == 0) return NULL;
    
    char *strippedMethodName = objcMethodNameFromLuaMethodName(luaName);
    SEL selector = sel_registerName(strippedMethodName);
    free(strippedMethodName);
    return selector;
}

SEL objcSetterForProperty(const char *propertyName)
{
    assert(propertyName && strlen(propertyName) > 0);
    char *methodName = (char *)calloc(strlen(propertyName) + 5, sizeof(char));
    strcpy(methodName, "set");
    if (propertyName[0] >= 'a' && propertyName[0] <= 'z') {
        methodName[3] = propertyName[0] - ('a'- 'A');
    }
    else if (propertyName[0] >= 'A' && propertyName[0] <= 'Z') {
        methodName[3] = propertyName[0];
    }
    
    if (strlen(propertyName) > 1) {
        strcpy(methodName + 4, propertyName + 1);
    }
    methodName[strlen(methodName)] = ':';//add last colon
    
    SEL selector = sel_getUid(methodName);
    free(methodName);
    
    return selector;
}

SEL objcGetterForProperty(const char *propertyName)
{
    assert(propertyName && strlen(propertyName) > 0);
    SEL selector = sel_getUid(propertyName);
    return selector;
}

char *objcPropertyFromSetter(SEL setter)
{
    const char *methodName = sel_getName(setter);
    assert(strlen(methodName) > 0);
    if (strlen(methodName) < 4) {
        return NULL;
    }
    
    char *propertyName = (char *)calloc(strlen(methodName) - 3, sizeof(char));
    for (long i=0; i<strlen(methodName)-1; ++i) {
        if (i == 3) {
            propertyName[i-3] = methodName[i] + 'a' - 'A';
        }
        else if (i > 3) {
            propertyName[i-3] = methodName[i];
        }
    }
    
    return propertyName;
}

const char *objcPropertyFromGetter(SEL setter)
{
    return sel_getName(setter);
}

char *objcIvarNameFromPropertyName(const char *propertyName)
{
    char *name = calloc(strlen(propertyName) + 2, sizeof(char));
    name[0] = '_';
    strcpy(name+1, propertyName);
    
    return name;
}

BOOL objcSelectorIsLikelyAGetter(SEL selector)
{
    const char *methodName = sel_getName(selector);
    assert(strlen(methodName) > 0);
    
    //I assume that the getter begins with a lower-case letter
    if (methodName[0] > 'z' || methodName[0] < 'a') return NO;

    for (long i = strlen(methodName) - 1; i >= 0; --i) {
        if (methodName[i] == ':') return NO;
    }
    
    return YES;
}

BOOL objcSelectorIsLikelyASetter(SEL selector)
{
    const char *methodName = sel_getName(selector);
    assert(strlen(methodName) > 0);
    if (strlen(methodName) < 4) return NO;
    
    if (methodName[0] == 's' && methodName[1] == 'e' && methodName[2] == 't' && methodName[3] >= 'A' && methodName[3] <= 'Z' && methodName[strlen(methodName)-1] == ':') {
        return YES;
    }
    
    return NO;
}

BOOL classHasProperty(Class klass, const char *propertyName)
{
    assert(strlen(propertyName)>0);
    unsigned propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(klass, &propertyCount);
    if (propertyCount == 0) {free(propertyList); return NO;}
    
    for (unsigned i = 0; i<propertyCount; ++i) {
        objc_property_t property = propertyList[i];
        const char *aPropertyName = property_getName(property);
        if (strcmp(propertyName, aPropertyName) == 0) {free(propertyList); return YES;};
    }
    free(propertyList);
    
    Class superClass = class_getSuperclass(klass);
    while (superClass) {
        unsigned propertyCount = 0;
        propertyList = class_copyPropertyList(superClass, &propertyCount);
        for (unsigned i = 0; i<propertyCount; ++i) {
            objc_property_t property = propertyList[i];
            const char *aPropertyName = property_getName(property);
            if (strcmp(propertyName, aPropertyName) == 0) {free(propertyList); return YES;};
        }
        free(propertyList);

        superClass = class_getSuperclass(superClass);
    }
    
    return NO;
}

//free the return value after use
char *methodTypeDescriptionFromLuaMethodName(const char *luaName)
{
    assert(strlen(luaName) > 0);

    char *strippedMethodName = objcMethodNameFromLuaMethodName(luaName);
    char *typeDescription = calloc(strlen(strippedMethodName) + 4, sizeof(char));
    strcpy(typeDescription, "v:@");//return type defaults to `void`
    
    for (int i=0, j=3; i < strlen(strippedMethodName); ++i) {
        if (strippedMethodName[i] == ':') {
            typeDescription[j++] = '@';//parameter type defaults to `id`
        }
    }
    free(strippedMethodName);
    return typeDescription;
}


//FIXME: struct alignment
int structBytesFromTypeDescription(const char *typeDescription)
{
    if (!typeDescription || strlen(typeDescription) == 0) return 0;
    
    int len = 0;
    char *subStruct = strstr(typeDescription, "=") + 1;
    for (int i=0; i<strlen(subStruct); ++i) {
        switch (subStruct[i]) {
            case '@'://#define _C_ID       '@'
            {
                len += sizeof(id);
                break;
            }
            case '#'://#define _C_CLASS    '#'
            {
                len += sizeof(Class);
                break;
            }
            case ':'://#define _C_SEL      ':'
            {
                len += sizeof(SEL);
                break;
            }
            case 'B'://#define _C_BOOL     'B'
            case 'c'://#define _C_CHR      'c'
            case 'C'://#define _C_UCHR     'C'
            {
                len += sizeof(char);
                break;
            }
            case 's'://#define _C_SHT      's'
            case 'S'://#define _C_USHT     'S'
            {
                len += sizeof(short);
                break;
            }
            case 'i'://#define _C_INT      'i'
            case 'I'://#define _C_UINT     'I'
            {
                len += sizeof(int);
                break;
            }
            case 'l'://#define _C_LNG      'l'
            case 'L'://#define _C_ULNG     'L'
            {
                len += sizeof(long);
                break;
            }
            case 'q'://#define _C_LNG_LNG  'q'
            case 'Q'://#define _C_ULNG_LNG 'Q'
            {
                len += sizeof(long long);
                break;
            }
            case 'f'://#define _C_FLT      'f'
            {
                len += sizeof(float);
                break;
            }
            case 'd'://#define _C_DBL      'd'
            case 'D':
            {
                len += sizeof(double);
                break;
            }
            case '?'://#define _C_UNDEF    '?'
            {
                //what's this?
                break;
            }
            case '^'://#define _C_PTR      '^'
            case '*'://#define _C_CHARPTR  '*'
            {
                len += sizeof(char *);
                break;
            }
            case '{'://#define _C_STRUCT_B '{'
            {
                len += structBytesFromTypeDescription(subStruct + i);
                i += strstr(subStruct, "}") - subStruct;
                break;
            }
            case '}'://#define _C_STRUCT_E '}'
            {
                //we are done here
                return len;
            }
            default:
                break;
        }
    }
    return len;
}

BOOL isInitMethod(const char *methodName)
{
    if (strlen(methodName)<4) {
        return NO;
    }
    
    if (methodName[0]=='i' && methodName[1]=='n' && methodName[2]=='i' && methodName[3]=='t') {
        return YES;
    }
    
    return NO;
}

BOOL isInitSelector(SEL sel)
{
    return isInitMethod(sel_getName(sel));
}

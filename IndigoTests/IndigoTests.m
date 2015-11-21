//
//  IndigoTests.m
//  IndigoTests
//
//  Created by zhang on 9/5/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <XCTest/XCTest.h>
#include "indigo_engine.h"
#include <objc/runtime.h>


typedef struct {
    int a;
    long b;
    float c;
    double d;
}AStruct;

extern int structBytesFromTypeDescription(const char *typeDescription);

#define TEST_FUNCTION(x) (x(*)(id, SEL, x))

#define TEST_FUNCTION_BODY(sel_name, param_type, arg0, arg1) \
Class TestClass = NSClassFromString(@"TestClass");\
XCTAssert(TestClass, "class not found");\
NSObject *obj = [[TestClass alloc] init];\
SEL selector = sel_getUid(sel_name);\
if ([obj respondsToSelector:selector]) {\
    IMP imp = [obj methodForSelector:selector];\
    param_type arg = arg0;\
    param_type ret = ((param_type(*)(id, SEL, param_type))imp)(obj, selector, arg0);\
    XCTAssert(ret == arg, "%s must return the same value as its input", sel_name);\
    arg = arg1;\
    ret = ((param_type(*)(id, SEL, param_type))imp)(obj, selector, arg1);\
    XCTAssert(ret == arg, "%s must return the same value as its input", sel_name);\
}\
else {\
    XCTFail("%s: not implemented", sel_name);\
}

@interface IndigoTests : XCTestCase
@property (nonatomic, strong) IndigoEngine *engine;
@end

@implementation IndigoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    [fileManager changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
//    
//    self.engine = [IndigoEngine sharedEngine];
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test_script" ofType:@"lua" inDirectory:nil];
//    if (!filePath) {
//        printf("file does not exist! bundle path: %s\n", [[NSBundle mainBundle] bundlePath].UTF8String);
//    }
//    
//    [self.engine runScriptAtPath:filePath];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testStructSize
{
    
    //        NSLog(@"%s", @encode(CGRect));//{CGRect={CGPoint=dd}{CGSize=dd}}
    //        NSLog(@"%s", @encode(CGAffineTransform));//{CGAffineTransform=dddddd}
    //
    //        NSLog(@"%s", @encode(CGVector));//{CGAffineTransform=dddddd}
    //
    //        NSLog(@"%s", @encode(AStruct));//{CGAffineTransform=dddddd}
    
    
    //
    int b = sizeof(CGAffineTransform);
    int a = structBytesFromTypeDescription("{CGRect={CGPoint=dd}{CGSize=dd}}");
    
    assert(a == b);
}

- (void)testCallFuncThatTakesNoArg
{
    Class TestClass = NSClassFromString(@"TestClass");
    XCTAssert(TestClass, "class not found");
    NSObject *obj = [[TestClass alloc] init];
    SEL selector = sel_getUid("funcThatTakesNoArg");
    if ([obj respondsToSelector:selector]) {
        IMP imp = [obj methodForSelector:selector];
        ((void(*)(id, SEL))imp)(obj, selector);
    }
    else {
        XCTFail("funcThatTakesNoArg not implemented");
    }
}

- (void)testCallFuncThatTakesSelector
{
    TEST_FUNCTION_BODY("funcThatTakesSelector:", SEL, @selector(description), @selector(hashTableWithOptions:));
}

- (void)testCallFuncThatTakesCChar
{
    TEST_FUNCTION_BODY("funcThatTakesCChar:", char, CHAR_MIN, CHAR_MAX);
}

- (void)testCallFuncThatTakesCUnsignedChar
{
    TEST_FUNCTION_BODY("funcThatTakesCUnsignedChar:", unsigned char, 0, UCHAR_MAX);
}

- (void)testCallFuncThatTakesShort
{
    TEST_FUNCTION_BODY("funcThatTakesShort:", short, SHRT_MIN, SHRT_MAX);
}

- (void)testCallFuncThatTakesUnsignedShort
{
    TEST_FUNCTION_BODY("funcThatTakesUnsignedShort:", unsigned short, 0, USHRT_MAX);
}

- (void)testCallFuncThatTakesInt
{
    TEST_FUNCTION_BODY("funcThatTakesInt:", int, INT_MIN, INT_MAX);
}

- (void)testCallFuncThatTakesDouble
{
    TEST_FUNCTION_BODY("funcThatTakesDouble:", double, DBL_MIN, DBL_MAX);
}

- (void)testCallFuncThatTakesLong
{
    TEST_FUNCTION_BODY("funcThatTakesLong:", long, LONG_MIN, LONG_MAX);
}

- (void)testCallFuncThatTakesUnsignedInt
{
    TEST_FUNCTION_BODY("funcThatTakesUnsignedInt:", unsigned int, 0, UINT_MAX);
}

- (void)testCallFuncThatTakesUnsignedLong
{
    TEST_FUNCTION_BODY("funcThatTakesUnsignedLong:", unsigned long, 0, ULONG_MAX);
}

- (void)testCallFuncThatTakesLongLong
{
    TEST_FUNCTION_BODY("funcThatTakesLongLong:", long long, LONG_LONG_MIN, LONG_LONG_MAX);
}

- (void)testCallFuncThatTakesUnsignedLongLong
{
    TEST_FUNCTION_BODY("funcThatTakesUnsignedLongLong:", unsigned long long, 0, ULONG_LONG_MAX);
}


//- (void)testCallFuncThatTakesStruct
//{
//    TEST_FUNCTION_BODY("funcThatTakesUnsignedLongLong:", CGRect, CGRectZero, CGRectZero);
//}

@end

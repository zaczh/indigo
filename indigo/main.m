//
//  main.m
//  indigo
//
//  Created by zhang on 7/19/15.
//  Copyright © 2015 yourcompany. All rights reserved.
//

#import <UIKit/UIKit.h>

#include "indigo.h"
#import "IndigoTestObject.h"


int main(int argc, char * argv[]) {
    @autoreleasepool {

        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
        
        IndigoEngine *engine = [IndigoEngine sharedEngine];
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"AppDelegate" ofType:@"lua" inDirectory:nil];
        if (!filePath) {
            printf("file does not exist! bundle path: %s\n", [[NSBundle mainBundle] bundlePath].UTF8String);
            return -1;
        }
        
        [engine runScriptAtPath:filePath];
        
//        filePath = [[NSBundle mainBundle] pathForResource:@"test_script" ofType:@"lua" inDirectory:nil];
//        if (!filePath) {
//            printf("file does not exist! bundle path: %s\n", [[NSBundle mainBundle] bundlePath].UTF8String);
//        }
//        
//        [engine runScriptAtPath:filePath];
        return UIApplicationMain(argc, argv, nil, @"MyAppDelegate");
    }
}

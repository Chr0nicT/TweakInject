//
//  TweakInject.m
//  TweakInject
//
//  Created by Tanay Findley on 5/24/19.
//  Copyright © 2019 Slice Team. All rights reserved.
//

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <spawn.h>
#include <sys/types.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <pthread.h>
#include <Foundation/Foundation.h>
#include <mach/host_priv.h>
#include <notify.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach/mach_init.h>
#include <mach/mach_error.h>

bool safeMode = false;

NSString *dylibDir = @"/usr/lib/TweakInject";

NSArray *sbinjectGenerateDylibList() {
    NSString *processName = [[NSProcessInfo processInfo] processName];
    // launchctl, amfid you are special cases
    if ([processName isEqualToString:@"launchctl"]) {
        return nil;
    }
    // Create an array containing all the filenames in dylibDir (/opt/simject)
    NSError *e = nil;
    NSArray *dylibDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dylibDir error:&e];
    if (e) {
        return nil;
    }
    // Read current bundle identifier
    //NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    // We're only interested in the plist files
    NSArray *plists = [dylibDirContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"plist"]];
    // Create an empty mutable array that will contain a list of dylib paths to be injected into the target process
    NSMutableArray *dylibsToInject = [NSMutableArray array];
    // Loop through the list of plists
    for (NSString *plist in plists) {
        // We'll want to deal with absolute paths, so append the filename to dylibDir
        NSString *plistPath = [dylibDir stringByAppendingPathComponent:plist];
        NSDictionary *filter = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        // This boolean indicates whether or not the dylib has already been injected
        BOOL isInjected = NO;
        // If supported iOS versions are specified within the plist, we check those first
        NSArray *supportedVersions = filter[@"CoreFoundationVersion"];
        if (supportedVersions) {
            if (supportedVersions.count != 1 && supportedVersions.count != 2) {
                continue; // Supported versions are in the wrong format, we should skip
            }
            if (supportedVersions.count == 1 && [supportedVersions[0] doubleValue] > kCFCoreFoundationVersionNumber) {
                continue; // Doesn't meet lower bound
            }
            if (supportedVersions.count == 2 && ([supportedVersions[0] doubleValue] > kCFCoreFoundationVersionNumber || [supportedVersions[1] doubleValue] <= kCFCoreFoundationVersionNumber)) {
                continue; // Outside bounds
            }
        }
        // Decide whether or not to load the dylib based on the Bundles values
        for (NSString *entry in filter[@"Filter"][@"Bundles"]) {
            // Check to see whether or not this bundle is actually loaded in this application or not
            if (!CFBundleGetBundleWithIdentifier((CFStringRef)entry)) {
                // If not, skip it
                continue;
            }
            [dylibsToInject addObject:[[plistPath stringByDeletingPathExtension] stringByAppendingString:@".dylib"]];
            isInjected = YES;
            break;
        }
        if (!isInjected) {
            // Decide whether or not to load the dylib based on the Executables values
            for (NSString *process in filter[@"Filter"][@"Executables"]) {
                if ([process isEqualToString:processName]) {
                    [dylibsToInject addObject:[[plistPath stringByDeletingPathExtension] stringByAppendingString:@".dylib"]];
                    isInjected = YES;
                    break;
                }
            }
        }
        if (!isInjected) {
            // Decide whether or not to load the dylib based on the Classes values
            for (NSString *clazz in filter[@"Filter"][@"Classes"]) {
                // Also check if this class is loaded in this application or not
                if (!NSClassFromString(clazz)) {
                    // This class couldn't be loaded, skip
                    continue;
                }
                // It's fine to add this dylib at this point
                [dylibsToInject addObject:[[plistPath stringByDeletingPathExtension] stringByAppendingString:@".dylib"]];
                isInjected = YES;
                break;
            }
        }
    }
    [dylibsToInject sortUsingSelector:@selector(caseInsensitiveCompare:)];
    return dylibsToInject;
}



int file_exist(const char *filename) {
    struct stat buffer;
    int r = stat(filename, &buffer);
    return (r == 0);
}

void SpringBoardSigHandler(int signo, siginfo_t *info, void *uap){
    
    //We got a bad signal. Safemode File
    NSLog(@"[TweakInject] Kill Signal: %d", signo);
    FILE *f = fopen("/var/mobile/.sbinjectSafeMode", "w");
    fprintf(f, "We out here\n");
    fclose(f);
    raise(signo);
}

__attribute__ ((constructor))
static void ctor(void) {
    NSLog(@"[TweakInject] Called!");
    
    
    if (NSBundle.mainBundle.bundleIdentifier == nil || ![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"org.coolstar.SafeMode"]) {
        safeMode = false;
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if ([processName isEqualToString:@"backboardd"] || [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            //SIGACTION
            struct sigaction action;
            memset(&action, 0, sizeof(action));
            action.sa_sigaction = &SpringBoardSigHandler;
            action.sa_flags = SA_SIGINFO | SA_RESETHAND;
            sigemptyset(&action.sa_mask);
            
            sigaction(SIGQUIT, &action, NULL);
            sigaction(SIGILL, &action, NULL);
            sigaction(SIGTRAP, &action, NULL);
            sigaction(SIGABRT, &action, NULL);
            sigaction(SIGEMT, &action, NULL);
            sigaction(SIGFPE, &action, NULL);
            sigaction(SIGBUS, &action, NULL);
            sigaction(SIGSEGV, &action, NULL);
            sigaction(SIGSYS, &action, NULL);
            
            
            if (file_exist("/var/mobile/.sbinjectSafeMode")) {
                safeMode = true;
                if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
                    unlink("/var/mobile/.sbinjectSafeMode");
                    NSLog(@"[TweakInject] Safe Mode!");
                }
                //INJECT SAFEMODE UI
                NSLog(@"[TweakInject] Injecting Safe Mode UI!");
                void *dl = dlopen([@"/usr/lib/TweakInject/Safemode.dylib" UTF8String], RTLD_LAZY | RTLD_GLOBAL);
                if (dl == NULL) {
                    NSLog(@"[TweakInject] FALIURE INJECTING SAFEMODE UI: '%s'", dlerror());
                }
            }
            
            
        }

        if (!safeMode)
        {
            NSLog(@"[TweakInject] Normal Operation!");
            for (NSString *dylib in sbinjectGenerateDylibList())
            {
                if (![dylib  isEqual: @"/usr/lib/TweakInject/Safemode.dylib"])
                {
                    NSLog(@"[TweakInject] Injecting %@ into %@", dylib, NSBundle.mainBundle.bundleIdentifier);
                    void *dl = dlopen([dylib UTF8String], RTLD_LAZY | RTLD_GLOBAL);
                    if (dl == NULL) {
                        NSLog(@"[TweakInject] FALIURE: '%s'", dlerror());
                    }
                } else {
                    NSLog(@"[TweakInject] Skipping %@ because it is Safemode.", dylib);
                }
            }
        }
    }
}

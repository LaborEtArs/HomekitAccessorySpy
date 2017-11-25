//
//  HASAppDelegate.m
//  HomekitAccessorySpy
//
//  Created by Hartmut on 16.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import "HASAppDelegate.h"


/**
 HASAppDelegate interface (private)
 
 */
@interface HASAppDelegate ()

@end


/**
 HASAppDelegate implementation
 
 */
@implementation HASAppDelegate

@synthesize persistentContainer = _persistentContainer;

/*
 application:didFinishLaunchingWithOptions:
 
 */
- (BOOL)			  application:(UIApplication *)pApplication
	didFinishLaunchingWithOptions:(NSDictionary *)pLaunchOptions {

	return YES;
}

/*
 applicationWillResignActive:
 
 */
- (void)applicationWillResignActive:(UIApplication *)pApplication {
}

/*
 applicationDidEnterBackground:
 
 */
- (void)applicationDidEnterBackground:(UIApplication *)pApplication {
}

/*
 applicationWillEnterForeground:
 
 */
- (void)applicationWillEnterForeground:(UIApplication *)pApplication {
}

/*
 applicationDidBecomeActive:
 
 */
- (void)applicationDidBecomeActive:(UIApplication *)pApplication {
}

/*
 applicationWillTerminate:
 
 */
- (void)applicationWillTerminate:(UIApplication *)pApplication {

	[self saveContext];
}


#pragma mark - COREDATASTACK

//@synthesize persistentContainer = _persistentContainer;

/*
 persistentContainer
 
 */
- (NSPersistentContainer *)persistentContainer {

    @synchronized (self) {
        if (!_persistentContainer) {
            _persistentContainer = [NSPersistentContainer.alloc initWithName:@"HomekitAccessorySpy"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription* pStoreDescription, NSError* pError) {
                if (pError) {
                    NSLog(@"[HASAppDelegate] persistentContainer ERROR: Unresolved error %@, %@", pError, pError.userInfo);
                    abort();
                }
            }];
        }
    }
    
    return _persistentContainer;
}

/*
 saveContext
 
 */
- (void)saveContext {
	
    NSManagedObjectContext*	context = self.persistentContainer.viewContext;
    NSError*				error = nil;
    if ((context.hasChanges) &&
		(![context save:&error])) {
		
        NSLog(@"[HASAppDelegate] saveContext ERROR: Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
}

@end









//
//  HASAppDelegate.h
//  HomekitAccessorySpy
//
//  Created by Hartmut on 16.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


/**
 HASAppDelegate
 
 */
@interface HASAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow*				window;

@property (readonly, strong) NSPersistentContainer*	persistentContainer;

- (void)saveContext;

@end








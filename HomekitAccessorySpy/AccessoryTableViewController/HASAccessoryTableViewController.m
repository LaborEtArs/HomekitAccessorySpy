//
//  HASAccessoryTableViewController.mm
//  HomekitAccessorySpy
//
//  Created by Hartmut on 30.10.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import "../AppDelegate/HASAppDelegate.h"
#import "../AccessoryViewController/HASAccessoryViewController.h"

#import "HASAccessoryTableViewController.h"


/**
 HASAccessoryTableViewController interface (private)
 
 */
@interface HASAccessoryTableViewController () <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSFetchedResultsController*	fetchedResultsController;

@end


/**
 HASAccessoryTableViewController implementation
 
 */
@implementation HASAccessoryTableViewController

/*
 viewDidLoad
 
 */
- (void)viewDidLoad {

	[super viewDidLoad];
	
	self.tableView.tableFooterView = UIView.alloc.init;
}

/*
 didReceiveMemoryWarning
 
 */
- (void)didReceiveMemoryWarning {
	
	[super didReceiveMemoryWarning];
}

/*
 prepareForSegue:sender:
 
 */
- (void)prepareForSegue:(UIStoryboardSegue *)pSegue
				 sender:(id)pSender {
	
	if ([pSegue.identifier isEqualToString:@"showAccessorySegueID"]) {
		NSIndexPath*				indexPath = [self.tableView indexPathForSelectedRow];
		HASAccessoryViewController*	destViewController = pSegue.destinationViewController;
		destViewController.accessoryObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
	}
}

#pragma mark - UITABLEVIEWDATASOURCE

/*
 tableView:numberOfRowsInSection:
 
 */
- (NSInteger)   tableView:(UITableView *)pTableView
	numberOfRowsInSection:(NSInteger)pSection {
	
	id<NSFetchedResultsSectionInfo>	sectionInfo = [self.fetchedResultsController.sections objectAtIndex:pSection];
    return sectionInfo.numberOfObjects;
}

/*
 tableView:cellForRowAtIndexPath:
 
 */
- (UITableViewCell *)tableView:(UITableView *)pTableView
		 cellForRowAtIndexPath:(NSIndexPath *)pIndexPath {
	
	UITableViewCell*	cell = [pTableView dequeueReusableCellWithIdentifier:@"AccessoriesTableViewCellIdentifier"
																forIndexPath:pIndexPath];
	[self configureCell:cell
			atIndexPath:pIndexPath];
	return cell;
}


#pragma mark - UITABLEVIEWDELEGATE

/*
 tableView:didSelectRowAtIndexPath:
 
 */
- (void)		  tableView:(UITableView *)pTableView
	didSelectRowAtIndexPath:(NSIndexPath *)pIndexPath {
	
	[self.tableView deselectRowAtIndexPath:pIndexPath
								  animated:YES];

}

/*
 tableView:canEditRowAtIndexPath:
 
 */
- (BOOL)		tableView:(UITableView *)pTableView
	canEditRowAtIndexPath:(NSIndexPath *)pIndexPath {
	
	return YES;
}

/*
 tableView:commitEditingStyle:forRowAtIndexPath:
 
 */
- (void)	 tableView:(UITableView *)pTableView
	commitEditingStyle:(UITableViewCellEditingStyle)pEditingStyle
 	 forRowAtIndexPath:(NSIndexPath *)pIndexPath {

	if (UITableViewCellEditingStyleDelete == pEditingStyle) {
		
		NSManagedObjectContext*		managedObjectContext = ((HASAppDelegate*)UIApplication.sharedApplication.delegate).persistentContainer.viewContext;
		NSManagedObject*			accessoryObject = [self.fetchedResultsController objectAtIndexPath:pIndexPath];
		[managedObjectContext deleteObject:accessoryObject];
		
		NSError*	error = 0;
		if (![managedObjectContext save:&error]) {
			NSLog(@"Failed to save managedObjectContext (%@)", error);
		}
	}
}

#pragma mark - NSFECTHEDRESULTSCONTROLLERDELEGATE

/*
 controllerWillChangeContent:
 
 */
- (void)controllerWillChangeContent:(NSFetchedResultsController *)pController {

	[self.tableView beginUpdates];
}

/*
 controller:didChangeSection:atIndex:forChangeType:
 
 */
- (void)  controller:(NSFetchedResultsController *)pController
	didChangeSection:(id)pSectionInfo
			 atIndex:(NSUInteger)pSectionIndex
	   forChangeType:(NSFetchedResultsChangeType)pChangeType {
    
    switch(pChangeType) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:pSectionIndex]
						  withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:pSectionIndex]
						  withRowAnimation:UITableViewRowAnimationFade];
            break;
			
		case NSFetchedResultsChangeMove:
		case NSFetchedResultsChangeUpdate:
			break;
    }
}

/*
 controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:
 
 */
- (void) controller:(NSFetchedResultsController *)pController
	didChangeObject:(id)pObject
		atIndexPath:(NSIndexPath *)pIndexPath
	  forChangeType:(NSFetchedResultsChangeType)pChangeType
	   newIndexPath:(NSIndexPath *)pNewIndexPath {

	switch(pChangeType) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[pNewIndexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[pIndexPath]
								  withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[self.tableView cellForRowAtIndexPath:pIndexPath]
					atIndexPath:pIndexPath];
            break;
            
        case NSFetchedResultsChangeMove:
           [self.tableView deleteRowsAtIndexPaths:@[pIndexPath]
								 withRowAnimation:UITableViewRowAnimationFade];
           [self.tableView insertRowsAtIndexPaths:@[pNewIndexPath]
								 withRowAnimation:UITableViewRowAnimationFade];
           break;
    }
}

/*
 controllerDidChangeContent:
 
 */
- (void)controllerDidChangeContent:(NSFetchedResultsController *)pController {
	
    [self.tableView endUpdates];
}


#pragma mark - HELPERS

/*
 configureCell:atIndexPath:
 
 */
- (void)configureCell:(UITableViewCell *)pCell
		  atIndexPath:(NSIndexPath *)pIndexPath {
	
	NSManagedObject*	accessoryObject = [self.fetchedResultsController objectAtIndexPath:pIndexPath];
	pCell.textLabel.text = [accessoryObject valueForKey:@"name"];
	NSData*	accessoryID = [accessoryObject valueForKey:@"id"];
	pCell.detailTextLabel.text = [NSString.alloc initWithData:accessoryID
													 encoding:NSUTF8StringEncoding];
	UIImage*	accessoryImage = [UIImage imageNamed:@"UnknownAccessory"];
	switch (((NSNumber*)[accessoryObject valueForKey:@"category"]).unsignedIntegerValue) {
		case 2:
			accessoryImage = [UIImage imageNamed:@"Bridge"];
			break;
		case 5:
			accessoryImage = [UIImage imageNamed:@"Lightbulb"];
			break;
	}
	pCell.imageView.image = accessoryImage;
}


#pragma mark - PROPERTIES

/*
 fetchedResultsController
 
 */
- (NSFetchedResultsController *)fetchedResultsController {
	
	if (!_fetchedResultsController) {
		NSManagedObjectContext*		managedObjectContext = ((HASAppDelegate*)UIApplication.sharedApplication.delegate).persistentContainer.viewContext;
		NSFetchRequest*				fetchRequest = NSFetchRequest.alloc.init;
		NSEntityDescription*		entity = [NSEntityDescription entityForName:@"HASPairedAccessory"
														 inManagedObjectContext:managedObjectContext];
		[fetchRequest setEntity:entity];
    
		NSSortDescriptor*			sort = [NSSortDescriptor.alloc initWithKey:@"name"
																	 ascending:NO];
		[fetchRequest setSortDescriptors:@[sort]];
		[fetchRequest setFetchBatchSize:20];
    
		NSFetchedResultsController*	localFetchedResultsController = [NSFetchedResultsController.alloc initWithFetchRequest:fetchRequest
																									  managedObjectContext:managedObjectContext
																										sectionNameKeyPath:nil
																											     cacheName:nil/*@"Root"*/];
		localFetchedResultsController.delegate = self;
		
		NSError*	error = nil;
		if (![localFetchedResultsController performFetch:&error]) {
			NSLog(@"[HASAccessoryTableViewController] fetchedResultsController: ERROR: Failed to preformFetch %@\n%@", error.localizedDescription, error.userInfo);
			abort();
		}		
		_fetchedResultsController = localFetchedResultsController;
	}
    return _fetchedResultsController;
}



@end









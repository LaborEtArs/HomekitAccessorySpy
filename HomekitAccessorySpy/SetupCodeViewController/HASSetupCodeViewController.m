//
//  HASSetupCodeViewController.m
//  HomekitAccessorySpy
//
//  Created by Hartmut on 21.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import "HASSetupCodeViewController.h"

@interface HASSetupCodeViewController ()

@property (strong, nonatomic) NSArray<UILabel*>*	setupCodeLabels;

@end

@implementation HASSetupCodeViewController

/*
 viewDidLoad
 
 */
- (void)viewDidLoad {
	
    [super viewDidLoad];
    
	[self setupLabels:nil];
	
	[self.invisibleTextField becomeFirstResponder];
}

/*
 didReceiveMemoryWarning
 
 */
- (void)didReceiveMemoryWarning {
	
    [super didReceiveMemoryWarning];
}


#pragma mark - UITEXTFIELDDELEGATE

/*
 textField:shouldChangeCharactersInRange:replacementString:
 
 */
- (BOOL)				textField:(UITextField *)pTextField
	shouldChangeCharactersInRange:(NSRange)pRange
				replacementString:(NSString *)pString {
	//NSLog(@"%lu, %@", pTextField.text.length, pString);
	
	NSString*	newText = [pTextField.text stringByReplacingCharactersInRange:pRange
																 withString:pString];
	[self setupLabels:newText];

	if (8  == newText.length) {
		[self.invisibleTextField endEditing:YES];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
					   dispatch_get_main_queue(),
					   ^{
						   if (self.commitAction) {
							   NSString*	setupCode = [NSString stringWithFormat:@"%@-%@-%@",
														 [newText substringWithRange:NSMakeRange(0, 3)],
														 [newText substringWithRange:NSMakeRange(3, 2)],
														 [newText substringWithRange:NSMakeRange(5, 3)]];
							   self.commitAction(self, setupCode);
						   }
					   });
	}
	return YES;
}


#pragma mark - HELPERS

/*
 setupLabels
 
 */
- (void)setupLabels:(NSString *)pSetupCode {
	
	self.setupCodeLabels = @[
							 self.setupCode1Label,
							 self.setupCode2Label,
							 self.setupCode3Label,
							 self.setupCode4Label,
							 self.setupCode5Label,
							 self.setupCode6Label,
							 self.setupCode7Label,
							 self.setupCode8Label
							 ];
	
	for (UILabel* label in self.setupCodeLabels) {
		NSUInteger	index = [self.setupCodeLabels indexOfObject:label];
		
		label.layer.borderColor = UIColor.blackColor.CGColor;
		label.layer.borderWidth = ((pSetupCode.length == index) ? 3.0 : 1.0);
		label.layer.cornerRadius = 5.0;
		
		label.backgroundColor = nil;
		
		label.text = ((pSetupCode.length > index)
					  ? [pSetupCode substringWithRange:NSMakeRange(index, 1)] 
					  : nil);
	}
}

@end










//
//  HASAccessoryViewController.h
//  HomekitAccessorySpy
//
//  Created by Hartmut on 17.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


/**
 HASAccessoryViewController
 
 */
@interface HASAccessoryViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (strong, nonatomic) NSManagedObject*		accessoryObject;

@property (weak, nonatomic) IBOutlet UIImageView*	imageView;
@property (weak, nonatomic) IBOutlet UILabel*		titleLabel;
@property (weak, nonatomic) IBOutlet UIPickerView*	methodPickerView;
@property (weak, nonatomic) IBOutlet UIButton*		sendButton;
@property (weak, nonatomic) IBOutlet UITextField*	inputTextField;
@property (strong, nonatomic) IBOutlet UITextView*	responseTextView;


@end

//
//  HASSetupCodeViewController.h
//  HomekitAccessorySpy
//
//  Created by Hartmut on 21.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//

#import <UIKit/UIKit.h>


/**
 HASSetupCodeViewController
 
 */
@interface HASSetupCodeViewController : UIViewController <UITextFieldDelegate>

typedef void (^setupCodeCommitActionType)(HASSetupCodeViewController* pViewController, NSString* pSetupCode);

@property (weak, nonatomic) IBOutlet UITextField*	invisibleTextField;

@property (weak, nonatomic) IBOutlet UILabel*		setupCode1Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode2Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode3Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode4Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode5Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode6Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode7Label;
@property (weak, nonatomic) IBOutlet UILabel*		setupCode8Label;

@property (strong, nonatomic) setupCodeCommitActionType	commitAction;
@end

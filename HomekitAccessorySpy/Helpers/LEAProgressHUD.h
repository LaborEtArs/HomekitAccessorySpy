//
// LEAProgressHUD.m
//

#import <UIKit/UIKit.h>


/**
 LEAProgressHUD

 */
@interface LEAProgressHUD : UIView

@property (assign, nonatomic) BOOL						allowInteraction;

@property (strong, nonatomic) UIWindow*					window;

@property (strong, nonatomic) UIView*					interactionShieldView;
@property (strong, nonatomic) UIColor*					interactionShieldViewColor;

@property (strong, nonatomic) UIToolbar*				hudToolbar;
@property (strong, nonatomic) UIColor*					hudToolbarBackgroundColor;

@property (strong, nonatomic) UIActivityIndicatorView*	activityIndicator;
@property (strong, nonatomic) UIColor*					activityIndicatorColor;

@property (strong, nonatomic) UILabel*					messageLabel;
@property (strong, nonatomic) UIFont*					messageLabelFont;
@property (strong, nonatomic) UIColor*					messageLabelTextColor;

+ (LEAProgressHUD *)sharedInstance;

- (void)showWithMessage:(NSString *)pMessage;
- (void)showWithMessage:(NSString *)pMessage
	   allowInteraction:(BOOL)pAllowInteraction;

- (void)dismiss;

@end

// LEAProgressHUDSharedInstance
#define LEAProgressHUDSharedInstance	[LEAProgressHUD sharedInstance]





//
// LEAProgressHUD.m
//

#import "LEAProgressHUD.h"


/**
 LEAProgressHUD

 */
@implementation LEAProgressHUD

#pragma mark - CLASS METHODS

/*
 sharedInstance

 */
+ (LEAProgressHUD *)sharedInstance {

	static LEAProgressHUD*	_sharedInstance = nil;

	static dispatch_once_t	onceToken = 0;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[LEAProgressHUD alloc] init];
	});

	return _sharedInstance;
}


#pragma mark - PUBLIC INTERFACE

/*
 showWithMessage:

*/
- (void)showWithMessage:(NSString *)pMessage {

	[self showWithMessage:pMessage allowInteraction:YES];
}

/*
 showWithMessage:allowInteraction:
	   
 */
- (void)showWithMessage:(NSString *)pMessage
	   allowInteraction:(BOOL)pAllowInteraction {

	self.allowInteraction = pAllowInteraction;
	[self setupHUDWithMessage:pMessage isSpinning:YES andAutoHide:NO];
}

/*
 dismiss

 */
- (void)dismiss {

	[self hideHUD];
}


#pragma mark - INIT/DESTROY

/*
 init
 
 */
- (instancetype)init {

	if (self = [super initWithFrame:[[UIScreen mainScreen] bounds]]) {

		// Get the application window from the app delegate (if implemented)
		id<UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
		if ([appDelegate respondsToSelector:@selector(window)]) {
			self.window = [appDelegate performSelector:@selector(window)];
		} else {
			self.window = [[UIApplication sharedApplication] keyWindow];
		}
		
		// Set the view itself transparent as a starter
		self.alpha = 0;

		// Default colors, ...
		self.hudToolbarBackgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
		self.interactionShieldViewColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.2];
		self.activityIndicatorColor = self.tintColor;
		self.messageLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
		self.messageLabelTextColor = UIColor.blackColor;
	}
	return self;
}


#pragma mark - VIEW MANAGEMENT

/*
 setupHUDWithMessage:isSpinning:andAutoHide:

 */
- (void)setupHUDWithMessage:(NSString *)pMessage
				 isSpinning:(BOOL)pIsSpinning
				andAutoHide:(BOOL)pAutoHide {

	[self createHUD];

	self.messageLabel.text = pMessage;
	self.messageLabel.hidden = (0 == pMessage.length);

	if (pIsSpinning) {
		[self.activityIndicator startAnimating];
	} else {
		[self.activityIndicator stopAnimating];
	}

	[self adjustHUDSize];
	[self adjustHUDPositionWithNotification:nil];
	[self showHUD];

	if (pAutoHide) {
		// Create thread to auto hide the HUD after a short moment
		[NSThread detachNewThreadSelector:@selector(timedHideThreadFct)
								 toTarget:self
							   withObject:nil];
	}
}

/*
 createHUD
 
 */
- (void)createHUD {

	// Create toolbar
	if (!_hudToolbar) {
		_hudToolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
		self.hudToolbar.translucent = YES;
		self.hudToolbar.backgroundColor = self.hudToolbarBackgroundColor;
		self.hudToolbar.layer.cornerRadius = 10;
		self.hudToolbar.layer.masksToBounds = YES;

		[self registerNotifications];
	}
	
	// Attach to superview
	if (!self.hudToolbar.superview) {
		if (!self.allowInteraction) {
			_interactionShieldView = [[UIView alloc] initWithFrame:self.window.frame];
			self.interactionShieldView.backgroundColor = self.interactionShieldViewColor;
			[self.window addSubview:self.interactionShieldView];
			[self.interactionShieldView addSubview:self.hudToolbar];
		} else {
			[self.window addSubview:self.hudToolbar];
		}
	}

	// Activity indicator
	if (!_activityIndicator) {
		// Default size: 36x36px
		_activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		self.activityIndicator.color = self.activityIndicatorColor;
		self.activityIndicator.hidesWhenStopped = YES;
	}
	if (!self.activityIndicator.superview) {
		[self.hudToolbar addSubview:self.activityIndicator];
	}

	// Message label
	if (!_messageLabel)	{
		_messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.messageLabel.font = self.messageLabelFont;
		self.messageLabel.textColor = self.messageLabelTextColor;
		self.messageLabel.backgroundColor = [UIColor clearColor];
		self.messageLabel.textAlignment = NSTextAlignmentCenter;
		self.messageLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		self.messageLabel.numberOfLines = 0;	// Multiline
	}
	if (!self.messageLabel.superview) {
		[self.hudToolbar addSubview:self.messageLabel];
	}
}

/*
 destroyHUD

 */
- (void)destroyHUD {

	[self unregisterNotifications];
	
	// destroy all subviews
	[self.messageLabel removeFromSuperview];			self.messageLabel = nil;
	[self.activityIndicator removeFromSuperview];		self.activityIndicator = nil;
	[self.hudToolbar removeFromSuperview];				self.hudToolbar = nil;
	[self.interactionShieldView removeFromSuperview];	self.interactionShieldView = nil;
}


/*
 adjustHUDSize

 */
- (void)adjustHUDSize {

	const CGFloat	borderPadding = 12.0;
	const CGSize	activityIndicatorSize = self.activityIndicator.bounds.size;

	CGRect	labelRect = CGRectZero;
	CGFloat	hudWidth = 100;
	CGFloat	hudHeight = 100;

	if (self.messageLabel.text.length) {
		NSDictionary*	attributes = @{
										NSFontAttributeName:	self.messageLabel.font
										};
		NSInteger		options = NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin;
		labelRect = [self.messageLabel.text boundingRectWithSize:CGSizeMake(200, 300)
														 options:options
													  attributes:attributes
														 context:NULL];

		labelRect.origin.x = borderPadding;
		labelRect.origin.y = borderPadding + activityIndicatorSize.height + borderPadding;

		hudWidth = borderPadding + labelRect.size.width + borderPadding;
		hudHeight = borderPadding + activityIndicatorSize.height + borderPadding + labelRect.size.height + borderPadding;

		if (100 > hudWidth) {	// Keep at a minimum width
			hudWidth = 100;
			labelRect.origin.x = 0;
			labelRect.size.width = 100;
		}
	}

	self.hudToolbar.bounds = CGRectMake(0, 0, hudWidth, hudHeight);
	
	self.activityIndicator.center = CGPointMake((hudWidth / 2), (self.messageLabel.text.length ? 36 : (hudHeight / 2)));

	self.messageLabel.frame = labelRect;
}

/*
 adjustHUDPositionWithNotification:
 
 */
- (void)adjustHUDPositionWithNotification:(NSNotification *)pNotification {

	CGFloat			keyboardHeight = 0;
	NSTimeInterval	animationDuration = 0;
	
	if (pNotification) {
		NSDictionary*	info = [pNotification userInfo];

		animationDuration = [[info valueForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
		CGRect			keyboardRect = [[info valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

		if (([pNotification.name isEqualToString:UIKeyboardWillShowNotification]) ||
			([pNotification.name isEqualToString:UIKeyboardDidShowNotification])) {
			
			keyboardHeight = keyboardRect.size.height;
		}
	} else {
		keyboardHeight = [self keyboardHeightHack];
	}

	CGRect	screenRect = [UIScreen mainScreen].bounds;
	CGPoint	center = CGPointMake((screenRect.size.width / 2), ((screenRect.size.height - keyboardHeight) / 2));
	
	[UIView animateWithDuration:animationDuration
						  delay:0
						options:UIViewAnimationOptionAllowUserInteraction
					 animations:^{
									self.hudToolbar.center = CGPointMake(center.x, center.y);
								}
					 completion:NULL];

	if (self.interactionShieldView) {
		self.interactionShieldView.frame = self.window.frame;
	}
}

/*
 showHUD

 */
- (void)showHUD {

	if (0.0 == self.alpha) {
		self.alpha = 1.0;

		self.hudToolbar.alpha = 0.0;
		self.hudToolbar.transform = CGAffineTransformScale(self.hudToolbar.transform, 1.4, 1.4);

		NSUInteger	options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut;
		[UIView animateWithDuration:0.15
							  delay:0
							options:options
						 animations:^{
										self.hudToolbar.transform = CGAffineTransformScale(self.hudToolbar.transform, (1 / 1.4), (1 / 1.4));
										self.hudToolbar.alpha = 1;
									 }
						 completion:NULL];
	}
}

/*
 hideHUD

 */
- (void)hideHUD {

	if (1.0 == self.alpha) {
		NSUInteger	options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseIn;
		[UIView animateWithDuration:0.15
							  delay:0
							options:options
						 animations:^{
										self.hudToolbar.transform = CGAffineTransformScale(self.hudToolbar.transform, 0.7, 0.7);
										self.hudToolbar.alpha = 0.0;
									 }
						 completion:^(BOOL finished) {
														[self destroyHUD];
														self.alpha = 0.0;
													 }];
	}
}


#pragma mark - HELPERS

/*
 registerNotifications

 */
- (void)registerNotifications {

	// Detect rotation
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustHUDPositionWithNotification:)
												 name:UIApplicationDidChangeStatusBarOrientationNotification
											   object:nil];

	// Detect keyboard 'movement'
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustHUDPositionWithNotification:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustHUDPositionWithNotification:)
												 name:UIKeyboardDidHideNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustHUDPositionWithNotification:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(adjustHUDPositionWithNotification:)
												 name:UIKeyboardDidShowNotification
											   object:nil];
}

/*
 unregisterNotifications

 */
- (void)unregisterNotifications {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*
 keyboardHeightHack
 
 */
- (CGFloat)keyboardHeightHack {

	for (UIWindow* testWindow in [[UIApplication sharedApplication] windows]) {
		if (![[testWindow class] isEqual:[UIWindow class]]) {
			for (UIView* possibleKeyboard in [testWindow subviews]) {
				if ([[possibleKeyboard description] hasPrefix:@"<UIPeripheralHostView"]) {
					return possibleKeyboard.bounds.size.height;
				} else if ([[possibleKeyboard description] hasPrefix:@"<UIInputSetContainerView"]) {
					for (UIView* hostKeyboard in [possibleKeyboard subviews]) {
						if ([[hostKeyboard description] hasPrefix:@"<UIInputSetHost"]) {
							return hostKeyboard.frame.size.height;
						}
					}
				}
			}
		}
	}
	return 0;
}


#pragma mark - AUTO HIDE BACKGROUND THREAD

/*
 timedHideThreadFct

 */
- (void)timedHideThreadFct {

	@autoreleasepool {
		double			length = self.messageLabel.text.length;
		NSTimeInterval	sleep = (length * 0.04) + 0.5;
		[NSThread sleepForTimeInterval:sleep];

		dispatch_async(dispatch_get_main_queue(), ^{
			[self hideHUD];
		});
	}
}

@end







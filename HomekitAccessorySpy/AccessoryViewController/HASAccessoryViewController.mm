//
//  HASAccessoryViewController.m
//  HomekitAccessorySpy
//
//  Created by Hartmut on 17.11.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//
#import <arpa/inet.h>

#import "../Helpers/HAPTCPIPConnection.h"
#import "../TLV/TLV8.h"
#import "../Crypto/Ed25519.h"
#import "../Crypto/ChaChaPoly.h"
#import "../Crypto/Curve25519.h"
#import "../HMAC+HKDF/HMAC+HKDF.h"

#import "../HAPAccessoryServer/HAPASConnection_Defines.h"

#import "../Helpers/LEAProgressHUD.h"

#import "HASAccessoryViewController.h"


/**
 HASAccessoryViewController interface (private)
 
 */
@interface HASAccessoryViewController () <NSNetServiceDelegate>

@property (strong, nonatomic) NSNetService*				accessoryService;

@property (strong, nonatomic) HAPTCPIPConnection*		hapConnection;
@property (strong, nonatomic) HAPTCPIPConnectionResponseHandlerType	requestResponseHandler;
@property (strong, nonatomic) NSString*					errorMessage;

@property (strong, nonatomic) NSArray<NSDictionary*>*	hapInputMethods;

@end


/**
 HASAccessoryViewController
 
 */
@implementation HASAccessoryViewController

/*
 viewDidLoad
 
 */
- (void)viewDidLoad {
	
    [super viewDidLoad];
	self.title =
	self.titleLabel.text = [self.accessoryObject valueForKey:@"name"];
	
	UIImage*	accessoryImage = [UIImage imageNamed:@"UnknownAccessory"];
	switch (((NSNumber*)[self.accessoryObject valueForKey:@"category"]).unsignedIntegerValue) {
		case 2:
			accessoryImage = [UIImage imageNamed:@"Bridge"];
			break;
		case 5:
			accessoryImage = [UIImage imageNamed:@"Lightbulb"];
			break;
	}
	self.imageView.image = accessoryImage;

	[self beginInitialization];
}

/*
 viewDidDisappear:
 
 */
- (void)viewDidDisappear:(BOOL)pAnimated {
	
	[super viewDidDisappear:pAnimated];
	
	if (self.hapConnection) {
		[self.hapConnection close];
		self.hapConnection = nil;
	}
}

/*
 didReceiveMemoryWarning
 
 */
- (void)didReceiveMemoryWarning {
	
    [super didReceiveMemoryWarning];
}


#pragma mark - INITIALIZATION

/*
 beginInitialization
 
 */
- (void)beginInitialization {
	
	[LEAProgressHUDSharedInstance showWithMessage:@"Searching accessory..." allowInteraction:NO];
	[self findAccessory];
}

/**
 HASAccessoryViewControllerInitializationResultType
 
 */
typedef NS_OPTIONS(NSUInteger, HASAccessoryViewControllerInitializationResultType) {
	HASAccessoryViewControllerInitializationResultType_Success		= 0,
	HASAccessoryViewControllerInitializationResultType_NotFound		= 1,
	HASAccessoryViewControllerInitializationResultType_NotVerified	= 2,
};

/*
 finalizeInitialization
 
 */
- (void)finalizeInitializationWithResult:(HASAccessoryViewControllerInitializationResultType)pResultType {
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	[LEAProgressHUDSharedInstance dismiss];
	
	if (HASAccessoryViewControllerInitializationResultType_Success != pResultType) {
		NSString*	message = nil;
		if (HASAccessoryViewControllerInitializationResultType_NotFound == pResultType) {
			message = [NSString stringWithFormat:@"Failed to find accessory!\n\n%@", self.errorMessage ?: @"No more details!"];
		}
		else if (HASAccessoryViewControllerInitializationResultType_NotVerified == pResultType) {
			message = [NSString stringWithFormat:@"Failed to verify accessory pairing!\n\n%@", self.errorMessage ?: @"No more details!"];
		}
		UIAlertController*	alert = [UIAlertController alertControllerWithTitle:@"Accessory Spy"
																	   message:message
																preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"Close"
												  style:UIAlertActionStyleDefault
												handler:^(UIAlertAction * _Nonnull p_pAction) {
													
													dispatch_async(dispatch_get_main_queue(), ^{
														[self.navigationController popViewControllerAnimated:YES];
													});
												}]];
		
		[self presentViewController:alert 
						   animated:YES
						 completion:NULL];
	}
	else {
		__weak typeof(self) 	weakSelf = self;
		
		void (^contentHandler)(NSData* pHeader, NSData* pContent) = ^(NSData* pHeader, NSData* pContent) {
			if (pContent) {
				//[weakSelf.responseTextView insertText:@"\nResponse-Header:\n"];
				//[weakSelf.responseTextView insertText:[NSString.alloc initWithData:pHeader encoding:NSUTF8StringEncoding]];
				//[weakSelf.responseTextView insertText:@"\nResponse:\n"];
				@try {
					NSError*		jsonError;
					id			allKeys = [NSJSONSerialization JSONObjectWithData:pContent
																   options:0
																	 error:&jsonError];
					NSData*		jsonData = [NSJSONSerialization dataWithJSONObject:allKeys
																		options:NSJSONWritingPrettyPrinted
																		  error:&jsonError];
					NSString*	jsonString = [NSString.alloc initWithData:jsonData
															   encoding:NSUTF8StringEncoding];
					[weakSelf.responseTextView insertText:jsonString];
				}
				@catch(...) {
					NSLog(@"FAILED to parse json response data: %@", [NSString.alloc initWithData:pContent
																						 encoding:NSUTF8StringEncoding]);
					[weakSelf.responseTextView insertText:[NSString stringWithFormat:@"\nFAILED to parse JSON response data!\n%@", [NSString.alloc initWithData:pContent
																																					   encoding:NSUTF8StringEncoding]]];
				}
			}
			else if (pHeader) {
				if (NSNotFound != [pHeader rangeOfData:[@"204 No Content" dataUsingEncoding:NSUTF8StringEncoding]
											   options:0 
												 range:NSMakeRange(0, pHeader.length)].location) {
					[weakSelf.responseTextView insertText:@"\nSucceeded! Received a 204 No Content response."];
				}
				else {
					NSLog(@"Unexpected response header without content!");
					[weakSelf.responseTextView insertText:[NSString stringWithFormat:@"\nUnexpected response header without content!\n%@", [NSString.alloc initWithData:pHeader
																																							   encoding:NSUTF8StringEncoding]]];
				}
			}
			else {
				NSLog(@"No response data and no header!");
				[weakSelf.responseTextView insertText:[NSString stringWithFormat:@"\nNo response data and no header!"]];					   
			}
		};
		
		self.requestResponseHandler = ^(NSData* pHeader, NSData* pContent) {
			[weakSelf.responseTextView insertText:@"\nResponse:\n"];
			contentHandler(pHeader, pContent);
		};
		
		self.hapConnection.eventHandler = ^(NSData* pHeader, NSData* pContent) {
			[weakSelf.responseTextView insertText:@"\nEVENT:\n"];
			contentHandler(pHeader, pContent);			
		};
	}
}

/*
 findAccessory
 
 */
- (void)findAccessory {
	
	NSString*	name = [self.accessoryObject valueForKey:@"name"];
	NSUInteger	port = ((NSNumber*)[self.accessoryObject valueForKey:@"port"]).unsignedIntegerValue;
	
	self.accessoryService = [NSNetService.alloc initWithDomain:@"local"
														  type:@"_hap._tcp"
														  name:name
														  port:(int)port];
	self.accessoryService.delegate = self;
	[self.accessoryService resolveWithTimeout:5.0];
}


#pragma mark - UIPICKERVIEWDATASOURCE

/*
 numberOfComponentsInPickerView:
 
 */
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pPickerView {
	
	return 1;
}

/*
 pickerView:numberOfRowsInComponent:
 
 */
- (NSInteger)	 pickerView:(UIPickerView *)pPickerView
	numberOfRowsInComponent:(NSInteger)pComponent {
	
	return self.hapInputMethods.count;
}

/*
 pickerView:(UIPickerView *)pPickerView titleForRow:(NSInteger)pRow forComponent:
 
 */
- (NSString *)pickerView:(UIPickerView *)pPickerView
			 titleForRow:(NSInteger)pRow 
			forComponent:(NSInteger)pComponent {
	
	return self.hapInputMethods[pRow][kHAPInputMethodNameKey];
}


#pragma mark - UIPICKERVIEWDELEGATE

/*
 pickerView:viewForRow:forComponent:reusingView:
 
 */
- (UIView *)pickerView:(UIPickerView *)pPickerView 
			viewForRow:(NSInteger)pRow
		  forComponent:(NSInteger)pComponent
		   reusingView:(UIView *)pView {
	
	UILabel*	label = ([pView isKindOfClass:UILabel.class] 
						 ? (UILabel*)pView
						 : UILabel.alloc.init);
	label.font = self.inputTextField.font;
	label.textAlignment = NSTextAlignmentLeft;
	label.backgroundColor = UIColor.clearColor;
	
	label.text = self.hapInputMethods[pRow][kHAPInputMethodNameKey];

	return label;
}

/*
 pickerView:didSelectRow:inComponent:
 
 */
- (void)pickerView:(UIPickerView *)pPickerView
	  didSelectRow:(NSInteger)pRow
	   inComponent:(NSInteger)pComponent {
	
	self.inputTextField.text = self.hapInputMethods[pRow][kHAPInputMethodExampleKey];
}


#pragma mark UITEXTFIELDDELEGATE

/*
 textFieldShouldReturn:
 
 */
- (BOOL)textFieldShouldReturn:(UITextField *)pTextField {
	
	[pTextField endEditing:YES];
	return YES;
}

/*
 textFieldDidEndEditing:reason:
 
 */
- (void)textFieldDidEndEditing:(UITextField *)pTextField
						reason:(UITextFieldDidEndEditingReason)pReason {
	
	if (UITextFieldDidEndEditingReasonCommitted == pReason) {
		[self transmitMessage];
	}
}


#pragma mark - ACTIONS

/*
 sendButtonPushUpInside:
 
 */
- (IBAction)sendButtonTouchUpInside:(id)pSender {
	
	[self transmitMessage];
}



#pragma mark - TRANSMIT MESSAGE

/*
 transmitMessage
 
 */
- (void)transmitMessage {
	
	switch ([self.methodPickerView selectedRowInComponent:0]) {
		case HAPMethodType_GET_accessories:
			[self transmitMessage_GET_accessories];
			break;
		case HAPMethodType_GET_characteristic:
			[self transmitMessage_GET_characteristics];
			break;
		case HAPMethodType_PUT_characteristic:
			[self transmitMessage_PUT_characteristics];
			break;
	}
}

/*
 transmitMessage_GET_accessories
 
 */
- (void)transmitMessage_GET_accessories {
	
	NSMutableData*	postData = NSMutableData.alloc.init;
	NSString*		header = [NSString stringWithFormat:@"GET /accessories HTTP/1.1\r\nContent-Type: application/hap+json\r\nContent-Length: 0\r\n\r\n"];
	[postData appendBytes:header.UTF8String
				   length:strlen(header.UTF8String)];
	
	NSLog(@"Sending GET /accessories request");
	self.responseTextView.text = @"\nRequest:\n";
	[self.responseTextView insertText:[NSString.alloc initWithData:postData encoding:NSUTF8StringEncoding]];
	
	if (![self.hapConnection sendData:postData
				  withResponseTimeout:30
				   andResponseHandler:self.requestResponseHandler]) {
		NSLog(@"Failed to send request");
		[self.responseTextView insertText:@"\nFAILED to send request!"];
	}
}

/*
 transmitMessage_GET_characteristics
 
 */
- (void)transmitMessage_GET_characteristics {
	
	NSMutableData*	postData = NSMutableData.alloc.init;
	NSString*		header = [NSString stringWithFormat:@"GET /characteristics?%@ HTTP/1.1\r\nContent-Type: application/hap+json\r\nContent-Length: 0\r\n\r\n", self.inputTextField.text];
	[postData appendBytes:header.UTF8String
				   length:strlen(header.UTF8String)];
	
	NSLog(@"Sending GET /characteristics request");
	self.responseTextView.text = @"\nRequest:\n";
	[self.responseTextView insertText:[NSString.alloc initWithData:postData encoding:NSUTF8StringEncoding]];
	
	if (![self.hapConnection sendData:postData
				  withResponseTimeout:30
				   andResponseHandler:self.requestResponseHandler]) {
		NSLog(@"Failed to send request");
		[self.responseTextView insertText:@"\nFAILED to send request!"];
	}
}

/*
 transmitMessage_PUT_characteristics
 
 */
- (void)transmitMessage_PUT_characteristics {
	
	NSData*			jsonData = nil;
	@try {
		NSError*	jsonError = nil;
		NSData*		inputData = [self.inputTextField.text dataUsingEncoding:NSUTF8StringEncoding];
		id			allKeys = [NSJSONSerialization JSONObjectWithData:inputData
													   options:0
														 error:&jsonError];
		jsonData = [NSJSONSerialization dataWithJSONObject:allKeys
												   options:0
													 error:&jsonError];
	} @catch(...) {
		NSLog(@"FAILED to parse json data: %@", self.inputTextField.text);
	}
	
	if (jsonData) {
		NSString*		header = [NSString stringWithFormat:@"PUT /characteristics HTTP/1.1\r\nContent-Type: application/hap+json\r\nContent-Length: %u\r\n\r\n", (unsigned)jsonData.length/*[NSString.alloc initWithData:inputData encoding:NSUTF8StringEncoding].length*/];
		
		NSMutableData*	postData = NSMutableData.alloc.init;
		[postData appendBytes:header.UTF8String
					   length:strlen(header.UTF8String)];
		[postData appendBytes:jsonData.bytes length:jsonData.length];
		
		NSLog(@"Sending GET /characteristics request");
		self.responseTextView.text = @"\nRequest:\n";
		[self.responseTextView insertText:[NSString.alloc initWithData:postData encoding:NSUTF8StringEncoding]];
		
		if (![self.hapConnection sendData:postData
					  withResponseTimeout:30
					   andResponseHandler:self.requestResponseHandler]) {
			NSLog(@"Failed to send request");
			[self.responseTextView insertText:@"\nFAILED to send request!"];
		}
	}
	else {
		NSLog(@"FAILED to create json data!");
		self.responseTextView.text = [NSString stringWithFormat:@"\nFAILED to create JSON data from input string: %@\n", self.inputTextField.text];
	}
}


#pragma mark - VERIFY PAIRING

/*
 verifyPairingWithService:
 
 */
static const unsigned char	hkdfPairVerifyEncryptSalt[24] = {
	'P',  'a',  'i',  'r',  '-',  'V',  'e',  'r',  'i',  'f', 'y',  '-',  'E',  'n',  'c',  'r',
	'y',  'p',  't',  '-',  'S',  'a',  'l',  't',
};

static const unsigned char	hkdfPairVerifyEncryptInfo[24] = {
	'P',  'a',  'i',  'r',  '-',  'V',  'e',  'r',  'i',  'f', 'y',  '-',  'E',  'n',  'c',  'r',
	'y',  'p',  't',  '-',  'I',  'n',  'f',  'o',
};

static const unsigned char nonce_PVMsg02[12] = {
	0x00, 0x00, 0x00, 0x00,
	'P',  'V',  '-',  'M',  's',  'g',  '0',  '2',
};

static const unsigned char nonce_PVMsg03[12] = {
	0x00, 0x00, 0x00, 0x00,
	'P',  'V',  '-',  'M',  's',  'g',  '0',  '3',
};

static const unsigned char hkdfControlSalt[12] = {
	'C',  'o',  'n',  't',  'r',  'o',  'l',  '-',  'S',  'a', 'l',  't',
};

static const unsigned char	hkdfControlReadEncryptionKey[27] = {
	'C',  'o',  'n',  't',  'r',  'o',  'l',  '-',  'R',  'e', 'a',  'd',  '-',  'E',  'n',  'c',
	'r',  'y',  'p',  't',  'i',  'o',  'n',  '-',  'K',  'e',  'y',
};

static const unsigned char	hkdfControlWriteEncryptionKey[28] = {
	'C',  'o',  'n',  't',  'r',  'o',  'l',  '-',  'W',  'r', 'i',  't',  'e',  '-',  'E',  'n',
	'c',  'r',  'y',  'p',  't',  'i',  'o',  'n',  '-',  'K',  'e',  'y',
};

- (void)verifyPairingWithService:(NSNetService *)pNetService {
	
	__weak typeof(self) 	weakSelf = self;
	
	__block unsigned char*	puciOSDeviceCurve25519SecretKey = 0;
	__block unsigned char*	puciOSDeviceCurve25519PublicKey = 0;
	__block unsigned char*	pucCurve25519SharedSecret = 0;
	__block unsigned char*	pucPairVerifyHKDFSessionKey = 0;
	
	//
	// cleanUp block
	void(^cleanUp)(const BOOL p_bCloseConnection) = ^(const BOOL p_bCloseConnection) {
		if (puciOSDeviceCurve25519SecretKey) {
			delete[] puciOSDeviceCurve25519SecretKey;
			puciOSDeviceCurve25519SecretKey = 0;
		}
		if (puciOSDeviceCurve25519PublicKey) {
			delete[] puciOSDeviceCurve25519PublicKey;
			puciOSDeviceCurve25519PublicKey = 0;
		}
		if (pucCurve25519SharedSecret) {
			delete[] pucCurve25519SharedSecret;
			pucCurve25519SharedSecret = 0;
		}
		if (pucPairVerifyHKDFSessionKey) {
			delete[] pucPairVerifyHKDFSessionKey;
			pucPairVerifyHKDFSessionKey = 0;
		}
		
		if (p_bCloseConnection) {
			[weakSelf.hapConnection close];
			weakSelf.hapConnection = nil;
		}
		[self finalizeInitializationWithResult:(weakSelf.hapConnection
												? HASAccessoryViewControllerInitializationResultType_Success
												: HASAccessoryViewControllerInitializationResultType_NotVerified)];
	};
	
	//
	// responseHandlerPVM4 block
	HAPTCPIPConnectionResponseHandlerType	responseHandlerPVM4 = ^(NSData* pHeader, NSData* pContent) {
		if (pContent) {
			NSLog(@"Received PV-M4 response data!");
			
			unsigned char			ucState = 0;
			unsigned char			ucError = kTLVError_NoErr;
			
			clsTLV8Reader			tlv8ReaderPVM4((unsigned char*)pContent.bytes, (unsigned)pContent.length);
			unsigned char			ucTag;
			unsigned				uLength;
			const unsigned char*	pucValue;
			while ((tlv8ReaderPVM4.isValid()) &&
				   (tlv8ReaderPVM4.next(ucTag, uLength, pucValue))) {
				switch (ucTag) {
					case kTLVType_State:
						if (1 == uLength) {
							ucState = *pucValue;
						}
						break;
					case kTLVType_Error:
						if (1 == uLength) {
							ucError = *pucValue;
						}
						break;
					default: {
						NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
					}
				}
			}	// while
			
			if ((4 == ucState) &&
				(kTLVError_NoErr == ucError)) {
				//NSLog(@"Succeeded to verify pairing!");
				
				NSMutableData*	HKDFAccessory2ControllerKeyData = [NSMutableData dataWithLength:32];
				NSMutableData*	HKDFController2AccessoryKeyData = [NSMutableData dataWithLength:32];
				if ((HKDF512(hkdfControlSalt, sizeof(hkdfControlSalt),
							 pucCurve25519SharedSecret, 32,
							 hkdfControlReadEncryptionKey, sizeof(hkdfControlReadEncryptionKey),
							 (unsigned char*)HKDFAccessory2ControllerKeyData.mutableBytes, (unsigned)HKDFAccessory2ControllerKeyData.length)) &&
					(HKDF512(hkdfControlSalt, sizeof(hkdfControlSalt),
							 pucCurve25519SharedSecret, 32,
							 hkdfControlWriteEncryptionKey, sizeof(hkdfControlWriteEncryptionKey),
							 (unsigned char*)HKDFController2AccessoryKeyData.mutableBytes, (unsigned)HKDFController2AccessoryKeyData.length))) {
					
					weakSelf.hapConnection.Accessory2ControllerKey = HKDFAccessory2ControllerKeyData;
					weakSelf.hapConnection.Controller2AccessoryKey = HKDFController2AccessoryKeyData;
					
					//[self printArray:(const unsigned char *)pucCurve25519SharedSecret withLength:32 andComment:@"Shared secret"];
					//[self printArray:(const unsigned char *)connection.Accessory2ControllerKey.bytes withLength:(unsigned)connection.Accessory2ControllerKey.length andComment:@"A2C"];
					//[self printArray:(const unsigned char *)connection.Controller2AccessoryKey.bytes withLength:(unsigned)connection.Controller2AccessoryKey.length andComment:@"C2A"];
					
					NSLog(@"SUCCEEDED to verify pairing!");
					cleanUp(NO);
				}
				else {
					NSLog(@"%@", self.errorMessage = @"Failed to create PV-M4 secure session keys!");
					cleanUp(YES);
				}
			}
			else {
				NSLog(@"%@", self.errorMessage = @"Error or invalid PV-M4 response data!");
				cleanUp(YES);
			}
		}
		else {
			NSLog(@"%@", self.errorMessage = @"No PV-M4 response data!");
			cleanUp(YES);
		}		
	};
	
	//
	// responseHandlerPVM2 block
	HAPTCPIPConnectionResponseHandlerType	responseHandlerPVM2 = ^(NSData* pHeader, NSData* p_Content) {
		if (p_Content) {
			NSLog(@"Received PV-M2 response data!");
			
			unsigned				ucState = 0;
			const unsigned char*	pucAccessoryCurve25519PublicKey = 0;
			unsigned				uAccessoryCurve25519PublicKeyLength = 0;
			const unsigned char*	pucEncryptedData = 0;
			unsigned				uEncryptedDataLength = 0;
			
			clsTLV8Reader			tlv8ReaderPVM2((unsigned char*)p_Content.bytes, (unsigned)p_Content.length);
			unsigned char			ucTag;
			unsigned				uLength;
			const unsigned char*	pucValue;
			while ((tlv8ReaderPVM2.isValid()) &&
				   (tlv8ReaderPVM2.next(ucTag, uLength, pucValue))) {
				switch (ucTag) {
					case kTLVType_State:
						if (1 == uLength) {
							ucState = *pucValue;
						}
						break;
					case kTLVType_PublicKey:
						if (32 == uLength) {
							pucAccessoryCurve25519PublicKey = pucValue;
							uAccessoryCurve25519PublicKeyLength = uLength;
						}
						break;
					case kTLVType_EncryptedData:
						pucEncryptedData = pucValue;
						uEncryptedDataLength = uLength;
						break;
					default: {
						NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
					}
				}
			}	// while
			
			if ((2 == ucState) &&
				(pucAccessoryCurve25519PublicKey) &&
				(pucEncryptedData)) {
				
				//[self printArray:pucAccessoryCurve25519PublicKey withLength:32 andComment:@"AccessoryPublicKey"];
				pucCurve25519SharedSecret = new unsigned char[32];
				memcpy(pucCurve25519SharedSecret, pucAccessoryCurve25519PublicKey, 32);
				if (!Curve25519::dh2(pucCurve25519SharedSecret, puciOSDeviceCurve25519SecretKey)) {
					NSLog(@"%@", self.errorMessage = @"FAILED to generate SHARED SECRET!");
				}
				//[self printArray:pucCurve25519SharedSecret withLength:32 andComment:@"SharedSecret A"];
				
				pucPairVerifyHKDFSessionKey = new unsigned char[32];
				if (HKDF512(hkdfPairVerifyEncryptSalt, sizeof(hkdfPairVerifyEncryptSalt),
							pucCurve25519SharedSecret, 32,
							hkdfPairVerifyEncryptInfo, sizeof(hkdfPairVerifyEncryptInfo),
							pucPairVerifyHKDFSessionKey, 32)) {
					
					const unsigned	uSizeOfTag = 16;
					unsigned		uSubTLVDataLength = (uEncryptedDataLength - uSizeOfTag);
					unsigned char	aucTag[uSizeOfTag];
					unsigned char*	pucSubTLVData = new unsigned char[uSubTLVDataLength];
					*pucSubTLVData = 0;
					
					//print("[HAPASConnection] Encrypted data:", p_pucEncryptedData, uSubTLVDataLength);
					//print("[HAPASConnection] Tag:", p_pucEncryptedData + uSubTLVDataLength, uSizeOfTag);
					
					ChaChaPoly	ccpDecrypt;
					ccpDecrypt.setKey(pucPairVerifyHKDFSessionKey, 32);
					ccpDecrypt.setIV(nonce_PVMsg02, sizeof(nonce_PVMsg02));
					ccpDecrypt.decrypt(pucSubTLVData, pucEncryptedData, uSubTLVDataLength);
					ccpDecrypt.computeTag(aucTag, sizeof(aucTag));
					
					if ((0 == memcmp(aucTag, (pucEncryptedData + uSubTLVDataLength), uSizeOfTag)) &&
						(0 != *pucSubTLVData)) {	// First byte of decrypted data should be '0x01' or '0x0A'
						// Tag and decrypted subTLV OK
						//NSLog(@"Succeeded to decrypt subTLV!");
						
						const unsigned char*	pucAccessoryPairingID = 0;
						unsigned				uAccessoryPairingIDLength = 0;
						const unsigned char*	pucAccessorySignature = 0;
						unsigned				uAccessorySignatureLength = 0;
						
						clsTLV8Reader			subTLV8Reader((unsigned char*)pucSubTLVData, (unsigned)uSubTLVDataLength);
						unsigned char			ucTag;
						unsigned				uLength;
						const unsigned char*	pucValue;
						while ((subTLV8Reader.isValid()) &&
							   (subTLV8Reader.next(ucTag, uLength, pucValue))) {
							switch (ucTag) {
								case kTLVType_Identifier:
									if (17 == uLength) {
										pucAccessoryPairingID = pucValue;
										uAccessoryPairingIDLength = uLength;
									}
									break;
								case kTLVType_Signature:
									if (64 == uLength) {
										pucAccessorySignature = pucValue;
										uAccessorySignatureLength = uLength;
									}
									break;
								default: {
									NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
								}
							}
						}	// while
						
						if ((pucAccessoryPairingID) &&
							(pucAccessorySignature)) {
							
							NSData*	accessoryPairingIDData = [weakSelf.accessoryObject valueForKey:@"pairingID"];
							if ((accessoryPairingIDData) &&
								(0 == memcmp(accessoryPairingIDData.bytes, pucAccessoryPairingID, uAccessoryPairingIDLength))) {
								
								NSData*	accessoryLTPKData = [weakSelf.accessoryObject valueForKey:@"ltpk"];
								//NSLog(@"Retrieved accessory LTPK!");
								
								// Concat: AccessoryInfo = AccessoryCurve25519PublicKey[32], pucAccessoryPairingID[17], puciOSDeviceCurve25519PublicKey[32]
								unsigned		uAccessoryInfoLength = (32 + uAccessoryPairingIDLength + 32);
								unsigned char*	pucAccessoryInfo = new unsigned char[uAccessoryInfoLength];
								unsigned char*	pCursor = pucAccessoryInfo;
								memcpy(pCursor, pucAccessoryCurve25519PublicKey, 32);				pCursor += 32;
								memcpy(pCursor, pucAccessoryPairingID, uAccessoryPairingIDLength);	pCursor += uAccessoryPairingIDLength;
								memcpy(pCursor, puciOSDeviceCurve25519PublicKey, 32);
								//print("[HAPASConnection] iOSDeviceInfo:", auciOSDeviceInfo, uiOSDeviceInfoLength);
								
								bool	bSignVerifyResult = Ed25519::verify(pucAccessorySignature, (const unsigned char*)accessoryLTPKData.bytes, pucAccessoryInfo, uAccessoryInfoLength);
								delete[] pucAccessoryInfo;
								
								// Compare signature
								if (bSignVerifyResult) {
									
									NSData*	iOSDevicePairingIDData = [NSUserDefaults.standardUserDefaults objectForKey:@"iOSDevicePairingID"];
									NSAssert(36 == iOSDevicePairingIDData.length, @"Invalid iOSDevicePairingID!");
									
									NSData*	iOSDeviceLTSKData = [NSUserDefaults.standardUserDefaults objectForKey:@"iOSDeviceLTSKData"];
									
									// Concat: iOSDeviceInfo = iOSDeviceCurve25519PublicKey[32], puciOSDevicePairingID, pucAccessoryCurve25519PublicKey[32]
									unsigned		uiOSDeviceInfoLength = (32 + (unsigned)iOSDevicePairingIDData.length/*36*/ + 32);
									unsigned char*	puciOSDeviceInfo = new unsigned char[uiOSDeviceInfoLength];
									unsigned char*	pCursor = puciOSDeviceInfo;
									memcpy(pCursor, puciOSDeviceCurve25519PublicKey, 32);							pCursor += 32;
									memcpy(pCursor, iOSDevicePairingIDData.bytes, iOSDevicePairingIDData.length);	pCursor += iOSDevicePairingIDData.length;
									memcpy(pCursor, pucAccessoryCurve25519PublicKey, 32);
									//print("[HAPASConnection] iOSDeviceInfo:", auciOSDeviceInfo, uiOSDeviceInfoLength);
									
									unsigned char 	auciOSDeviceLTPK[32];
									Ed25519::derivePublicKey(auciOSDeviceLTPK, (const unsigned char*)iOSDeviceLTSKData.bytes);
									
									unsigned char		auciOSDeviceSignature[64];
									Ed25519::sign(auciOSDeviceSignature, (const unsigned char*)iOSDeviceLTSKData.bytes, auciOSDeviceLTPK, puciOSDeviceInfo, uiOSDeviceInfoLength);
									delete[] puciOSDeviceInfo;
									
									clsTLV8Writer	subTLV8Writer((1 + 1 + (unsigned)iOSDevicePairingIDData.length) + (1 + 1 + sizeof(auciOSDeviceSignature)));
									subTLV8Writer.add(kTLVType_Identifier, (unsigned)iOSDevicePairingIDData.length, (const unsigned char*)iOSDevicePairingIDData.bytes);
									subTLV8Writer.add(kTLVType_Signature, sizeof(auciOSDeviceSignature), auciOSDeviceSignature);
									
									const unsigned	uSizeOfTag = 16;
									unsigned char	aucTag[uSizeOfTag];
									unsigned		uSubTLVStreamLength = subTLV8Writer.length();
									unsigned char*	pucEncryptedSubTLV = new unsigned char[(uSubTLVStreamLength + sizeof(aucTag))];
									//DEBUG_HAPASCONNECTION(DEBUG_OUTPUT.printf("[HAPASConnection] uSubTLVStreamLength: %u\n", uSubTLVStreamLength));
									
									ChaChaPoly	ccpEncrypt;
									ccpEncrypt.setKey(pucPairVerifyHKDFSessionKey, 32);
									ccpEncrypt.setIV(nonce_PVMsg03, sizeof(nonce_PVMsg03));
									ccpEncrypt.encrypt(pucEncryptedSubTLV, subTLV8Writer.TLVStream(), uSubTLVStreamLength);
									ccpEncrypt.computeTag(aucTag, sizeof(aucTag));
									
									//print("[HAPASConnection] EncryptedSubTLV:", pucEncryptedSubTLV, (uSubTLVStreamLength + sizeof(aucTag)));
									memcpy(pucEncryptedSubTLV + uSubTLVStreamLength, aucTag, sizeof(aucTag));
									//print("[HAPASConnection] EncryptedSubTLV+authTag:", pucEncryptedSubTLV, (uSubTLVStreamLength + sizeof(aucTag)));
									
									clsTLV8Writer	tlv8WriterM3((1 + 1 + 1) + (1 + 1 + (uSubTLVStreamLength + sizeof(aucTag))));
									tlv8WriterM3.addUC(kTLVType_State, 3);
									tlv8WriterM3.add(kTLVType_EncryptedData, (uSubTLVStreamLength + sizeof(aucTag)), pucEncryptedSubTLV);
									delete[] pucEncryptedSubTLV;
									
									NSMutableData*	postDataM3 = NSMutableData.alloc.init;
									NSString*		header = [NSString stringWithFormat:@"POST /pair-verify HTTP/1.1\r\nContent-Type: application/pairing+tlv8\r\nContent-Length: %u\r\n\r\n", tlv8WriterM3.length()];
									[postDataM3 appendBytes:header.UTF8String
													 length:strlen(header.UTF8String)];
									[postDataM3 appendBytes:tlv8WriterM3.TLVStream()
													 length:tlv8WriterM3.length()];
									
									NSLog(@"Sending PV-M3 request");
									if (![weakSelf.hapConnection sendData:postDataM3
													  withResponseTimeout:30
													   andResponseHandler:responseHandlerPVM4]) {
										NSLog(@"%@", self.errorMessage = @"Failed to send PV-M3 request");
										cleanUp(YES);
									}
								}
								else {
									NSLog(@"%@", self.errorMessage = @"Failed to verify PV-M2 signature!");
									cleanUp(YES);
								}
							}
							else {
								NSLog(@"%@", self.errorMessage = @"Invalid PV-M2 pairing ID subTLV!");
								cleanUp(YES);
							}
						}
						else {
							NSLog(@"%@", self.errorMessage = @"Invalid data in PV-M2 subTLV!");
							cleanUp(YES);
						}
					}
					else {
						NSLog(@"%@", self.errorMessage = @"Failed to decrypt PV-M2 subTLV!");
						cleanUp(YES);
					}
				}
				else {
					NSLog(@"%@", self.errorMessage = @"Failed to create PV-M2 HKDF session key!");
					cleanUp(YES);
				}
			}
			else {
				NSLog(@"%@", self.errorMessage = @"Received invalid PV-M2 content data!");
				cleanUp(YES);
			}
		}
		else {
			NSLog(@"%@", self.errorMessage = @"No PV-M2 response data!");
			cleanUp(YES);
		}
	};
	
	self.hapConnection = [HAPTCPIPConnection.alloc initWithService:pNetService];
	
	// Curve25519 random key pair
	puciOSDeviceCurve25519PublicKey = new unsigned char[32];
	puciOSDeviceCurve25519SecretKey = new unsigned char[32];
	Curve25519::dh1(puciOSDeviceCurve25519PublicKey, puciOSDeviceCurve25519SecretKey);
	
	clsTLV8Writer	tlv8WriterPVM1((1 + 1 + 1) + (1 + 1 + 32));
	tlv8WriterPVM1.addUC(kTLVType_State, 1);										// State: M1
	tlv8WriterPVM1.add(kTLVType_PublicKey, 32, puciOSDeviceCurve25519PublicKey);	// ED25519 Public key
	
	NSString*		headerPVM1 = [NSString stringWithFormat:@"POST /pair-verify HTTP/1.1\r\nContent-Type: application/pairing+tlv8\r\nContent-Length: %u\r\n\r\n", tlv8WriterPVM1.length()];
	
	NSMutableData*	postDataPVM1 = NSMutableData.alloc.init;
	[postDataPVM1 appendBytes:headerPVM1.UTF8String
					   length:strlen(headerPVM1.UTF8String)];
	[postDataPVM1 appendBytes:tlv8WriterPVM1.TLVStream()
					   length:tlv8WriterPVM1.length()];
	
	NSLog(@"Sending PV-M1 request");
	[self.hapConnection sendData:postDataPVM1 
			 withResponseTimeout:30
			  andResponseHandler:responseHandlerPVM2];
}


#pragma mark - NSNETSERVICEDELEGATE

/*
 netServiceDidResolveAddress:
 
 */
- (void)netServiceDidResolveAddress:(NSNetService *)pNetService {
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if (self.accessoryService == pNetService) {
		// Right now resolving
		[pNetService stop];
	}
	
	//NSLog(@"Port: %ld (%ld adresses)", (long)pNetService.port, (long)pNetService.addresses.count);
	
	NSData*			TXTRecordData = pNetService.TXTRecordData;
	NSDictionary*	TXTDictionary = [NSNetService dictionaryFromTXTRecordData:TXTRecordData];
	/*NSLog(@"TXT: %@", TXTDictionary);
	 id	x = TXTDictionary[@"sf"];
	 NSString*	s = [NSString.alloc initWithData:TXTDictionary[@"sf"] encoding:NSUTF8StringEncoding];*/
	
	NSData*	accessoryID = [self.accessoryObject valueForKey:@"id"];
	if ([accessoryID isEqualToData:TXTDictionary[@"id"]]) {
		
		[LEAProgressHUDSharedInstance showWithMessage:@"Verifying pairing..." 
									 allowInteraction:NO];
		[self verifyPairingWithService:pNetService];
	}
	else {
		NSLog(@"%@", self.errorMessage = @"Accessory doesn't match!");
		[self finalizeInitializationWithResult:HASAccessoryViewControllerInitializationResultType_NotFound];
	}
}

/*
 netService:didNotResolve:
 
 */
- (void)netService:(NSNetService *)pNetService
	 didNotResolve:(NSDictionary *)pErrorDict {
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if (self.accessoryService == pNetService) {
		[self.accessoryService stop];
		self.accessoryService = nil;
	}
	NSLog(@"%@", self.errorMessage = @"FAILED to find accessory!");
	[self finalizeInitializationWithResult:HASAccessoryViewControllerInitializationResultType_NotFound];
}

#pragma mark - PROPERTIES

/**
 HAPMethodType
 
 */
typedef NS_OPTIONS(NSUInteger, HAPMethodType) {
	HAPMethodType_GET_accessories		= 0,
	HAPMethodType_GET_characteristic	= 1,
	HAPMethodType_PUT_characteristic	= 2,
};

static NSString const*	kHAPInputMethodIDKey		= @"kHAPInputMethodIDKey";
static NSString const*	kHAPInputMethodNameKey		= @"kHAPInputMethodNameKey";
static NSString const*	kHAPInputMethodExampleKey	= @"kHAPInputMethodExampleKey";

/*
 hapInputMethods
 
 */
- (NSArray *)hapInputMethods {
	
	if (!_hapInputMethods) {
		
		_hapInputMethods = @[
							 @{
								 kHAPInputMethodIDKey:		[NSNumber numberWithUnsignedInteger:HAPMethodType_GET_accessories],
								 kHAPInputMethodNameKey:	@"GET /accessories",
								 kHAPInputMethodExampleKey:	@"",
								 },
							 @{
								 kHAPInputMethodIDKey:		[NSNumber numberWithUnsignedInteger:HAPMethodType_GET_characteristic],
								 kHAPInputMethodNameKey:	@"GET /characteristics",
								 kHAPInputMethodExampleKey:	@"id=1.9",
								 },
							 @{
								 kHAPInputMethodIDKey:		[NSNumber numberWithUnsignedInteger:HAPMethodType_PUT_characteristic],
								 kHAPInputMethodNameKey:	@"PUT /characteristics",
								 kHAPInputMethodExampleKey:	@"{\"characteristics\":[{\"aid\":1,\"iid\":17,\"ev\":1}]}",
								 },
							 ];
	}
	return _hapInputMethods;
}

@end








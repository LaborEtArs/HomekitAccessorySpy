//
//  HASAddAccessoryTableViewController.mm
//  HomekitAccessorySpy
//
//  Created by Hartmut on 30.10.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//
#import "../Helpers/HAPTCPIPConnection.h"
#import "../TLV/TLV8.h"
#import "../SRP/SRP6aClient.h"
#import "../Crypto/Ed25519.h"
#import "../Crypto/ChaChaPoly.h"
#import "../Crypto/Curve25519.h"
#import "../HMAC+HKDF/HMAC+HKDF.h"

#import "../Helpers/HAPTCPIPConnection.h"
#import "../HAPAccessoryServer/HAPASConnection_Defines.h"
#import "../Helpers/LEAProgressHUD.h"

#import "../AppDelegate/HASAppDelegate.h"
#import "../SetupCodeViewController/HASSetupCodeViewController.h"

#import "HASAddAccessoryTableViewController.h"


/**
 HASAddAccessoryTableViewController interface (private)
 
 */
@interface HASAddAccessoryTableViewController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (strong, nonatomic) NSMutableArray*					accessories;

@property (strong, nonatomic) NSNetServiceBrowser*				serviceBrowser;
@property (strong, nonatomic) NSMutableArray<NSNetService*>*	serviceResolvers;

@property (strong, nonatomic) HAPTCPIPConnection*				hapConnection;

@end

static NSString const*	kAccessoriesDictServiceKey		=	@"kAccessoriesDictServiceKey";		// NSNetService*
static NSString const*	kAccessoriesDictNameKey			=	@"kAccessoriesDictNameKey";			// NSString*
static NSString const*	kAccessoriesDictIDKey			=	@"kAccessoriesDictIDKey";			// NSData*
static NSString const*	kAccessoriesDictCategoryKey		=	@"kAccessoriesDictCategoryKey";		// NSNumber*(unsigned)
static NSString const*	kAccessoriesDictAddressKey		=	@"kAccessoriesDictAddressKey";		// NSString*
static NSString const*	kAccessoriesDictPortKey			=	@"kAccessoriesDictPortKey";			// NSNumber*(int)
static NSString const*	kAccessoriesDictAvailableKey	=	@"kAccessoriesDictAvailableKey";	// NSNumber*(bool)

/**
 HASAddAccessoryTableViewController implementation
 
 */
@implementation HASAddAccessoryTableViewController

/*
 viewDidLoad
 
 */
- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.accessories = NSMutableArray.array;
	
	self.serviceBrowser = NSNetServiceBrowser.alloc.init;
	self.serviceBrowser.delegate = self;
	self.serviceResolvers = NSMutableArray.array;
	
	self.tableView.tableFooterView = UIView.alloc.init;
	
	[self.serviceBrowser searchForServicesOfType:@"_hap._tcp"
										inDomain:@"local"];
}

/*
 didReceiveMemoryWarning
 
 */
- (void)didReceiveMemoryWarning {
	
	[super didReceiveMemoryWarning];
}

/*
 cancelBarButtonItem:
 
 */
- (IBAction)cancelBarButtonItem:(UIBarButtonItem *)pSender {
	
	[self dismissViewControllerAnimated:YES
							 completion:NULL];
}

#pragma mark - UITABLEVIEWDATASOURCE

/*
 tableView:numberOfRowsInSection:
 
 */
- (NSInteger)   tableView:(UITableView *)pTableView
	numberOfRowsInSection:(NSInteger)pSection {
	
	return MAX(1, self.accessories.count);
}

/*
 tableView:cellForRowAtIndexPath:
 
 */
- (UITableViewCell *)tableView:(UITableView *)pTableView
		 cellForRowAtIndexPath:(NSIndexPath *)pIndexPath {
	
	UITableViewCell*	cell = [pTableView dequeueReusableCellWithIdentifier:@"AddAccessoryTableViewCellIdentifier"
																forIndexPath:pIndexPath];
	if (self.accessories.count) {
		NSDictionary*	accessoryDict = [self.accessories objectAtIndex:pIndexPath.row];
		bool	bAvailable = ((NSNumber*)accessoryDict[kAccessoriesDictAvailableKey]).boolValue;
		
		cell.textLabel.text = accessoryDict[kAccessoriesDictNameKey];
		NSData*	accessoryID = accessoryDict[kAccessoriesDictIDKey];
		cell.detailTextLabel.text = (bAvailable
									 ? [NSString.alloc initWithData:accessoryID encoding:NSUTF8StringEncoding]
									 : @"Already paired!");
		cell.textLabel.textColor = 
		cell.detailTextLabel.textColor = (bAvailable ? UIColor.blackColor : UIColor.lightGrayColor);
		cell.userInteractionEnabled = bAvailable;
		
		UIImage*	accessoryImage = [UIImage imageNamed:@"UnknownAccessory"];
		switch (((NSNumber*)accessoryDict[kAccessoriesDictCategoryKey]).unsignedIntegerValue) {
			case 2:
				accessoryImage = [UIImage imageNamed:@"Bridge"];
				break;
			case 5:
				accessoryImage = [UIImage imageNamed:@"Lightbulb"];
				break;
		}
		cell.imageView.image = accessoryImage;
 	}
	else {
		cell.textLabel.text = @"Searching...";
	}
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

	if (self.accessories.count) {
		NSDictionary*	accessoryDict = [self.accessories objectAtIndex:pIndexPath.row];
		//NSLog(@"Selected accessory: %@", accessoryDict);
		
		HASSetupCodeViewController*	setupCodeViewController = (HASSetupCodeViewController*)[self.storyboard instantiateViewControllerWithIdentifier:@"SetupCodeViewControllerID"];
		setupCodeViewController.commitAction = ^(HASSetupCodeViewController *pViewController, NSString* pSetupCode) {
			[self.navigationController popViewControllerAnimated:YES];
			[self setupPairingForAccessory:accessoryDict
							  withPassword:pSetupCode];
		};
		[self.navigationController pushViewController:setupCodeViewController
											 animated:YES];
	}
}


#pragma mark - NSNETSERVICEBROWSERDELEGATE

/*
 netServiceBrowserWillSearch:
 
 */
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)pNetServiceBrowser {
	
	NSLog(@"%s", __PRETTY_FUNCTION__);
}
	
/*
 netServiceBrowser:didFindService:moreComing:
 
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)pNetServiceBrowser
		   didFindService:(NSNetService *)pNetService
			   moreComing:(BOOL)pMoreComing {
	
	pNetService.delegate = self;
	[pNetService resolveWithTimeout:3.0];
	
	[self.serviceResolvers addObject:pNetService];
}

/*
 netServiceBrowser:didRemoveService:moreComing:
 
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)pNetServiceBrowser
		 didRemoveService:(NSNetService *)pNetService
			   moreComing:(BOOL)pMoreServicesComing {
	
	if ([self.serviceResolvers containsObject:pNetService]) {
		// Right now resolving
		
		[pNetService stop];
		[self.serviceResolvers removeObject:pNetService];
	}
	else {
		// Maybe already resolved
		NSDictionary* accessoryDictToDelete = 0;
		for (NSDictionary* accessoryDict in self.accessories) {
			if ([accessoryDict[kAccessoriesDictServiceKey] isEqual:pNetService]) {
				accessoryDictToDelete = accessoryDict;
				break;
			}
		}
		if (accessoryDictToDelete) {
			[self.accessories removeObject:accessoryDictToDelete];
		}
	}
	
	if (!pMoreServicesComing) {
		[self.tableView reloadData];
	}
}

/*
 netServiceBrowser:didNotSearch:
 
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)pNetServiceBrowser
			 didNotSearch:(NSDictionary<NSString *,NSNumber *> *)pErrorDict {

	NSLog(@"%s (%@)", __PRETTY_FUNCTION__, pErrorDict);
}
/*
 netServiceBrowserDidStopSearch:
 
 */
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)pNetServiceBrowser {
	
	NSLog(@"%s", __PRETTY_FUNCTION__);
}


#pragma mark - NSNETSERVICEDELEGATE

/*
 netServiceDidResolveAddress:
 
 */
- (void)netServiceDidResolveAddress:(NSNetService *)pNetService {
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if ([self.serviceResolvers containsObject:pNetService]) {
		// Right now resolving
		
		[pNetService stop];
		[self.serviceResolvers removeObject:pNetService];
	}
	else {
		NSLog(@"NetService not found: %@", pNetService);
	}
	
	NSLog(@"Port: %ld (%ld adresses)", (long)pNetService.port, (long)pNetService.addresses.count);
	
	NSData*			TXTRecordData = pNetService.TXTRecordData;
	NSDictionary*	TXTDictionary = [NSNetService dictionaryFromTXTRecordData:TXTRecordData];
	NSLog(@"TXT: %@", TXTDictionary);
	/*id	x = TXTDictionary[@"sf"];
	NSString*	s = [NSString.alloc initWithData:TXTDictionary[@"sf"] encoding:NSUTF8StringEncoding];*/

	for (NSData* data in pNetService.addresses) {
		char				addressBuffer[100];
		struct sockaddr_in*	socketAddress = (struct sockaddr_in*)data.bytes;
		int					sockFamily = socketAddress->sin_family;
		if (AF_INET == sockFamily) {
			const char*	addressStr = inet_ntop(sockFamily,
											   &(socketAddress->sin_addr),
											   addressBuffer, sizeof(addressBuffer));
			
			int			iPort = ntohs(socketAddress->sin_port);
			if ((addressStr) &&
				(iPort)) {
				
				NSLog(@"Found hap service at %s:%d", addressStr, iPort);
				
				NSMutableDictionary*	accessoryDict = NSMutableDictionary.dictionary;
				accessoryDict[kAccessoriesDictServiceKey] = pNetService;
				accessoryDict[kAccessoriesDictPortKey] = [NSNumber numberWithInt:iPort];
				accessoryDict[kAccessoriesDictNameKey] = pNetService.name;
				accessoryDict[kAccessoriesDictAddressKey] = [NSString stringWithUTF8String:addressStr];
				NSString*	accessoryCI = [NSString.alloc initWithData:TXTDictionary[@"CI"]
															encoding:NSUTF8StringEncoding];
				NSNumberFormatter*	formatter = NSNumberFormatter.alloc.init;
				formatter.numberStyle = NSNumberFormatterDecimalStyle;
				accessoryDict[kAccessoriesDictCategoryKey] = [formatter numberFromString:accessoryCI];
				NSString*	accessorySF = [NSString.alloc initWithData:TXTDictionary[@"sf"]
															encoding:NSUTF8StringEncoding];
				accessoryDict[kAccessoriesDictIDKey] = TXTDictionary[@"id"];
				accessoryDict[kAccessoriesDictAvailableKey] = [NSNumber numberWithBool:([accessorySF isEqualToString:@"1"])];
				// ...
				
				[self.accessories addObject:accessoryDict];
				
				/*[NSUserDefaults.standardUserDefaults removeObjectForKey:@"AccessoryPairingID"];
				[NSUserDefaults.standardUserDefaults removeObjectForKey:@"AccessoryLTPK"];
				[NSUserDefaults.standardUserDefaults removeObjectForKey:@"iOSDeviceLTSKData"];
				[NSUserDefaults.standardUserDefaults removeObjectForKey:@"iOSDevicePairingID"];

				//[self setupPairingWithBaseURL:[NSString stringWithFormat:@"http://%s:%d", addressStr, port] andPassword:@"324-40-937"];
				[self setupPairingWithBaseURL:[NSString stringWithFormat:@"http://192.168.2.107:60086"] andPassword:@"240-12-014"];
				
				//[self verifyPairingWithIP:[NSString stringWithUTF8String:addressStr] andPort:port];
				//[self verifyPairingWithIP:@"192.168.2.107" andPort:60086];*/
			}
		}
	}
	
	if (!self.serviceResolvers.count) {
		// All resolved
		
		[self.tableView reloadData];
	}
}

/*
 netService:didNotResolve:
 
 */
- (void)netService:(NSNetService *)pNetService
	 didNotResolve:(NSDictionary *)pErrorDict {
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if ([self.serviceResolvers containsObject:pNetService]) {
		// Right now resolving
		
		[pNetService stop];
		[self.serviceResolvers removeObject:pNetService];
	}
	else {
		NSLog(@"NetService not found: %@", pNetService);
	}
}


#pragma mark - HAP

/*
 setupPairingForAccessory:withPassword:
 
 */

static const unsigned char  N[] = {  //initialize it with value of N
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xc9, 0x0f, 0xda, 0xa2,
	0x21, 0x68, 0xc2, 0x34, 0xc4, 0xc6, 0x62, 0x8b, 0x80, 0xdc, 0x1c, 0xd1,
	0x29, 0x02, 0x4e, 0x08, 0x8a, 0x67, 0xcc, 0x74, 0x02, 0x0b, 0xbe, 0xa6,
	0x3b, 0x13, 0x9b, 0x22, 0x51, 0x4a, 0x08, 0x79, 0x8e, 0x34, 0x04, 0xdd,
	0xef, 0x95, 0x19, 0xb3, 0xcd, 0x3a, 0x43, 0x1b, 0x30, 0x2b, 0x0a, 0x6d,
	0xf2, 0x5f, 0x14, 0x37, 0x4f, 0xe1, 0x35, 0x6d, 0x6d, 0x51, 0xc2, 0x45,
	0xe4, 0x85, 0xb5, 0x76, 0x62, 0x5e, 0x7e, 0xc6, 0xf4, 0x4c, 0x42, 0xe9,
	0xa6, 0x37, 0xed, 0x6b, 0x0b, 0xff, 0x5c, 0xb6, 0xf4, 0x06, 0xb7, 0xed,
	0xee, 0x38, 0x6b, 0xfb, 0x5a, 0x89, 0x9f, 0xa5, 0xae, 0x9f, 0x24, 0x11,
	0x7c, 0x4b, 0x1f, 0xe6, 0x49, 0x28, 0x66, 0x51, 0xec, 0xe4, 0x5b, 0x3d,
	0xc2, 0x00, 0x7c, 0xb8, 0xa1, 0x63, 0xbf, 0x05, 0x98, 0xda, 0x48, 0x36,
	0x1c, 0x55, 0xd3, 0x9a, 0x69, 0x16, 0x3f, 0xa8, 0xfd, 0x24, 0xcf, 0x5f,
	0x83, 0x65, 0x5d, 0x23, 0xdc, 0xa3, 0xad, 0x96, 0x1c, 0x62, 0xf3, 0x56,
	0x20, 0x85, 0x52, 0xbb, 0x9e, 0xd5, 0x29, 0x07, 0x70, 0x96, 0x96, 0x6d,
	0x67, 0x0c, 0x35, 0x4e, 0x4a, 0xbc, 0x98, 0x04, 0xf1, 0x74, 0x6c, 0x08,
	0xca, 0x18, 0x21, 0x7c, 0x32, 0x90, 0x5e, 0x46, 0x2e, 0x36, 0xce, 0x3b,
	0xe3, 0x9e, 0x77, 0x2c, 0x18, 0x0e, 0x86, 0x03, 0x9b, 0x27, 0x83, 0xa2,
	0xec, 0x07, 0xa2, 0x8f, 0xb5, 0xc5, 0x5d, 0xf0, 0x6f, 0x4c, 0x52, 0xc9,
	0xde, 0x2b, 0xcb, 0xf6, 0x95, 0x58, 0x17, 0x18, 0x39, 0x95, 0x49, 0x7c,
	0xea, 0x95, 0x6a, 0xe5, 0x15, 0xd2, 0x26, 0x18, 0x98, 0xfa, 0x05, 0x10,
	0x15, 0x72, 0x8e, 0x5a, 0x8a, 0xaa, 0xc4, 0x2d, 0xad, 0x33, 0x17, 0x0d,
	0x04, 0x50, 0x7a, 0x33, 0xa8, 0x55, 0x21, 0xab, 0xdf, 0x1c, 0xba, 0x64,
	0xec, 0xfb, 0x85, 0x04, 0x58, 0xdb, 0xef, 0x0a, 0x8a, 0xea, 0x71, 0x57,
	0x5d, 0x06, 0x0c, 0x7d, 0xb3, 0x97, 0x0f, 0x85, 0xa6, 0xe1, 0xe4, 0xc7,
	0xab, 0xf5, 0xae, 0x8c, 0xdb, 0x09, 0x33, 0xd7, 0x1e, 0x8c, 0x94, 0xe0,
	0x4a, 0x25, 0x61, 0x9d, 0xce, 0xe3, 0xd2, 0x26, 0x1a, 0xd2, 0xee, 0x6b,
	0xf1, 0x2f, 0xfa, 0x06, 0xd9, 0x8a, 0x08, 0x64, 0xd8, 0x76, 0x02, 0x73,
	0x3e, 0xc8, 0x6a, 0x64, 0x52, 0x1f, 0x2b, 0x18, 0x17, 0x7b, 0x20, 0x0c,
	0xbb, 0xe1, 0x17, 0x57, 0x7a, 0x61, 0x5d, 0x6c, 0x77, 0x09, 0x88, 0xc0,
	0xba, 0xd9, 0x46, 0xe2, 0x08, 0xe2, 0x4f, 0xa0, 0x74, 0xe5, 0xab, 0x31,
	0x43, 0xdb, 0x5b, 0xfc, 0xe0, 0xfd, 0x10, 0x8e, 0x4b, 0x82, 0xd1, 0x20,
	0xa9, 0x3a, 0xd2, 0xca, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
};

static const unsigned char	g[1] {
	0x05,
};

static const unsigned char	hkdfPairSetupEncryptSalt[23] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'E',  'n',  'c',  'r',  'y',
	'p',  't',  '-',  'S',  'a',  'l',  't',
};

static const unsigned char	hkdfPairSetupEncryptInfo[23] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'E',  'n',  'c',  'r',  'y',
	'p',  't',  '-',  'I',  'n',  'f',  'o',
};

static const unsigned char nonce_PSMsg05[12] = {
	0x00, 0x00, 0x00, 0x00,
	'P',  'S',  '-',  'M',  's',  'g',  '0',  '5',
};

static const unsigned char	hkdfPairSetupControllerSignSalt[31] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'C',  'o',  'n',  't',  'r',
	'o',  'l',  'l',  'e',  'r',  '-',  'S',  'i',  'g',  'n',  '-',  'S',  'a',  'l',  't',
};

static const unsigned char	hkdfPairSetupControllerSignInfo[31] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'C',  'o',  'n',  't',  'r',
	'o',  'l',  'l',  'e',  'r',  '-',  'S',  'i',  'g',  'n',  '-',  'I',  'n',  'f',  'o',
};

static const unsigned char nonce_PSMsg06[12] = {
	0x00, 0x00, 0x00, 0x00,
	'P',  'S',  '-',  'M',  's',  'g',  '0',  '6',
};

static const unsigned char	hkdfPairSetupAccessorySignSalt[30] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'A',  'c',  'c',  'e',  's',
	's',  'o',  'r',  'y',  '-',  'S',  'i',  'g',  'n',  '-',  'S',  'a',  'l',  't',
};

static const unsigned char	hkdfPairSetupAccessorySignInfo[30] = {
	'P',  'a',  'i',  'r',  '-',  'S',  'e',  't',  'u',  'p',  '-',  'A',  'c',  'c',  'e',  's',
	's',  'o',  'r',  'y',  '-',  'S',  'i',  'g',  'n',  '-',  'I',  'n',  'f',  'o',
};

/*const unsigned char	PairingID[36] = {
 0x38, 0x30, 0x44, 0x45, 0x37, 0x46, 0x39, 0x45, 0x2d, 0x33, 0x38, 0x33, 0x32, 0x2d, 0x34, 0x45, 
 0x33, 0x37, 0x2d, 0x41, 0x30, 0x45, 0x46, 0x2d, 0x38, 0x41, 0x30, 0x42, 0x42, 0x41, 0x34, 0x41, 
 0x33, 0x41, 0x36, 0x38,
 };*/




- (void)setupPairingForAccessory:(NSDictionary *)pAccessoryDict
					withPassword:(NSString *)pPassword {
	
	[LEAProgressHUDSharedInstance showWithMessage:@"Setup pairing..." allowInteraction:NO];

	__weak typeof(self) 		weakSelf = self;
	
	__block clsSRP6aClient*		pSRPClient = 0;
	__block unsigned			uiOSDeviceInfoLength = 0;
	__block unsigned char*		pucSRPSharedSecret = 0;
	__block unsigned char*		pucHKDFSessionKey = 0;
	
	void(^cleanUp)(void) = ^(void) {
		if (pSRPClient) {
			delete pSRPClient;
			pSRPClient = 0;
		}
		if (pucSRPSharedSecret) {
			delete[] pucSRPSharedSecret;
			pucSRPSharedSecret = 0;
		}
		if (pucHKDFSessionKey) {
			delete[] pucHKDFSessionKey;
			pucHKDFSessionKey = 0;
		}
		[weakSelf.hapConnection close];
		
		[LEAProgressHUDSharedInstance dismiss];
	};
	
	HAPTCPIPConnectionResponseHandlerType	responseHandlerPSM6 = ^(NSData* pHeader, NSData* pContent) {
		if (pContent) {
			NSLog(@"Received PS-M6 response data!");
			
			unsigned char			ucState = 0;
			const unsigned char*	pucEncryptedData = 0;
			unsigned				uEncryptedDataLength = 0;
			unsigned char			ucErrorCode = kTLVError_NoErr;
			
			clsTLV8Reader	tlv8ReaderPSM6((unsigned char*)pContent.bytes, (unsigned)pContent.length);
			unsigned char			ucTag;
			unsigned				uLength;
			const unsigned char*	pucData;
			while((tlv8ReaderPSM6.isValid()) &&
				  (tlv8ReaderPSM6.next(ucTag, uLength, pucData))) {
				switch (ucTag) {
					case kTLVType_State: {
						if (1 == uLength) {
							ucState = *pucData;
						}
						break;
					}
					case kTLVType_EncryptedData: {
						pucEncryptedData = pucData;
						uEncryptedDataLength = uLength;
						break;
					}
					case kTLVType_Error: {
						if (1 == uLength) {
							ucErrorCode = *pucData;
						}
						break;
					}
					default: {
						NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
					}
				}
			}	// while
			
			if ((6 == ucState) &&
				(kTLVError_NoErr == ucErrorCode) &&
				(pucEncryptedData)) {
				NSLog(@"Received encrypted data!");
				
				const unsigned	uSizeOfTag = 16;
				unsigned		uSubTLVDataLength = (uEncryptedDataLength - uSizeOfTag);
				unsigned char	aucTag[uSizeOfTag];
				unsigned char*	pucSubTLVData = new unsigned char[uSubTLVDataLength];
				*pucSubTLVData = 0;
				
				//print("[HAPASConnection] Encrypted data:", p_pucEncryptedData, uSubTLVDataLength);
				//print("[HAPASConnection] Tag:", p_pucEncryptedData + uSubTLVDataLength, uSizeOfTag);
				
				ChaChaPoly	ccpDecrypt;
				ccpDecrypt.setKey(pucHKDFSessionKey, 32);
				ccpDecrypt.setIV(nonce_PSMsg06, sizeof(nonce_PSMsg06));
				ccpDecrypt.decrypt(pucSubTLVData, pucEncryptedData, uSubTLVDataLength);
				ccpDecrypt.computeTag(aucTag, sizeof(aucTag));
				
				if ((0 == memcmp(aucTag, (pucEncryptedData + uSubTLVDataLength), uSizeOfTag)) &&
					(0 != *pucSubTLVData)) {	// First byte of decrypted data should be '0x01', '0x03' or '0x0A'
					// Tag and decrypted subTLV OK
					
					const unsigned char*	pucAccessoryPairingID = 0;
					unsigned				uAccessoryPairingIDLength = 0;
					const unsigned char*	pucAccessoryLTPK = 0;
					unsigned				uAccessoryLTPKLength = 0;
					const unsigned char*	pucAccessorySignature = 0;
					unsigned				uAccessorySignatureLength = 0;
					
					clsTLV8Reader			tlv8Reader(pucSubTLVData, uSubTLVDataLength);
					unsigned char			ucTag;
					unsigned				uLength;
					const unsigned char*	pucValue;
					while ((tlv8Reader.isValid()) &&
						   (tlv8Reader.next(ucTag, uLength, pucValue))) {
						switch (ucTag) {
							case kTLVType_Identifier:
								pucAccessoryPairingID = pucValue;
								uAccessoryPairingIDLength = uLength;
								break;
							case kTLVType_PublicKey:
								if (32 == uLength) {
									pucAccessoryLTPK = pucValue;
									uAccessoryLTPKLength = uLength;
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
					}
					
					if ((pucAccessoryPairingID) &&
						(uAccessoryPairingIDLength) &&
						(pucAccessoryLTPK) &&
						(uAccessoryLTPKLength) &&
						(pucAccessorySignature) &&
						(uAccessorySignatureLength)) {
						
						unsigned char	aucHKDFAccessoryX[32] = { 0 };
						if (HKDF512(hkdfPairSetupAccessorySignSalt, sizeof(hkdfPairSetupAccessorySignSalt),
									pucSRPSharedSecret, 64,
									hkdfPairSetupAccessorySignInfo, sizeof(hkdfPairSetupAccessorySignInfo),
									aucHKDFAccessoryX, sizeof(aucHKDFAccessoryX))) {
							
							// Concat: AccessoryInfo = AccessoryX[32], pucAccessoryPairingID, pucAccessoryLTPK[32]
							unsigned		uAccessoryInfoLength = (sizeof(aucHKDFAccessoryX) + uAccessoryPairingIDLength + uAccessoryLTPKLength);
							unsigned char*	pucAccessoryInfo = new unsigned char[uiOSDeviceInfoLength];
							unsigned char*	pCursor = pucAccessoryInfo;
							memcpy(pCursor, aucHKDFAccessoryX, sizeof(aucHKDFAccessoryX));		pCursor += sizeof(aucHKDFAccessoryX);
							memcpy(pCursor, pucAccessoryPairingID, uAccessoryPairingIDLength);	pCursor += uAccessoryPairingIDLength;
							memcpy(pCursor, pucAccessoryLTPK, uAccessoryLTPKLength);
							//_print("[HAPASConnection] iOSDeviceInfo:", auciOSDeviceInfo, uiOSDeviceInfoLength);
							
							bool	bSignVerifyResult = Ed25519::verify(pucAccessorySignature, pucAccessoryLTPK, pucAccessoryInfo, uAccessoryInfoLength);
							delete[] pucAccessoryInfo;
							
							// Compare signature
							if (bSignVerifyResult) {
								NSLog(@"Succeeded to verify signature!");
								
								NSData*	accessoryPairingIDData = [NSData dataWithBytes:pucAccessoryPairingID
																				length:uAccessoryPairingIDLength];
								NSData*	accessoryLTPKData = [NSData dataWithBytes:pucAccessoryLTPK
																		   length:uAccessoryLTPKLength];
								
								NSManagedObjectContext*	managedObjectContext = ((HASAppDelegate*)UIApplication.sharedApplication.delegate).persistentContainer.viewContext;
								
								NSManagedObject*		pairedAccessory = [NSEntityDescription insertNewObjectForEntityForName:@"HASPairedAccessory"
																								  inManagedObjectContext:managedObjectContext];
								
								[pairedAccessory setValue:pAccessoryDict[kAccessoriesDictIDKey]
												   forKey:@"id"];
								[pairedAccessory setValue:pAccessoryDict[kAccessoriesDictNameKey]
												   forKey:@"name"];
								[pairedAccessory setValue:pAccessoryDict[kAccessoriesDictPortKey]
												   forKey:@"port"];
								[pairedAccessory setValue:accessoryPairingIDData
												   forKey:@"pairingID"];
								[pairedAccessory setValue:accessoryLTPKData
												   forKey:@"ltpk"];
								[pairedAccessory setValue:pAccessoryDict[kAccessoriesDictCategoryKey]
												   forKey:@"category"];
								
								NSError*	error = 0;
								if (![managedObjectContext save:&error]) {
									NSLog(@"Failed to save managedObjectContext (%@)", error);
								}
								
								dispatch_async(dispatch_get_main_queue(), ^{
									[weakSelf dismissViewControllerAnimated:YES
																 completion:^{
																	 cleanUp();
																 }];
								});
							}
							else {
								NSLog(@"Failed to verify signature!");
								cleanUp();
							}
						}
						else {
							NSLog(@"Failed to create HKDFAccessoryX!");
							cleanUp();
						}
					}
					else {
						NSLog(@"Decrypt produced invalid data!");
						cleanUp();
					}
				}
				else {
					NSLog(@"Decryption failed!");
					cleanUp();
				}
				delete[] pucSubTLVData;
			}
			else {
				NSLog(@"Error or invalid PS-M6 data!");
				cleanUp();
			}
		}
		else {
			NSLog(@"No PS-M6 response data!");
			cleanUp();
		}
	};
	
	HAPTCPIPConnectionResponseHandlerType	responseHandlerPSM4 = ^(NSData* pHeader, NSData* pContent) {
		if (pContent) {
			NSLog(@"Received PS-M4 response data!");
						
			unsigned char			ucState = 0;
			const unsigned char*	pucAccessorySRPProof = 0;
			unsigned				uAccessorySRPProofLength = 0;
			unsigned char			ucErrorCode = kTLVError_NoErr;
			
			clsTLV8Reader	tlv8ReaderPSM4((unsigned char*)pContent.bytes, (unsigned)pContent.length);
			unsigned char			ucTag;
			unsigned				uLength;
			const unsigned char*	pucData;
			while((tlv8ReaderPSM4.isValid()) &&
				  (tlv8ReaderPSM4.next(ucTag, uLength, pucData))) {
				switch (ucTag) {
					case kTLVType_State: {
						if (1 == uLength) {
							ucState = *pucData;
						}
						break;
					}
					case kTLVType_Proof: {
						if (64 == uLength) {
							pucAccessorySRPProof = pucData;
							uAccessorySRPProofLength = uLength;
						}
						break;
					}
					case kTLVType_Error: {
						if (1 == uLength) {
							ucErrorCode = *pucData;
						}
						break;
					}
					default: {
						NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
					}
				}
			}	// while
			
			if ((4 == ucState) &&
				(kTLVError_NoErr == ucErrorCode) &&
				(pucAccessorySRPProof)) {
				
				if (SRP_SUCCESS == pSRPClient->verify(pucAccessorySRPProof, uAccessorySRPProofLength)) {
					NSLog(@"Successfully verified accessories proof!");
					
					//ED25519::iOSDevice LongTermPublicKey
					unsigned char 	auciOSDeviceLTPK[32];
					Ed25519::derivePublicKey(auciOSDeviceLTPK, (const unsigned char*)weakSelf.iOSDeviceLTSK.bytes);
					
					// iOSDevice PairingID
					
					unsigned char	aucHKDFiOSDeviceX[32] = { 0 };
					if (HKDF512(hkdfPairSetupControllerSignSalt, sizeof(hkdfPairSetupControllerSignSalt),
								pucSRPSharedSecret, 64,
								hkdfPairSetupControllerSignInfo, sizeof(hkdfPairSetupControllerSignInfo),
								aucHKDFiOSDeviceX, sizeof(aucHKDFiOSDeviceX))) {
						
						// Concat: iOSDeviceInfo = iOSDeviceX[32], puciOSDevicePairingID, puciOSDeviceLTPK[32]
						uiOSDeviceInfoLength = (unsigned)(sizeof(aucHKDFiOSDeviceX) + self.iOSDevicePairingID.length + sizeof(auciOSDeviceLTPK));
						unsigned char*	puciOSDeviceInfo = new unsigned char[uiOSDeviceInfoLength];
						unsigned char*	pCursor = puciOSDeviceInfo;
						memcpy(pCursor, aucHKDFiOSDeviceX, sizeof(aucHKDFiOSDeviceX));					pCursor += sizeof(aucHKDFiOSDeviceX);
						memcpy(pCursor, weakSelf.iOSDevicePairingID.bytes, weakSelf.iOSDevicePairingID.length);	pCursor += self.iOSDevicePairingID.length;
						memcpy(pCursor, auciOSDeviceLTPK, sizeof(auciOSDeviceLTPK));
						
						unsigned char		auciOSDeviceSignature[64];
						Ed25519::sign(auciOSDeviceSignature, (const unsigned char*)weakSelf.iOSDeviceLTSK.bytes, auciOSDeviceLTPK, puciOSDeviceInfo, uiOSDeviceInfoLength);
						delete[] puciOSDeviceInfo;
						
						clsTLV8Writer	subTLV8Writer((unsigned)(1 + 1 + weakSelf.iOSDevicePairingID.length) + (1 + 1 + sizeof(auciOSDeviceLTPK)) + (1 + 1 + sizeof(auciOSDeviceSignature)));
						subTLV8Writer.add(kTLVType_Identifier, (unsigned)weakSelf.iOSDevicePairingID.length, (unsigned char*)weakSelf.iOSDevicePairingID.bytes);
						subTLV8Writer.add(kTLVType_PublicKey, sizeof(auciOSDeviceLTPK), auciOSDeviceLTPK);
						subTLV8Writer.add(kTLVType_Signature, sizeof(auciOSDeviceSignature), auciOSDeviceSignature);
						
						const unsigned	uSizeOfTag = 16;
						unsigned char	aucTag[uSizeOfTag];
						unsigned		uSubTLVStreamLength = subTLV8Writer.length();
						unsigned char*	pucEncryptedSubTLV = new unsigned char[(uSubTLVStreamLength + sizeof(aucTag))];
						//DEBUG_HAPASCONNECTION(DEBUG_OUTPUT.printf("[HAPASConnection] uSubTLVStreamLength: %u\n", uSubTLVStreamLength));
						
						pucHKDFSessionKey = new unsigned char[32];
						if (HKDF512(hkdfPairSetupEncryptSalt, sizeof(hkdfPairSetupEncryptSalt),
									pucSRPSharedSecret, 64,
									hkdfPairSetupEncryptInfo, sizeof(hkdfPairSetupEncryptInfo),
									pucHKDFSessionKey, 32)) {
							
							ChaChaPoly	ccpEncrypt;
							ccpEncrypt.setKey(pucHKDFSessionKey, 32);
							ccpEncrypt.setIV(nonce_PSMsg05, sizeof(nonce_PSMsg05));
							ccpEncrypt.encrypt(pucEncryptedSubTLV, subTLV8Writer.TLVStream(), uSubTLVStreamLength);
							ccpEncrypt.computeTag(aucTag, sizeof(aucTag));
							
							//print("[HAPASConnection] EncryptedSubTLV:", pucEncryptedSubTLV, (uSubTLVStreamLength + sizeof(aucTag)));
							memcpy(pucEncryptedSubTLV + uSubTLVStreamLength, aucTag, sizeof(aucTag));
							//print("[HAPASConnection] EncryptedSubTLV+authTag:", pucEncryptedSubTLV, (uSubTLVStreamLength + sizeof(aucTag)));
							
							clsTLV8Writer	tlv8WriterPSM5((1 + 1 + 1) + (1 + 1 + (uSubTLVStreamLength + sizeof(aucTag))));
							tlv8WriterPSM5.addUC(kTLVType_State, 5);
							tlv8WriterPSM5.add(kTLVType_EncryptedData, (uSubTLVStreamLength + sizeof(aucTag)), pucEncryptedSubTLV);
														
							NSString*		headerPSM5 = [NSString stringWithFormat:@"POST /pair-setup HTTP/1.1\r\nContent-Type: application/pairing+tlv8\r\nContent-Length: %u\r\n\r\n", tlv8WriterPSM5.length()];
							
							NSMutableData*	postDataPSM5 = NSMutableData.alloc.init;
							[postDataPSM5 appendBytes:headerPSM5.UTF8String
											   length:strlen(headerPSM5.UTF8String)];
							[postDataPSM5 appendBytes:tlv8WriterPSM5.TLVStream()
											   length:tlv8WriterPSM5.length()];
							
							NSLog(@"Sending PS-M5 reqeust");
							[weakSelf.hapConnection sendData:postDataPSM5
										 withResponseTimeout:30
										  andResponseHandler:responseHandlerPSM6];
						}
						else {
							NSLog(@"HKDFSessionKey failed!");
							cleanUp();
						}
						delete[] pucEncryptedSubTLV;
					}
					else {
						NSLog(@"HKDFiOSDeviceX failed!");
						cleanUp();
					}
				}
				else {
					NSLog(@"Accessory proof invalid!");
					cleanUp();
				}
			}
			else {
				NSLog(@"Error or invalid data PS-M4 data!");
				cleanUp();
			}
		}
		else {
			NSLog(@"No PS-M4 response data!");
			cleanUp();
		}
	};
	
	HAPTCPIPConnectionResponseHandlerType	responseHandlerPSM2 = ^(NSData* pHeader, NSData* pContent) {
		if (pContent) {
			NSLog(@"Received PS-M2 response data!");											
			
			unsigned char			ucState = 0;
			const unsigned char*	pucAccessorySRPPublicKey = 0;
			unsigned				uAccessorySRPPublicKeyLength = 0;
			const unsigned char*	pucAccessorySRPSalt = 0;
			unsigned				uAccessorySRPSaltLength = 0;
			unsigned char			ucErrorCode = kTLVError_NoErr;
			
			clsTLV8Reader	tlv8ReaderPSM2((unsigned char*)pContent.bytes, (unsigned)pContent.length);
			unsigned char			ucTag;
			unsigned				uLength;
			const unsigned char*	pucData;
			while((tlv8ReaderPSM2.isValid()) &&
				  (tlv8ReaderPSM2.next(ucTag, uLength, pucData))) {
				switch (ucTag) {
					case kTLVType_State: {
						if (1 == uLength) {
							ucState = *pucData;
						}
						break;
					}
					case kTLVType_PublicKey: {
						if (384 == uLength) {
							pucAccessorySRPPublicKey = pucData;
							uAccessorySRPPublicKeyLength = uLength;
						}
						break;
					}
					case kTLVType_Salt: {
						if (16 == uLength) {
							pucAccessorySRPSalt = pucData;
							uAccessorySRPSaltLength = uLength;
						}
						break;
					}
					case kTLVType_Error: {
						if (1 == uLength) {
							ucErrorCode = *pucData;
						}
						break;
					}
					default: {
						NSLog(@"Ignoring unknown tag: %x (%u)!", ucTag, uLength);
					}
				}
			}	// while
			
			//Verify PS-M2 data
			if ((2 == ucState) &&
				(kTLVError_NoErr == ucErrorCode) &&
				(pucAccessorySRPPublicKey) &&
				(pucAccessorySRPSalt)) {
				
				// Create PSM3 data
				pSRPClient = new clsSRP6aClient();
				pSRPClient->set_username("Pair-Setup");
				pSRPClient->set_params(N, sizeof(N), g, sizeof(g), pucAccessorySRPSalt, uAccessorySRPSaltLength);
				pSRPClient->set_auth_password(pPassword.UTF8String);
				
				unsigned char*	pucCLIPublicKey = 0;
				pSRPClient->gen_pub(&pucCLIPublicKey);
				//[weakSelf printArray:pucCLIPublicKey withLength:384 andComment:@"Public key"];
				
				pSRPClient->compute_key(&pucSRPSharedSecret, pucAccessorySRPPublicKey, uAccessorySRPPublicKeyLength);
				//[weakSelf printArray:pucSRPSharedSecret withLength:64 andComment:@"Shared secret"];
				
				unsigned char*	pucCLIProof = 0;
				pSRPClient->respond(&pucCLIProof);	// IMPORTANT -> Call CLI.respond before CLI.verify
				
				//[weakSelf printArray:pucCLIProof withLength:64 andComment:@"Proof"];
				
				clsTLV8Writer	tlv8WriterPSM3((1 + 1 + 1) + (1 + 1 + 255 + 1 + 1 + 129) + (1 + 1 + 64));
				tlv8WriterPSM3.addUC(kTLVType_State, 3);
				tlv8WriterPSM3.add(kTLVType_PublicKey, 384, pucCLIPublicKey);
				tlv8WriterPSM3.add(kTLVType_Proof, 64, pucCLIProof);
				
				NSString*		headerPSM3 = [NSString stringWithFormat:@"POST /pair-setup HTTP/1.1\r\nContent-Type: application/pairing+tlv8\r\nContent-Length: %u\r\n\r\n", tlv8WriterPSM3.length()];
				
				NSMutableData*	postDataPSM3 = NSMutableData.alloc.init;
				[postDataPSM3 appendBytes:headerPSM3.UTF8String
								   length:strlen(headerPSM3.UTF8String)];
				[postDataPSM3 appendBytes:tlv8WriterPSM3.TLVStream()
								   length:tlv8WriterPSM3.length()];
				
				NSLog(@"Sending PS-M3 reqeust");
				[weakSelf.hapConnection sendData:postDataPSM3
							 withResponseTimeout:45
							  andResponseHandler:responseHandlerPSM4];
			}
			else {
				NSLog(@"Error or invalid data PS-M2 data!");
				cleanUp();
			}
		}
		else {
			NSLog(@"No PS-M2 response data!");
			cleanUp();
		}
	};

	NSNetService*	service = pAccessoryDict[kAccessoriesDictServiceKey];
	self.hapConnection = [HAPTCPIPConnection.alloc initWithService:service];
	
	clsTLV8Writer	tlv8WriterPSM1((1 + 1 + 1) + (1 + 1 + 1));
	tlv8WriterPSM1.addUC(kTLVType_State, 1);							// State: M1
	tlv8WriterPSM1.addUC(kTLVType_Method, HAPMethod_PairSetupNonMFI);	// Method: 0 Pair-Setup Non-MFI
	
	NSString*		headerPSM1 = [NSString stringWithFormat:@"POST /pair-setup HTTP/1.1\r\nContent-Type: application/pairing+tlv8\r\nContent-Length: %u\r\n\r\n", tlv8WriterPSM1.length()];
	
	NSMutableData*	postDataPSM1 = NSMutableData.alloc.init;
	[postDataPSM1 appendBytes:headerPSM1.UTF8String
					   length:strlen(headerPSM1.UTF8String)];
	[postDataPSM1 appendBytes:tlv8WriterPSM1.TLVStream()
					   length:tlv8WriterPSM1.length()];
	
	NSLog(@"Sending PS-M1 reqeust");
	[self.hapConnection sendData:postDataPSM1
			 withResponseTimeout:30
			  andResponseHandler:responseHandlerPSM2];
}

/*
 iOSDeviceLTSK
 
 */
- (NSData *)iOSDeviceLTSK {
	
	NSData*	iOSDeviceLTSKData = [NSUserDefaults.standardUserDefaults objectForKey:@"iOSDeviceLTSKData"];
	if (!iOSDeviceLTSKData) {
		unsigned char	auciOSDeviceLTSK[32];
		arc4random_buf(auciOSDeviceLTSK, sizeof(auciOSDeviceLTSK));
		iOSDeviceLTSKData = [NSData dataWithBytes:auciOSDeviceLTSK
										   length:sizeof(auciOSDeviceLTSK)];
		[NSUserDefaults.standardUserDefaults setObject:iOSDeviceLTSKData
												forKey:@"iOSDeviceLTSKData"];
	}
	return iOSDeviceLTSKData;
}

/*
 iOSDevicePairingID
 
 */
- (NSData *)iOSDevicePairingID {
	
	// iOSDevice PairingID
	NSData*	iOSDevicePairingIDData = [NSUserDefaults.standardUserDefaults objectForKey:@"iOSDevicePairingID"];
	if (!iOSDevicePairingIDData) {
		unsigned char	auciOSDevicePairingID[36];
		/*arc4random_buf(auciOSDevicePairingID, sizeof(auciOSDevicePairingID));*/
		unsigned char	aucAlphabet[] = {
			// 0..9
			0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
			// A..Z
			0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
			0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
		};
		for (unsigned u=0; u<sizeof(auciOSDevicePairingID); ++u) {
			auciOSDevicePairingID[u] = aucAlphabet[(arc4random() % sizeof(aucAlphabet))];
		}
		auciOSDevicePairingID[8] = 
		auciOSDevicePairingID[12] = 
		auciOSDevicePairingID[16] = 
		auciOSDevicePairingID[20] = 0x2D;	// '-'
		
		iOSDevicePairingIDData = [NSData dataWithBytes:auciOSDevicePairingID
												length:sizeof(auciOSDevicePairingID)];
		[NSUserDefaults.standardUserDefaults setObject:iOSDevicePairingIDData
												forKey:@"iOSDevicePairingID"];
	}
	return iOSDevicePairingIDData;
}


// HELPERS

/*
 * print(const unsigned char*)
 *
 */
- (void)printArray:(const unsigned char *)p_pucArray
		withLength:(unsigned)p_uLength
		andComment:(NSString *)p_Comment {
	
	NSLog(@"%@", p_Comment);
	
	NSMutableString*	output = [NSMutableString.alloc initWithString:@"\n"];	
	for (unsigned j = 1; j <= p_uLength; ++j) {
		[output appendFormat:@"0x%02x, ", p_pucArray[j - 1]];
		if (!(j % 16)) {
			[output appendString:@"\n"];
		}
	}
	NSLog(@"%@", output);
}

/*
 * print(const char*)
 *
 */
- (void)printString:(const char *)p_pcString
		withComment:(NSString *)p_Comment {
	
	NSLog(@"%@", p_Comment);
	
	NSMutableString*	output = [NSMutableString.alloc initWithString:@"\n"];	
	for (unsigned j = 1; j <= strlen(p_pcString); ++j) {
		[output appendFormat:@"%c, ", p_pcString[j - 1]];
		if (!(j % 16)) {
			[output appendString:@"\n"];
		}
	}
	NSLog(@"%@", output);
}

@end









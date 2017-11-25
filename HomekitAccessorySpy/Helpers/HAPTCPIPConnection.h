//
//  HAPTCPIPConnection.mm
//  HomekitAccessorySpy
//
//  Created by Hartmut on 30.10.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <arpa/inet.h>


/**
 HAPTCPIPConnection
 
 Based on: https://gist.github.com/rjungemann/446256
 */
@interface HAPTCPIPConnection : NSObject <NSStreamDelegate>

typedef void (^HAPTCPIPConnectionResponseHandlerType)(NSData* pHeader, NSData* pContent);

@property (strong, nonatomic) HAPTCPIPConnectionResponseHandlerType	eventHandler;

@property (strong, nonatomic) NSData*			Accessory2ControllerKey;
@property (strong, nonatomic) NSData*			Controller2AccessoryKey;

- (instancetype)initWithIP:(NSString *)p_IP
				   andPort:(NSUInteger)p_Port;
- (instancetype)initWithService:(NSNetService *)pService;

- (BOOL)open;
- (void)close;

- (BOOL)	   sendData:(NSData *)p_Data
	withResponseTimeout:(NSTimeInterval)pResponseTimeout
	 andResponseHandler:(HAPTCPIPConnectionResponseHandlerType)pResponseHandler;

@end







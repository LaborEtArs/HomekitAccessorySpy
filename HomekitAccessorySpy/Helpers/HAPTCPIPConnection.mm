//
//  HAPTCPIPConnection.mm
//  HomekitAccessorySpy
//
//  Created by Hartmut on 30.10.17.
//  Copyright © 2017 LaborEtArs. All rights reserved.
//
#include <cstring>
#include "../Crypto/ChaChaPoly.h"

#import "HAPTCPIPConnection.h"


/*
 * stcHAPTCPIPConnectionRollingNonce
 *
 */
typedef struct _stcHAPTCPIPConnectionRollingNonce {
	static const unsigned	length = 12;
	
	unsigned char	m_ucBuffer[length];
	
	_stcHAPTCPIPConnectionRollingNonce(void) {
		memset(m_ucBuffer, 0, (sizeof(unsigned char) * length));
	}
	
	operator const unsigned char*(void) {
		return m_ucBuffer;
	}
	
	_stcHAPTCPIPConnectionRollingNonce& operator++(void) {
		uint64_t*	pLast8Bytes = (uint64_t*)(m_ucBuffer + 4);	// Get last 8 bytes of buffer
		++(*pLast8Bytes);										// Increment these last 8 bytes by 1
		return *this;
	}
} stcHAPTCPIPConnectionRollingNonce;


/**
 HAPTCPIPConnection
 
 Based on: https://gist.github.com/rjungemann/446256
 */
@interface HAPTCPIPConnection () <NSStreamDelegate>

@property (assign, nonatomic) CFReadStreamRef	readStream;
@property (assign, nonatomic) CFWriteStreamRef	writeStream;

@property (strong, nonatomic) NSInputStream*	inputStream;
@property (strong, nonatomic) NSOutputStream*	outputStream;

@property (strong, nonatomic) HAPTCPIPConnectionResponseHandlerType	responseHandler;
@property (strong, nonatomic) NSTimer*			timeoutTimer;

@end


/**
 HAPTCPIPConnection
 
 */
@implementation HAPTCPIPConnection {
	stcHAPTCPIPConnectionRollingNonce	Accessory2ControllerNonce;
	stcHAPTCPIPConnectionRollingNonce	Controller2AccessoryNonce;
}

/*
 initWithIP:andPort:
 
 */
- (instancetype)initWithIP:(NSString *)p_IP
				   andPort:(NSUInteger)p_Port {
	
	if (self = [super init]) {
		CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)p_IP, (unsigned)p_Port, &_readStream, &_writeStream);
		if(CFWriteStreamOpen(_writeStream)) {
			self.inputStream = (__bridge NSInputStream *)_readStream;
			self.outputStream = (__bridge NSOutputStream *)_writeStream;
			
			[self open];
		}
		else {
			NSLog(@"[HAPTCPIPConnection] FAILED to open 'writeStream'!");
		}
	}
	return self;
}

/*
 initWithService:
 
 */
- (instancetype)initWithService:(NSNetService *)pService {
	
	if (self = [super init]) {
		
		[pService getInputStream:&_inputStream
					outputStream:&_outputStream];
		if((self.inputStream) &&
		   (self.outputStream)) {
			
			[self open];
		}
		else {
			NSLog(@"[HAPTCPIPConnection] FAILED to get streams!");
		}
	}
	return self;
}

/*
 open
 
 */
- (BOOL)open {
	//NSLog(@"[HAPTCPIPConnection] %s", __PRETTY_FUNCTION__);
	
	BOOL	result = YES;
	
	[self.inputStream setDelegate:self];
	[self.outputStream setDelegate:self];
	
	[self.inputStream scheduleInRunLoop:NSRunLoop.currentRunLoop 
								forMode:NSDefaultRunLoopMode];
	[self.outputStream scheduleInRunLoop:NSRunLoop.currentRunLoop
								 forMode:NSDefaultRunLoopMode];
	
	[self.inputStream open];
	[self.outputStream open];
	
	return result;
}

/*
 close
 
 */
- (void)close {
	//NSLog(@"[HAPTCPIPConnection] %s", __PRETTY_FUNCTION__);
	
	[self.inputStream close];
	[self.outputStream close];
	
	[self.inputStream removeFromRunLoop:NSRunLoop.currentRunLoop
								forMode:NSDefaultRunLoopMode];
	[self.outputStream removeFromRunLoop:NSRunLoop.currentRunLoop
								 forMode:NSDefaultRunLoopMode];
	
	[self.inputStream setDelegate:nil];
	[self.outputStream setDelegate:nil];
	
	self.inputStream = nil;
	self.outputStream = nil;
}

/*
 sendData:withResponseTimeout:andResponseHandler:
 
 */
- (BOOL)   	   sendData:(NSData *)p_Data
	withResponseTimeout:(NSTimeInterval)pResponseTimeout
	 andResponseHandler:(HAPTCPIPConnectionResponseHandlerType)pResponseHandler {
	
	BOOL	bResult = NO;
	
	if (self.timeoutTimer) {
		NSLog(@"[HAPTCPIPConnection] WARNING: Invalidating existing timeout timer!");
		[self.timeoutTimer invalidate];
		self.timeoutTimer = nil;
	}
	
	NSData*	dataToSend = p_Data;
	
	if ((self.Accessory2ControllerKey) &&
		(self.Controller2AccessoryKey)) {
		// Secure session -> Encrypt
		
		const unsigned	cuMaxDecryptedFrameLength = 1024;
		//const unsigned	cuMaxEncryptedFrameLength = 2/*length*/ + cuMaxDecryptedFrameLength + 16/*authTag*/;

		unsigned	uFrameCount = (unsigned)((p_Data.length / cuMaxDecryptedFrameLength) + ((p_Data.length % cuMaxDecryptedFrameLength) ? 1 : 0));
		unsigned	uFinalMessageLength = (unsigned)(p_Data.length + (uFrameCount * (2/*length*/ + 16/*authTag*/)));
		
		/*[self printArray:(const unsigned char*)self.Controller2AccessoryKey.bytes
			  withLength:(unsigned)self.Controller2AccessoryKey.length
			  andComment:@"Controller2AccessoryKey"];*/
		/*[self printArray:(const unsigned char*)self.Accessory2ControllerKey.bytes
			  withLength:(unsigned)self.Accessory2ControllerKey.length
			  andComment:@"Accessory2ControllerKey"];*/
		
		NSMutableData*			encryptedData = [NSMutableData dataWithCapacity:uFinalMessageLength];
		const unsigned char*	pPlainData = (const unsigned char*)p_Data.bytes;	
		for (unsigned uFrame = 0; uFrame < uFrameCount; ++uFrame) {
			uint16_t		u16FrameLength = ((uFrame < (uFrameCount - 1))
											? cuMaxDecryptedFrameLength
											: (p_Data.length - ((uFrameCount - 1) * cuMaxDecryptedFrameLength)));
			
			ChaChaPoly		ccpEncrypt;
			ccpEncrypt.setKey((const unsigned char*)self.Controller2AccessoryKey.bytes, self.Controller2AccessoryKey.length);
			ccpEncrypt.setIV(Controller2AccessoryNonce, Controller2AccessoryNonce.length);
			ccpEncrypt.addAuthData(&u16FrameLength, 2);
			
			NSMutableData*	encryptedChunk = [NSMutableData dataWithLength:u16FrameLength];
			ccpEncrypt.encrypt((unsigned char*)encryptedChunk.mutableBytes, pPlainData, u16FrameLength);
			
			NSMutableData*	authTag = [NSMutableData dataWithLength:16];
			ccpEncrypt.computeTag((unsigned char*)authTag.mutableBytes, 16);

			[encryptedData appendBytes:&u16FrameLength
								length:sizeof(u16FrameLength)];
			[encryptedData appendData:encryptedChunk];
			[encryptedData appendData:authTag];
			
			++Controller2AccessoryNonce;
			pPlainData += u16FrameLength;
		}
		dataToSend = encryptedData;
	}
	
	self.responseHandler = pResponseHandler;
	if (dataToSend.length == [self.outputStream write:(const unsigned char*)dataToSend.bytes
											maxLength:dataToSend.length]) {
		//NSLog(@"[HAPTCPIPConnection] Succeeded to send %u bytes!", (unsigned)dataToSend.length);
		
		self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:pResponseTimeout
															 target:self 
														   selector:@selector(timeoutTimerFired:) 
														   userInfo:nil
															repeats:NO];
		bResult = YES;
	}
	else {
		NSLog(@"[HAPTCPIPConnection] FAILED to send data!");
		if (self.responseHandler) {
			self.responseHandler(0, 0);
			self.responseHandler = nil;
		}
	}
	return bResult;
}

#pragma mark - NSSTREAMDELEGATE

/*
 stream:handleEvent:
 
 */
- (void)stream:(NSStream *)p_Stream
   handleEvent:(NSStreamEvent)pEvent {
	//NSLog(@"[HAPTCPIPConnection] %s", __PRETTY_FUNCTION__);
	
	switch(pEvent) {
		case NSStreamEventOpenCompleted: {
			//NSLog(@"[HAPTCPIPConnection] Stream opened");
			break;
		}
			
		case NSStreamEventHasSpaceAvailable: {
			if(p_Stream == self.outputStream) {
				//NSLog(@"[HAPTCPIPConnection] outputStream is ready."); 
			}
			break;
		}
			
		case NSStreamEventHasBytesAvailable: {
			if(p_Stream == self.inputStream) {
				//NSLog(@"[HAPTCPIPConnection] inputStream is ready (has data).");
				
				if (self.timeoutTimer) {
					[self.timeoutTimer invalidate];
					self.timeoutTimer = nil;
				}
				
				NSMutableData*	messageData = NSMutableData.alloc.init;
				while (((NSInputStream*)p_Stream).hasBytesAvailable) {
					uint8_t		buf[1024];
					NSInteger	length = [self.inputStream read:buf
													maxLength:sizeof(buf)];
					
					if(0 < length) {
						[messageData appendBytes:buf
										  length:length];
					}
					else {
						NSLog(@"[HAPTCPIPConnection] FAILED to read data!");
					}
					
					if (!((NSInputStream*)p_Stream).hasBytesAvailable) {
						// Wait a second for more data to arrive
						sleep(1);
					}
				}
				
				if ((self.Accessory2ControllerKey) &&
					(self.Controller2AccessoryKey)) {
					// Secure session -> Decrypt
					// Data needs decryption
					
					NSMutableData*	decryptedData = NSMutableData.alloc.init;
					
					const unsigned	cuMaxDecryptedFrameLength = 1024;
					const unsigned	cuMaxEncryptedFrameLength = 2/*length*/ + cuMaxDecryptedFrameLength + 16/*authTag*/;
					
					unsigned		uFrameCount = (unsigned)((messageData.length / cuMaxEncryptedFrameLength) + ((messageData.length % cuMaxEncryptedFrameLength) ? 1 : 0));
					
					if (uFrameCount) {
						const unsigned char*	pEncryptedData = (const unsigned char*)messageData.bytes;
						for (unsigned uFrame = 0; uFrame < uFrameCount; ++uFrame) {
							short	sFrameDataLength = *((const short*)pEncryptedData);
							
							ChaChaPoly	ccpDecrypt;
							ccpDecrypt.setKey((const unsigned char*)self.Accessory2ControllerKey.bytes, self.Accessory2ControllerKey.length);
							ccpDecrypt.setIV(Accessory2ControllerNonce, Accessory2ControllerNonce.length);
							ccpDecrypt.addAuthData(pEncryptedData, 2);	// First two bytes (length) is used as AAD also
							
							NSMutableData*	decryptedChunk = [NSMutableData dataWithLength:sFrameDataLength];
							ccpDecrypt.decrypt((unsigned char*)decryptedChunk.mutableBytes, (pEncryptedData + 2), sFrameDataLength);
							
							if (ccpDecrypt.checkTag((pEncryptedData + 2/*length*/ + sFrameDataLength), 16)) {
								// Increment the rolling nonce
								++Accessory2ControllerNonce;
								[decryptedData appendData:decryptedChunk];
								
								pEncryptedData += (2/*length*/ + sFrameDataLength + 16/*authTag*/);
							}
							else {
								NSLog(@"[HAPTCPIPConnection] FAILED to verify tag!");
								decryptedData = nil;
								break;
							}
						}	// for
						/*const unsigned char	trailingZero[1] = { 0 };
						[decryptedData appendBytes:trailingZero
											length:sizeof(trailingZero)];*/
					}
					else {
						NSLog(@"[HAPTCPIPConnection] Invalid encrypted data!");
						decryptedData = nil;
					}
					messageData = decryptedData;
				}
				
				//
				// CAUTION: a response handler might call 'send...' which will replace the response handler itself...
				HAPTCPIPConnectionResponseHandlerType	responseHandler = self.responseHandler;
				self.responseHandler = nil;
				
				if (messageData) {
					int		messageType = 0;
					NSRange	rangeOfHeader;
					if (NSNotFound != (rangeOfHeader = [messageData rangeOfData:[@"HTTP/1.1" dataUsingEncoding:NSUTF8StringEncoding]
																		options:0 
																		  range:NSMakeRange(0, messageData.length)]).location) {
						//NSLog(@"[HAPTCPIPConnection] HTTP header detected!");
						messageType = 1;
					}
					else if (NSNotFound != (rangeOfHeader = [messageData rangeOfData:[@"EVENT/1.0" dataUsingEncoding:NSUTF8StringEncoding]
																			 options:0 
																			   range:NSMakeRange(0, messageData.length)]).location) {
						NSLog(@"[HAPTCPIPConnection] EVENT header detected!");
						messageType = 2;
					}
					else {
						NSLog(@"[HAPTCPIPConnection] UNKNOWN header!");
					}
					
					NSData*	header = nil;
					NSData*	responseContent = nil;
					NSRange	rangeOfEndOfHeader = [messageData rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
														   options:0 
															 range:NSMakeRange(0, messageData.length)];
					if (NSNotFound != rangeOfEndOfHeader.location) {
						header = [messageData subdataWithRange:NSMakeRange(0, rangeOfEndOfHeader.location)];
						//NSLog(@"[HAPTCPIPConnection] Received header: %@", [NSString.alloc initWithData:header encoding:NSUTF8StringEncoding]);
						
						if ((rangeOfEndOfHeader.location + rangeOfEndOfHeader.length) < messageData.length) {
							responseContent = [messageData subdataWithRange:NSMakeRange((rangeOfEndOfHeader.location + rangeOfEndOfHeader.length), (messageData.length - (rangeOfEndOfHeader.location + rangeOfEndOfHeader.length)))];
							//NSLog(@"[HAPTCPIPConnection] Received content length: %lu", responseContent.length);
						}
					}
					
					if ((1 == messageType) &&
						(responseHandler)) {
						
						responseHandler(header, responseContent);
					}
					if (2 == messageType) {
						if (self.eventHandler) {
							self.eventHandler(header, responseContent);
						}
						else {
							NSLog(@"[HAPTCPIPConnection] Received event, but no event handler registered!");
						}
					}
				}
				else {
					if (responseHandler) {
						responseHandler(0, 0);
					}
				}
			} 
			break;
		}
		case NSStreamEventErrorOccurred: {
			NSLog(@"[HAPTCPIPConnection] ERROR: Can't connect to the host");
			break;
		}
			
		case NSStreamEventEndEncountered: {
			//NSLog(@"[HAPTCPIPConnection] End encountered");
			[self close];
			break;
		}
			
		case NSStreamEventNone: {
			NSLog(@"[HAPTCPIPConnection] WARNING: None event");
			break;
		}
			
		default: {
			NSLog(@"[HAPTCPIPConnection] WARNING: Stream is sending an unhandled Event: %u", (unsigned)pEvent);
			
			break;
		}
	}
}


#pragma mark - TIMER

/*
 timeoutTimerFired:
 
 */
- (void)timeoutTimerFired:(NSTimer *)pTimer {
	
	if (self.timeoutTimer == pTimer) {
		
		[self.timeoutTimer invalidate];
		self.timeoutTimer = nil;
		
		//
		// CAUTION: a response handler might call 'send...' which will replace the response handler itself...
		HAPTCPIPConnectionResponseHandlerType	responseHandler = self.responseHandler;
		self.responseHandler = nil;
		
		if (responseHandler) {
			responseHandler(0, 0);
		}
	}
}


#pragma mark - HELPERS

/*
 * print(const unsigned char*)
 *
 */
- (void)printArray:(const unsigned char *)p_pucArray
		withLength:(unsigned)p_uLength
		andComment:(NSString *)p_Comment {
	
	NSLog(@"[HAPTCPIPConnection] %@", p_Comment);
	
	NSMutableString*	output = [NSMutableString.alloc initWithString:@"\n"];	
	for (unsigned j = 1; j <= p_uLength; ++j) {
		[output appendFormat:@"0x%02x, ", p_pucArray[j - 1]];
		if (!(j % 16)) {
			[output appendString:@"\n"];
		}
	}
	NSLog(@"%@", output);
}

@end








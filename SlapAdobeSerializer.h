//
//  SlapAdobeSerializer.h
//  HCePub
//
//  Created by Stephen La Pierre on 6/11/12.
//  Copyright (c) 2012 2012 SlapWare Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

static const Byte BEGIN_ELEMENT  = 1;
static const Byte END_ATTRIBUTES = 2;
static const Byte END_ELEMENT = 3;
static const Byte TEXT_NODE = 4;
static const Byte ATTRIBUTE = 5;

@interface SlapAdobeSerializer : NSObject <NSXMLParserDelegate>

@property (readwrite) BOOL didStartElement;

- (id) initWithData: (NSData*)xmlInput;
- (bool)shouldIgnore:(NSString *)attUri :(NSString *) lname;
- (void)SerializeString:(NSString *) str;
- (void)SerializeByte:(Byte) byte;
- (void)SerializeByteArray:(NSData *) bytearray;
- (void)SerializeAttribute:(NSString *)attvalue;
- (NSMutableData *)GetMessage;
-(void)cleanUp;
@end

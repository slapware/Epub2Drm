//
//  SlapAdobeSerializer.m
//  HCePub
//
//  Created by Stephen La Pierre on 6/11/12.
//  Copyright (c) 2012 2012 SlapWare Inc. All rights reserved.
//

#import "SlapAdobeSerializer.h"

@implementation SlapAdobeSerializer
{
    NSXMLParser *parser;
    NSMutableString *element;
    NSMutableData *myStream;
}

// -------------------------------------------------------------------------------
//  initWithData:(NSData*)xmlInput --- 
// -------------------------------------------------------------------------------
- (id) initWithData:(NSData*)xmlInput
{
    self = [super init];
    if (self != nil) {
        self.didStartElement = NO;
        myStream = [[NSMutableData alloc] init];
        parser = [[NSXMLParser alloc]
                  initWithData:xmlInput];
        [parser setDelegate:self];
        [parser setShouldProcessNamespaces:YES];
        [parser setShouldResolveExternalEntities:YES];
        [parser parse];
    }
    return self;
}
// -------------------------------------------------------------------------------
//  dealloc --- 
// -------------------------------------------------------------------------------
-(void)cleanUp;
{
    [myStream setLength:0];
    parser = nil;
}
// -------------------------------------------------------------------------------
//  SerializeString:(NSString *) str --- 
// -------------------------------------------------------------------------------
- (void)SerializeString:(NSString *) str
{
    [self SerializeByte:((Byte)[str length] >> 8)];
    [self SerializeByte:((Byte)[str length] & 0xFF)];
    [self SerializeByteArray:[NSData dataWithBytes:[str UTF8String] length:[str lengthOfBytesUsingEncoding:NSUTF8StringEncoding]]];

}
// -------------------------------------------------------------------------------
//  SerializeByte:(Byte) byte --- 
// -------------------------------------------------------------------------------
- (void)SerializeByte:(Byte) byte
{
    @try
    {
    [myStream appendBytes:(const void *)&byte length:sizeof(byte)];
    }
    @catch (id theException) 
    {
		NSLog(@"%@", theException);
    }
}
// -------------------------------------------------------------------------------
//  SerializeByteArray:(NSData *) bytearray --- 
// -------------------------------------------------------------------------------
- (void)SerializeByteArray:(NSData *) bytearray
{
    @try
    {
        [myStream appendData:bytearray];
    }
    @catch (id theException) 
    {
		NSLog(@"%@", theException);
    }
}
// -------------------------------------------------------------------------------
//  SerializeAttribute --- 
// -------------------------------------------------------------------------------
- (void)SerializeAttribute:(NSString *)attvalue
{
//    SerializeByte((Byte)
}
// -------------------------------------------------------------------------------
//  parser:(NSXMLParser *)parser didStartElement --- 
// -------------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
    attributes:(NSDictionary*) attributeDict
{
    if([self shouldIgnore:namespaceURI :elementName])
        return;
    [self SerializeByte:(Byte)BEGIN_ELEMENT];
    [self SerializeString:namespaceURI];
    [self SerializeString:(NSString *)elementName];

    self.didStartElement = YES;
    //
    if ([attributeDict count] > 0)
    {
        NSArray *blockSortedKeys = [attributeDict keysSortedByValueUsingComparator: ^(id obj1, id obj2) {
            
            if (obj1 > obj2) {
                return (NSComparisonResult)NSOrderedDescending;
            }
            
            if (obj1 < obj2) {
                return (NSComparisonResult)NSOrderedAscending;
            }
            return (NSComparisonResult)NSOrderedSame;
        }];
        [blockSortedKeys enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
            [self SerializeByte:(Byte)ATTRIBUTE];
            [self SerializeString:namespaceURI];
            [self SerializeString:(NSString *)object];
            [self SerializeString:(NSString *)attributeDict[object] ];
            [self SerializeByte:(Byte)END_ATTRIBUTES];
        }];
    }
    else {
        [self SerializeByte:(Byte)END_ATTRIBUTES];
    }
}
// -------------------------------------------------------------------------------
//  parser:(NSXMLParser *)parser didEndElement --- 
// -------------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName 
{
//    if (([qName isEqualToString:@"package"] || [qName isEqualToString:@"request"])) {
//        [self SerializeByte:(Byte)END_ELEMENT];
//    }
   if ([qName isEqualToString:@"package"]) {
       [self SerializeByte:(Byte)END_ELEMENT];
       [self SerializeByte:(Byte)END_ELEMENT];
   }
    if ([qName isEqualToString:@"QueryResourceItems"]) {
        [self SerializeByte:(Byte)END_ELEMENT];
        [self SerializeByte:(Byte)END_ELEMENT];
    }
}
// -------------------------------------------------------------------------------
//  parser foundCharacters --- 
// -------------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    //
    NSString *trimmedText = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] > 0) 
    {
        int len = [trimmedText length];
        int done = 0;
        do {
            int remains = (len - done < 0x7FFF ? len - done : 0x7FFF );
            [self SerializeByte:(Byte)TEXT_NODE];
            [self SerializeString:[trimmedText substringWithRange:NSMakeRange(done, remains)]];
            done += remains;
            [self SerializeByte:(Byte)END_ELEMENT];
        } while (done < len);
    }
}
// -------------------------------------------------------------------------------
//  shouldIgnore --- 
// -------------------------------------------------------------------------------
- (bool)shouldIgnore:(NSString *)attUri :(NSString *)lname
{
    if ([attUri isEqualToString:@"http://ns.adobe.com/adept"] && ([lname isEqualToString:@"hmac"] || [lname isEqualToString:@"signature"])) {
        return YES;
    }
    return NO;
}
// -------------------------------------------------------------------------------
//  GetMessage --- 
// -------------------------------------------------------------------------------
- (NSMutableData *)GetMessage
{
//    NSString *msg = [[[NSString alloc] initWithData:myStream encoding:NSUTF8StringEncoding]autorelease];
    return myStream;
}
@end

//
//  AssignBooks.m
//  HCePub
//
//  Created by Stephen La Pierre on 7/31/12.
//  Serialize file data for Adobe DRM system
//

#import "AssignBooks.h"
#import "AppController.h"

@implementation AssignBooks
{
    NSXMLParser *parser;
    NSMutableArray *myArray;
    BOOL captureCharacters;
}

// -------------------------------------------------------------------------------
//  initWithData:(NSData*)xmlInput ---
// -------------------------------------------------------------------------------
- (id) initWithData:(NSData*)xmlInput
{
    self = [super init];
    if (self != nil) {
        self.isDone = NO;
        NSError * err;
        myArray = [[NSMutableArray alloc] initWithCapacity:768];
        parser = [[NSXMLParser alloc]
                  initWithData:xmlInput];
        [parser setDelegate:self];
        [parser setShouldProcessNamespaces:NO];
        [parser setShouldResolveExternalEntities:NO];
        BOOL isOk = [parser parse];
        if (!isOk) {
            err = [parser parserError];
        }

        self.isDone = YES;
    }
    return self;
}
// -------------------------------------------------------------------------------
//  GetMessage ---
// -------------------------------------------------------------------------------
- (NSMutableArray *)GetMessage
{
    // Initialise a new, empty mutable array
    NSMutableArray *unique = [[NSMutableArray alloc] initWithCapacity:[myArray count] / 2];
    
    
    [myArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![unique containsObject:obj]) {
            [unique addObject:obj];
        }
    }];

//    return myArray;
    return unique;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqual:@"resource"]) {
        captureCharacters = YES;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (captureCharacters) {
        //from parser:foundCharacters: docs:
        //The parser object may send the delegate several parser:foundCharacters: messages to report the characters of an element.
        //Because string may be only part of the total character content for the current element, you should append it to the current
        //accumulation of characters until the element changes.
        [myArray addObject:string];
//        [element appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if (captureCharacters) {
        captureCharacters = NO;
//        [(AppController *)[[NSApplication sharedApplication] delegate] sendassign:element];
//        NSRange range;
//        range.location = 0;
//        range.length = [element length];
//        [element deleteCharactersInRange:range];
    }
}
@end

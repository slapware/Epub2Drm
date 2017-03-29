//
//  AssignBooks.h
//  HCePub
//
//  Created by Stephen La Pierre on 7/31/12.
//
//

#import <Foundation/Foundation.h>

@interface AssignBooks : NSObject  <NSXMLParserDelegate>

@property (readwrite) BOOL isDone;

- (id) initWithData: (NSData*)xmlInput;
- (NSMutableArray *)GetMessage;

@end

//
//  NSString+slapadds.h
//  HCePub
//
//  Created by Stephen La Pierre on 7/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (slapadds)

- (BOOL) appendToFile:(NSString *)path encoding:(NSStringEncoding)enc;

@end

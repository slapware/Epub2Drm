//
//  NSString+slapadds.m
//  HCePub
//
//  Created by Stephen La Pierre on 7/24/12.
//  Copyright (c) 2012 SlapWare Inc. All rights reserved.
//

#import "NSString+slapadds.h"

@implementation NSString (slapadds)

- (BOOL) appendToFile:(NSString *)path encoding:(NSStringEncoding)enc;
{
    BOOL result = YES;
    NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if ( !fh ) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    if ( !fh ) return NO;
    @try {
        [fh seekToEndOfFile];
        [fh writeData:[self dataUsingEncoding:enc]];
    }
    @catch (NSException * e) {
        result = NO;
    }
    [fh closeFile];
    return result;
}
@end

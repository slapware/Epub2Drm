//
//  OpfChecker.h
//  HCePub
//
//  Created by Stephen La Pierre on 9/17/12.
//  Fix ISBN in dc:identifier if not correct or missing.
//

#import <Foundation/Foundation.h>

@interface OpfChecker : NSObject

@property(readwrite, strong) NSString *input;
@property (readwrite) BOOL isDone;
@property (readwrite) BOOL canRead;
@property (readwrite) BOOL didModify;
@property(readwrite, strong) NSString *errorMessage;


-(id) initWithFile:(NSString*)pInput;
-(bool) openOPF;
-(NSString*)newIdent:(NSString *)pFile;
-(NSData*)checkOPF:(NSString *)pOpf newIsbn:(NSString*)newIdent;
-(void)cleanUp;

@end

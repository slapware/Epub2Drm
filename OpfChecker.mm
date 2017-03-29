//
//  OpfChecker.m
//  HCePub
//
//  Created by Stephen La Pierre on 9/17/12.
//
//

#import "OpfChecker.h"
#import "CkoZip.h"
#import "CkoZipEntry.h"

@implementation OpfChecker
{
    NSXMLDocument *xmlDoc;
}

// -------------------------------------------------------------------------------
//  initWithFile --- 
// -------------------------------------------------------------------------------
- (id) initWithFile: (NSString*)pInput
{
    self = [super init];
    if (self != nil) {
        self.input = pInput;
        self.didModify = NO;
        [self openOPF];
    }
    return self;
}

-(void)cleanUp;
{
//    NSXMLDocument = nil;
}
// -------------------------------------------------------------------------------
//  openOPF --- 
// -------------------------------------------------------------------------------
-(bool) openOPF
{
//    NSError *err = nil;
    BOOL success;
    @autoreleasepool {
    NSMutableString *strOutput = [NSMutableString stringWithCapacity:1000];

    CkoZip *zip = [[CkoZip alloc] init];
    success = [zip UnlockComponent: @""];
    if (success != YES) {
        [strOutput appendString: zip.LastErrorText];
        [strOutput appendString: @"\n"];
        self.errorMessage = strOutput;
        return NO;
    }

    success = [zip OpenZip: self.input];
    if (success != YES) {
        [strOutput appendString: zip.LastErrorText];
        [strOutput appendString: @"\n"];
        self.errorMessage = strOutput;
        return NO;
    }
    
    NSString *newIsbn = [self newIdent:self.input];
    int n;
    
    //  Get the number of files and directories in the .zip
    n = [zip.NumEntries intValue];
    CkoZipEntry *entry;
    NSString *searchString = @"*.opf";    
        
    entry = [zip FirstMatchingEntry:searchString];
    if (entry.IsDirectory == NO) {
        if (entry != NULL)
        {
            NSString* opfData = [entry UnzipToString:0 srcCharset:@"utf-8"];
            NSRange tend = [opfData rangeOfString:@"</package>" options:NSBackwardsSearch];
            if (tend.location == NSNotFound) {
                self.errorMessage = [NSString stringWithFormat:@"Error reading epub OPF document for %@, as empty or invalid",newIsbn];
                self.canRead = NO;
                return NO;
            }
            NSRange rangedel = NSMakeRange(0, tend.location + 10);
            if (rangedel.location < [opfData length]) {
                opfData = [opfData substringWithRange:rangedel];
            }
            NSData *newOpf = [self checkOPF:opfData newIsbn:newIsbn];
            if (self.didModify) {
                // NOTE: important to use NSUTF8StringEncoding NOT Ascii
                NSString *newEntry = [[NSString alloc] initWithData:newOpf encoding:NSUTF8StringEncoding];
                // change line endinds
                newEntry = [newEntry stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
                //                    success = [entry ReplaceStringAnsi:newEntry]; // 9.3.2 code
                success = [entry ReplaceString:newEntry charset:@"utf-8"];
                if (success != YES) {
                    [strOutput appendString: entry.LastErrorText];
                    [strOutput appendString: @"\n"];
                    self.errorMessage = strOutput;
                    self.canRead = NO;
                    return NO;
                }
                else
                {
                 success = [zip WriteZip];
                }
            }
            
        }
        if (success != YES) {
            [strOutput appendString: entry.LastErrorText];
            [strOutput appendString: @"\n"];
            self.errorMessage = strOutput;
            return NO;
        }
        
    }

    if (self.didModify) {
        [zip WriteZipAndClose];
    }
    else
    {
        [zip CloseZip];
    }
    self.canRead = YES;
    } // @autoreleasepool
    return self.canRead;
}
// -------------------------------------------------------------------------------
//  newIdent --- 
// -------------------------------------------------------------------------------
/*! Return the ISBN derived from file name
 * \param1 the complete file name
 * \returns The 13 digit ISBN
 */
-(NSString*)newIdent:(NSString *)pFile
{
    NSString *newIsbn;
    NSRange rangeOfIsbn = [pFile rangeOfString:@"978"];
    
    if(rangeOfIsbn.location == NSNotFound)
    {
        // error condition — the text '<a href' wasn't in 'string'
        return newIsbn;;
    }
    else
    {
        newIsbn = [pFile substringWithRange:NSMakeRange(rangeOfIsbn.location, 13)];
    }
    return newIsbn;;    
}
// -------------------------------------------------------------------------------
//  checkOPF --- 
// -------------------------------------------------------------------------------
/*! Check OPF dc:identifier matches ISBN and fix if required
 * \param1 NSString OPF XML data
 * \param2 The 13 digit ISBN derived from file name
 * \returns NSData* of XML data
 */
-(NSData*)checkOPF:(NSString *)pOpf newIsbn:(NSString*)newIdent
{
    if([pOpf length] < 64)
    {
        self.errorMessage = [NSString stringWithFormat:@"Error reading epub OPF document for %@,", newIdent];
        self.canRead = NO;
        NSData* dataOpf = [pOpf dataUsingEncoding:NSUTF8StringEncoding];
        return dataOpf;
    }
    NSError *err = nil;
    
    xmlDoc = [[NSXMLDocument alloc] initWithXMLString:pOpf options:(NSXMLNodePreserveWhitespace|NSXMLNodeCompactEmptyElement) error:&err];
    
//    if( xmlDoc == nil )
//    {
//        // in previous attempt, it failed creating XMLDocument because it
//        // was malformed.
//        xmlDoc = [[NSXMLDocument alloc] initWithXMLString:pOpf options:NSXMLDocumentTidyXML error:&err];
//    }
//    if( xmlDoc == nil)
//    {
//        NSLog( @"Error occurred while reading epub XML document.");
//        if(err)
//        {
//            self.canRead = NO;
//        }
//    }
    if(err)
    {
        //        NSString *lastCharacter = [pOpf substringFromIndex:[pOpf length] - 1];
        self.errorMessage = [NSString stringWithFormat:@"Error reading epub OPF document for %@, %@", newIdent, [err localizedDescription]];
        self.canRead = NO;
    }
    else
    {
        //get all of the children from the root node into an array
        NSArray *children = [[xmlDoc rootElement] children];
        int i, count = [children count];
        
        //loop through each child
        for (i=0; i < count; i++) {
            NSXMLElement *child = [children objectAtIndex:i];
            
            //check to see if the child node is of 'metadata' type
            if (([child.name isEqual:@"metadata"]) || ([child.name isEqual:@"opf:metadata"])) {
                {
                    NSXMLNode *nsNamespaceNode;
                    nsNamespaceNode = [child namespaceForPrefix:@"dc"];
                    NSArray *idents = [child elementsForLocalName: @"identifier" URI:[nsNamespaceNode stringValue]];
                    // NOTE: was fixed 17/12/2013
                    if (([idents count] == 0 )  || (idents == nil) ) {
                        idents = [xmlDoc nodesForXPath:@".//opf:package/opf:metadata/dc:identifier" error:&err];
                    }
                    if (([idents count] == 0 )  || (idents == nil) ) {
                        idents = [xmlDoc nodesForXPath:@".//package/metadata/dc:identifier" error:&err];
                    }
                    if (([idents count] == 0 )  || (idents == nil) ) {
                        idents = [xmlDoc nodesForXPath:@".//package/opf:metadata/dc:identifier" error:&err];
                    }
                    if ([idents count] > 0 ) {
                        NSXMLNode *dcidentifier = [idents objectAtIndex:0];
                        NSString *oldvalue =  [dcidentifier objectValue];
                        // NOTE: Compare found ISBN with one taken from file name of epub
                        if (([oldvalue length] != 13) || ([oldvalue hasPrefix:@"978"] == NO) || ([oldvalue isEqualToString:newIdent] == NO)) {
                            if ([newIdent length] == 13) {
                                [dcidentifier setStringValue:newIdent];
                                self.didModify = YES;
                            }
                            else {
                                // newIdent no good
                                self.didModify = NO;
                            }
                        }
                    }
                    else
                    {
                        // dc:identifier not found
                        self.didModify = NO;
                    }
                }
            }
        } // for (i=0; i < count; i++)
    }
    err = nil;
    return [xmlDoc XMLData];
}

@end
    

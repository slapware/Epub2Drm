//
//  AppController.m
//  HCePub
//
//  Created by LaPierre, Stephen on 5/26/10.
//  Copyright 2012 SlapWare. All rights reserved.
//  SLAP 8/4/12, at 8:17 PM

#import "AppController.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSData+Base64.h"
#import "JFUrlUtil.h"
#import "SlapAdobeSerializer.h"

#import <CommonCrypto/CommonHMAC.h>
#import "NSString+slapadds.h"
#import "AssignBooks.h"
#import "OpfChecker.h"


@implementation AppController
{
    BOOL distAltered;
    BOOL distEdit;
    BOOL isAssign;
    BOOL isOverSize;
	NSString *developmentServer;
	NSString *productionServer;
	NSString *myPassword;
}

@synthesize window = _window;

#pragma mark -
#pragma mark Standard app functions
- (id)init {
	if ((self = [super init])) {
	}
	return self;
}

// ----------------------------------------------------------------------------
// applicationShouldTerminateAfterLastWindowClosed --- 
// ----------------------------------------------------------------------------
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}
// ----------------------------------------------------------------------------
// awakeFromNib --- 
// ----------------------------------------------------------------------------
- (void)awakeFromNib
{
    self.distrubutors = [[NSMutableArray alloc] initWithCapacity:16];
    self.guidsToDelete = [[NSMutableArray alloc] initWithCapacity:64];
    self.ItemInfo = [[resourceItemInfo alloc] init];

    self.isGalley = NO;
	[self retrieveFromUserDefaults];
	[transmitButton setKeyEquivalent: @"\r"];	// enable the nice blue button look
    distAltered = NO;
    distEdit = NO;
    isAssign = NO;
    isOverSize = NO;
    self.readyToSend = NO;
    self.readyToPost = NO;
    NSDate *today = [NSDate date];
    self.fileDate = [today descriptionWithCalendarFormat:@"%Y-%m-%d_%H_%M_" timeZone:[NSTimeZone timeZoneWithName:@"EST"] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}
// ----------------------------------------------------------------------------
// dealloc --- 
// ----------------------------------------------------------------------------
- (void)dealloc
{
    [self.distrubutors removeAllObjects];
    [self.guidsToDelete removeAllObjects];
}
#pragma mark -
#pragma mark GUI feedback standard
// -------------------------------------------------------------------------------
//  goBusy --- 
// -------------------------------------------------------------------------------
-(void)goBusy
{
    [transmitButton setEnabled:NO];
    [progress startAnimation:nil];
}
// -------------------------------------------------------------------------------
//  goFree --- 
// -------------------------------------------------------------------------------
-(void)goFree
{
    [progress stopAnimation:nil];
	[transmitButton setEnabled:YES];
}
#pragma mark -
#pragma mark The main event
// ----------------------------------------------------------------------------
// transmit:(id)sender --- 
// ----------------------------------------------------------------------------
- (IBAction)transmit:(id)sender
{
	int eAction = [ePubSelect selectedRow];	// 0 = file, 1 = directory
	int pAction = [packageSelect selectedRow];	// 0 = dev, 1 = prod, 2 = other
	// check file or directory has been provided.
	if(eAction == 0)
	{	// FILE selected
		if([[ePubFile stringValue] length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid ePub", @"Please select a valid ePub." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;  
		}
	}
	if(eAction == 1)
	{	// DIRECTORY selected
		if([[ePubDirectory stringValue] length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid location", @"Please select a valid ePub directory." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;  
		}
	}
	// check for selected server information.
	if(pAction == 0)
	{	// ETG development
		if([developmentServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;  
		}
		else 
		{
			self.activeServer = [NSString stringWithFormat:@"http://%@/packaging/Package", developmentServer ];
		}
	}
	if(pAction == 1)
	{	// Harper Production
		if([productionServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;  
		}
		else 
		{
			self.activeServer = [NSString stringWithFormat:@"http://%@/packaging/Package", productionServer ];
		}
	}
	if(pAction == 2)
	{	// OTHER packaging server
		if([[otherServerName stringValue] length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;  
		}
		else 
		{
			self.activeServer = [otherServerName stringValue];
		}
	}
    // NOTE: eGalley check
    if ([GalleyCheckBox state] == NSOnState) {
        self.isGalley = YES;
    }
    else
    {
        [self selecteCatalog:self];
    }
    [self goBusy];
    // Update fileDate on command issued
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"MM-dd-YY_HH_mm_ss_"];
    self.fileDate = [dateFormatter stringFromDate:today];
    
	if(eAction == 0)
	{	// FILE selected
        NSString *xmlTemplate;
        NSString *fileToSend;
		fileToSend = [NSString stringWithFormat:@"%@", [ePubFile stringValue]];
		xmlTemplate = [self filePrepare:fileToSend];
        [self sendToDrm:xmlTemplate];
	}
	if(eAction == 1)
	{	// DIRECTORY selected
        NSDirectoryEnumerator*	e = [[NSFileManager defaultManager] enumeratorAtPath:[ePubDirectory stringValue]];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1];
        // Ignore any files except XYZ.jpg
        for (NSString*	file in e)
        {
            if (NSOrderedSame == [[file pathExtension] caseInsensitiveCompare:@"epub"])
            {
                NSString *fileToSend = [NSString stringWithFormat:@"%@/%@", [ePubDirectory stringValue], file];
                // FIXME: test all went well Do something with file.epub
                // remove threading and check opfChecker status to skip or continue
                [self filePrepare:fileToSend];
                if ((self.readyToSend == NO) && (self.readyToPost == NO)) {
                    continue;
                }
                
                
                [self sendToDrm:self.xml2Send];
                
                
//                NSInvocationOperation *doPost = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(sendToDrm:) object:self.xml2Send];
//                [queue addOperation:doPost];
//                [queue waitUntilAllOperationsAreFinished];

//                while (self.readyToPost == NO) {
//                    [NSThread sleepForTimeInterval:1];
//                }
                self.xml2Send = @"";
            }
            else
            if ([[[e fileAttributes] fileType] isEqualToString:NSFileTypeDirectory])
            {
                // Ignore any subdirectories
                [e skipDescendents];
            }
        }
    }
    
    [self goFree];
}
#pragma mark -
#pragma mark The epub helper functions
// -------------------------------------------------------------------------------
//	sendRequest --- 
// -------------------------------------------------------------------------------
//-(void)sendToDrm:(NSString *)pdata toServer:(NSString *)pserver isSingle:(bool)isSingle
-(void)sendToDrm:(NSString *)pdata
{
    self.readyToPost = NO;
    
    @autoreleasepool {
	NSData *postData = [pdata dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:self.activeServer]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	NSURLResponse *response;
	NSError *error;
	NSData *returnData =[NSURLConnection sendSynchronousRequest:request
                                              returningResponse:&response
                                                          error:&error];
	NSString* myresponce;
	myresponce = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];
    BOOL succeed;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
    NSString *documentsDirectory = paths[0]; // Get documents directory
    
    if ([myresponce rangeOfString:@"<error xmlns="].location != NSNotFound)
    {
        succeed = [myresponce appendToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@upload_error.xml", self.fileDate]] encoding:(NSStringEncoding)NSUTF8StringEncoding];
    }
    else
    {
      succeed = [myresponce appendToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@upload.xml", self.fileDate]] encoding:(NSStringEncoding)NSUTF8StringEncoding];
    }
    if (!succeed){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save upload responce", nil, nil, nil);
    }
        
    request = nil;
    postData = nil;
    request = nil;
    returnData = nil;
    myresponce = nil;
    error = nil;
    } // @autoreleasepool

    pdata = nil;
    self.readyToSend = YES;
    self.readyToPost = YES;

    return;
}
// -------------------------------------------------------------------------------
//	filePrepare --- 
// -------------------------------------------------------------------------------
-(NSString *)filePrepare:(NSString *)pfile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0]; // Get documents directory
    @autoreleasepool {
    OpfChecker *opfFixer = [[OpfChecker alloc] initWithFile:pfile];
        // FIXME: bail out and log
        if (!opfFixer.canRead) {
            NSString *myError = [NSString stringWithFormat:@"<%@>", opfFixer.errorMessage];
            [myError appendToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@upload_error.xml", self.fileDate]] encoding:(NSStringEncoding)NSUTF8StringEncoding];
            self.readyToSend = NO;
            self.readyToPost = NO;
            return pfile;
        }
    } // @autoreleasepool

	NSTimeInterval hourAway = 2 * 60 * 60;
	NSDate *expireDate;
	NSDate *today = [NSDate date];
	expireDate = [today dateByAddingTimeInterval:hourAway];
	NSString *szExpire = [expireDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S-04:00" timeZone:[NSTimeZone timeZoneWithName:@"EST"] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	// NOTE: new nonce section
	NSString *expireText = [NSString stringWithFormat:@"<expiration>%@</expiration>\n", szExpire];
    // new nonce
    long max = 23000345772485410;
    long min = 102854372134123;
    long value = (arc4random() % max) + min;
    NSString *newNumn = [NSString stringWithFormat:@"%lu",value];
    @autoreleasepool {
    NSData* myBnonce = [newNumn dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce base64EncodedString]];
    // Read headeer template XML
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *xmlPath;
    NSString * xmlTemplate;
    // !!!: check if galley and add or replace
    if([GalleyCheckBox state] == NSOffState)
    {
        // NOTE: strip isbn from file path-name
        NSString *foundIsbn = [[pfile lastPathComponent] stringByDeletingPathExtension];
        if ([self CheckCatalog:foundIsbn ]) {
            xmlPath = [NSString stringWithFormat:@"%@%@", [bundle resourcePath], @"/header_replace.xml" ];
            xmlTemplate = [NSString stringWithContentsOfFile:xmlPath encoding:NSASCIIStringEncoding error:nil];
            xmlTemplate = [xmlTemplate stringByReplacingOccurrencesOfString:@"oldGuid" withString:self.theGuid];
            xmlTemplate = [xmlTemplate stringByAppendingString:@"<dc:format>application/epub+zip</dc:format>\n"];
            xmlTemplate = [xmlTemplate stringByAppendingString:@"</metadata>\n"];
        }
        else
        {
            xmlPath = [NSString stringWithFormat:@"%@%@", [bundle resourcePath], @"/header_add.xml" ];
            xmlTemplate = [NSString stringWithContentsOfFile:xmlPath encoding:NSASCIIStringEncoding error:nil];
        }
    } // !!!: GalleyCheckBox is ON
    else
    {
        xmlPath = [NSString stringWithFormat:@"%@%@", [bundle resourcePath], @"/header_add.xml" ];
        xmlTemplate = [NSString stringWithContentsOfFile:xmlPath encoding:NSASCIIStringEncoding error:nil];
        xmlTemplate = [xmlTemplate stringByAppendingString:@"<metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n"];
        xmlTemplate = [xmlTemplate stringByAppendingString:@"<dc:publisher>Harper Collins eGalley - NOT for re-sale</dc:publisher>\n"];
        xmlTemplate = [xmlTemplate stringByAppendingString:@"<dc:format>application/epub+zip</dc:format>\n"];
        xmlTemplate = [xmlTemplate stringByAppendingString:@"</metadata>\n"];
    }

    if (useXml)
    {
        xmlPath = [NSString stringWithFormat:@"%@%@", [bundle resourcePath], @"/permission.xml" ];
        NSString * permissions = [NSString stringWithContentsOfFile:xmlPath encoding:NSASCIIStringEncoding error:nil];
        xmlTemplate = [xmlTemplate stringByAppendingString:permissions];
    }
    
    NSData *filedata = [NSData dataWithContentsOfFile:pfile];
    NSString *file64 = [filedata base64EncodedString];
	NSString *edata = [NSString stringWithFormat:@"\n<data>%@</data>\n", file64];
	xmlTemplate = [xmlTemplate stringByAppendingString:edata];
	xmlTemplate = [xmlTemplate stringByAppendingString:expireText];
	xmlTemplate = [xmlTemplate stringByAppendingString:nonceText];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"</package>\n"];
    // **************************************************************************
    NSData *xmldata = [NSData dataWithBytes:[xmlTemplate UTF8String] length:[xmlTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    
	SlapAdobeSerializer *serial = [[SlapAdobeSerializer alloc] initWithData:xmldata];
    NSData *serialPost = [serial GetMessage];
    [serial cleanUp];
    // FIXME: change for office or home location.
//    [serialPost writeToFile:@"/Users/slapware/native2.bin" atomically:NO];
//    [serialPost writeToFile:@"/Users/slap/native2.bin" atomically:NO];
    NSData * serialPostData = [NSData dataWithData:serialPost];
 	// FIXME: file to b64 enc string
    NSData *aKey = [NSData dataFromBase64String:[self builtInDist]];
   [self getHmac:aKey :serialPostData];
	// NOTE: HMAC HERE
	NSString *hmacText = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText = [hmacText stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd = [NSString stringWithFormat:@"%@</package>\n", hmacText];
//    NSString *xmlToSend = [xmlTemplate stringByReplacingOccurrencesOfString:@"</package>\n" withString:macadd];
    self.xml2Send = [xmlTemplate stringByReplacingOccurrencesOfString:@"</package>\n" withString:macadd];
    // clean up
        
    macadd = nil;
    edata = nil;
    nonceText = nil;
	xmlTemplate = nil;
    filedata = nil;
    file64 = nil;
    serial = nil;
    serialPostData = nil;
    } // @autoreleasepool
    self.readyToSend = YES;
    self.readyToPost = YES;
	return self.xml2Send;
}
#pragma mark -
#pragma mark assign ebooks to distributor
// -------------------------------------------------------------------------------
//  overAssignBooks --- 
// -------------------------------------------------------------------------------
-(void)overAssignBooks:(id)sender
{
    // Update fileDate on command issued
    NSDate *today = [NSDate date];
    self.fileDate = [today descriptionWithCalendarFormat:@"%Y-%m-%d_%H_%M_" timeZone:[NSTimeZone timeZoneWithName:@"EST"] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
    NSString * xmlfile;
    // Select the xml file
    NSArray *fileTypes = @[@"xml",@"dat",@"txt"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	
	
	[panel setPrompt:@"Choose data file"]; // Should be localized
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowedFileTypes:fileTypes];
    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        // get the urls
        NSArray *selectedFiles = [panel URLs];
		NSURL *saveTo = selectedFiles[0];
		xmlfile = [saveTo path]; //full filename and path
    }
    else
    {
        // cancel button was clicked
        return;
    }
    NSString *dataFile = [NSString stringWithContentsOfFile:xmlfile encoding:NSUTF8StringEncoding error:nil];
    [transmitButton setEnabled:NO];
    [progress startAnimation:nil];
    NSArray *lines = [dataFile componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
    for (NSString* line in lines) {
        if (line.length) {
            //            NSLog(@"line: %@", line);
            NSRange rangeOfSubstring = [line rangeOfString:@".epub"];
            
            if(rangeOfSubstring.location == NSNotFound)
            {
                // error condition — the text '<a href' wasn't in 'string'
                continue;
            }
            
            // return only that portion of 'string' up to where 'urn:uuid:' was found
            NSString *toAssign = [NSString stringWithFormat:@"urn:uuid:%@", [line substringToIndex:rangeOfSubstring.location]];
            [self sendassign:toAssign];
        }
    }
    [progress stopAnimation:nil];
	[transmitButton setEnabled:YES];
}
// -------------------------------------------------------------------------------
//  assignBooks --- 
// -------------------------------------------------------------------------------
-(void)assignBooks:(id)sender
{
    // Update fileDate on command issued
    NSDate *today = [NSDate date];
//    self.fileDate = [today descriptionWithCalendarFormat:@"%Y-%m-%d_%H_%M_" timeZone:[NSTimeZone timeZoneWithName:@"EST"] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"MM-dd-YY_HH_mm_ss_"];
    self.fileDate = [dateFormatter stringFromDate:today];

    NSString * xmlfile;
    // Select the xml file
    NSArray *fileTypes = @[@"xml",@"dat"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	
	
	[panel setPrompt:@"Choose data file"]; // Should be localized
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowedFileTypes:fileTypes];
    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        // get the urls
        NSArray *selectedFiles = [panel URLs];
		NSURL *saveTo = selectedFiles[0];
		xmlfile = [saveTo path]; //full filename and path
    }
    else
    {
        // cancel button was clicked
        return;
    }
    // SLAP 8/5/12, at 3:25 PM to make valid xml for reading
    NSString *newFile = @"<data>\n";
    NSString *oldFile = [NSString stringWithContentsOfFile:xmlfile encoding:NSUTF8StringEncoding error:nil];
    newFile = [newFile stringByAppendingString:oldFile];
    newFile = [newFile stringByAppendingString:@"</data>\n"];
    [newFile writeToFile:xmlfile atomically:NO encoding:NSUTF8StringEncoding error:nil];
    
    [transmitButton setEnabled:NO];
    [progress startAnimation:nil];
    NSData *xmldata = [NSData dataWithContentsOfFile:xmlfile];
	AssignBooks *serial = [[AssignBooks alloc] initWithData:xmldata];
    isAssign = NO;
    while (!serial.isDone) {
        sleep(1);
    }
    NSArray *ids = [NSArray arrayWithArray:[serial GetMessage]];
    [ids enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        // do something with object
        [self sendassign:(NSString*)object];
    }];
    xmldata = nil;
    serial = nil;
    [progress stopAnimation:nil];
	[transmitButton setEnabled:YES];
}
// -------------------------------------------------------------------------------
//  sendassign --- 
// -------------------------------------------------------------------------------
-(void)sendassign:(NSString*)urnid
{
	NSString *serverPath;
	int pAction = [packageSelect selectedRow];	// 0 = dev, 1 = prod, 2 = other
    if(pAction == 0)
	{	// ETG development
		if([developmentServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights", developmentServer ];
            //			serverPath = [NSString stringWithFormat:@"http://10.40.85.24/cgi-bin/capture.exe", developmentServer ];
		}
	}
	if(pAction == 1)
	{	// Harper Production
		if([productionServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights", productionServer ];
		}
	}
	if(pAction == 2)
	{	// OTHER packaging server
		if([[otherServerName stringValue] length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
                    serverPath = @"http://10.40.85.24/cgi-bin/capture.exe";
//                                  serverPath = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights",                                   [otherServerName stringValue] ];
		}
	}

	NSTimeInterval hourAway = 2 * 60 * 60;
	NSDate *expireDate;
	NSDate *today = [NSDate date];
	expireDate = [today dateByAddingTimeInterval:hourAway];
	NSString *szExpire = [expireDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S-04:00" timeZone:[NSTimeZone timeZoneWithName:@"EST"]
                                                            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	NSString *expireText = [NSString stringWithFormat:@"<expiration>%@</expiration>\n", szExpire];
	// NOTE: new nonce section
    long max = 23000345772485410;
    long min = 102854372134123;
    long value = (arc4random() % max) + min;
    NSString *newNumn = [NSString stringWithFormat:@"%lu",value];
    
    NSString* mydist = [NSString stringWithFormat:@"<distributor>%@</distributor>\n", self.catalogID];
    NSString* myUrn = [NSString stringWithFormat:@"<resource>%@</resource>\n", urnid];
    NSData* myBnonce = [newNumn dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce base64EncodedString]];
	NSString *xmlTemplate = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<request action=\"create\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributionRights>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:mydist];
	xmlTemplate = [xmlTemplate stringByAppendingString:myUrn];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributionType>buy</distributionType>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<available>2</available>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<returnable>false</returnable>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<userType>user</userType>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<permissions>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<display />\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<play />\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<excerpt />\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<print />\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"</permissions>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"</distributionRights>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:nonceText];
	xmlTemplate = [xmlTemplate stringByAppendingString:expireText];
	NSString *hmacText = @"<hmac>SLAPTHIS</hmac>";
	xmlTemplate = [xmlTemplate stringByAppendingString:hmacText];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"\n</request>"];
    //
    NSData *xmldata = [NSData dataWithBytes:[xmlTemplate UTF8String] length:[xmlTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize = [[SlapAdobeSerializer alloc] initWithData:xmldata];
    NSData *serialPost = [serialize GetMessage];
    NSData * serialPostData = [NSData dataWithData:serialPost];
//    NSData *aKey = [NSData dataWithData:[self builtInDist] ];
    NSData *aKey = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey :serialPostData];
    NSString *xmlToSend = [xmlTemplate stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSData *postData = [xmlToSend dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
	[request setURL:[NSURL URLWithString:serverPath]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	NSError *error;
	NSURLResponse *response;
	NSData *returnData =[NSURLConnection sendSynchronousRequest:request
                                              returningResponse:&response
                                                          error:&error];
	NSString* myresponce;
	myresponce = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0]; // Get documents directory
    BOOL succeed = [myresponce appendToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@assign.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save assigment file", nil, nil, nil);
    }
}
#pragma mark -
#pragma mark Delete from system
// -------------------------------------------------------------------------------
//  DeleteSingleBook --- 
// -------------------------------------------------------------------------------
- (IBAction)DeleteSingleBook:(id)sender
{
    // select delete file save location
    NSInteger result;
    NSOpenPanel *destpanel = [NSOpenPanel openPanel];
	
	
	[destpanel setPrompt:@"Choose save logs folder"]; // Should be localized
	[destpanel setCanChooseFiles:NO];
	[destpanel setCanChooseDirectories:YES];
//    [destpanel setAllowedFileTypes:fileTypes];
    [destpanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    [destpanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    result = [destpanel runModal];
    //    if ([panel runModal] == NSFileHandlingPanelOKButton)
	if (result == NSOKButton)
    {
        // get the urls
        NSArray *selectedFolder = [destpanel URLs];
		NSURL *writeTo = selectedFolder[0];
		self.deleteFileLocation = [writeTo path];
    }
    else
    {
        // cancel button was clicked
		return;
    }
    
    //[self performDelete:@"urn:uuid:24a431f9-39df-4092-930f-8d0285be0194"];
	[NSApp beginSheet:singleDeleteSheet
	   modalForWindow:(NSWindow *)_window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL ];
}
// -------------------------------------------------------------------------------
//  performSingleDelete --- 
// -------------------------------------------------------------------------------
- (IBAction)performSingleDelete:(id)sender
{
    NSString *tobegone = [fileToDelete stringValue];
    
    [singleDeleteSheet orderOut:nil];
	[NSApp endSheet:singleDeleteSheet];

    if ([tobegone hasPrefix:@"urn:uuid:"]) {
        [self performDelete:tobegone];
    } else {
        [self performDelete:[NSString stringWithFormat:@"urn:uuid:%@", tobegone]];
    }
}
// -------------------------------------------------------------------------------
//  cancelDeleteSingle ---
// -------------------------------------------------------------------------------
- (IBAction)cancelDeleteSingle:(id)sender
{
	[singleDeleteSheet orderOut:nil];
	[NSApp endSheet:singleDeleteSheet];
}
// -------------------------------------------------------------------------------
//  performMultiDelete --- 
// -------------------------------------------------------------------------------
- (IBAction)performMultiDelete:(id)sender
{
    NSInteger shallWe = NSRunAlertPanel(@"Continue ?", @"Delete from List, delete all files in given guid list ?",
                                        @"OK", @"Cancel", nil);
    if (shallWe == NSAlertAlternateReturn)
    {
        return;
    }
    [self goBusy];
    // NOTE: Disable this panel buttons for GUI feedback
    [doDeleteMulti setEnabled:NO];
    [cancelDeleteMulti setEnabled:NO];
    [selectMultiGuid setEnabled:NO];
    [self.guidsToDelete enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *tobegone = obj;
        if ([tobegone hasPrefix:@"urn:uuid:"]) {
            [self performDelete:tobegone];
        } else {
            [self performDelete:[NSString stringWithFormat:@"urn:uuid:%@", tobegone]];
        }
    }];
    // NOTE: Enable this panel buttons for GUI feedback
    [doDeleteMulti setEnabled:YES];
    [cancelDeleteMulti setEnabled:YES];
    [selectMultiGuid setEnabled:YES];
    // send our results back to the main thread
    [self performSelectorOnMainThread:@selector(goFree)
                           withObject:nil waitUntilDone:NO];
}
// -------------------------------------------------------------------------------
//  selecteGuidList --- 
// -------------------------------------------------------------------------------
- (IBAction)selecteGuidList:(id)sender
{
    NSArray *fileTypes = @[@"xml",@"txt"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	NSString *guidFile;
    NSInteger result;

	[panel setPrompt:@"Select GUID list"]; // Should be localized
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowedFileTypes:fileTypes];
    //    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        // get the urls
        NSArray *selectedFiles = [panel URLs];
		NSURL *selected = selectedFiles[0];
		guidFile = [selected path];
    }
    else
    {
        // cancel button was clicked
        return;
    }
    // select delete file save location
    NSOpenPanel *destpanel = [NSOpenPanel openPanel];
	
	
	[destpanel setPrompt:@"Choose save logs folder"]; // Should be localized
	[destpanel setCanChooseFiles:NO];
	[destpanel setCanChooseDirectories:YES];
    [destpanel setAllowedFileTypes:fileTypes];
    [destpanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    [destpanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    result = [destpanel runModal];
    //    if ([panel runModal] == NSFileHandlingPanelOKButton)
	if (result == NSOKButton)
    {
        // get the urls
        NSArray *selectedFolder = [destpanel URLs];
		NSURL *writeTo = selectedFolder[0];
		self.deleteFileLocation = [writeTo path];
    }
    else
    {
        // cancel button was clicked
		return;
    }

    // move onto deletions
    [self goBusy];
    // spawn a worker thread
    [NSThread detachNewThreadSelector:@selector(selecteGuidListThread:)
                             toTarget:self withObject:guidFile];

}
// -------------------------------------------------------------------------------
//  getIsbn2GuidThread ---
// -------------------------------------------------------------------------------
-(void)selecteGuidListThread:(NSString*)guidFile
{
    // read everything from text
    NSString* fileContents = [NSString stringWithContentsOfFile:guidFile
                                                       encoding:NSUTF8StringEncoding error:nil];
    [listToDelete setStringValue:guidFile];
    if ([self.guidsToDelete count] > 0) {
        [self.guidsToDelete removeAllObjects];
    }

    // first, separate by new line
    NSArray *tmparray = [fileContents componentsSeparatedByCharactersInSet:
                                [NSCharacterSet newlineCharacterSet]];
    self.guidsToDelete =  [tmparray mutableCopy];
    
    // send our results back to the main thread
    [self performSelectorOnMainThread:@selector(goFree)
                           withObject:nil waitUntilDone:NO];
}
// -------------------------------------------------------------------------------
//  DeleteMultieBook --- 
// -------------------------------------------------------------------------------
- (IBAction)DeleteMultieBook:(id)sender
{
	[NSApp beginSheet:multiDeleteSheet
	   modalForWindow:(NSWindow *)_window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL ];
}
// -------------------------------------------------------------------------------
//  cancelDeleteMulti --- 
// -------------------------------------------------------------------------------
- (IBAction)cancelDeleteMulti:(id)sender
{
	[multiDeleteSheet orderOut:nil];
	[NSApp endSheet:multiDeleteSheet];
}
// Due to BUG in ACS the foreign key constraints on adept.assignedresource - ibfk_2 to
// resourcekey.resourceid and ibfk_1 on adept.resourceitem to resourcekey.resourceid.
// Make them CASCADE instead of RESTRICT to allow delete via web service to function on resource items.
// -------------------------------------------------------------------------------
//  performDelete --- 
// -------------------------------------------------------------------------------
-(void)performDelete:(NSString*)urnid
{
	NSString *serverPath1;  // ManageDistributionRights
	NSString *serverPath2;  // ManageResourceItem
	NSString *serverPath3;  // ManageResourceKey
    NSString *crline = @"\n";
    __block NSString *myKey;    // The disributor ID to use for Production or Development selection made.
	int pAction = [packageSelect selectedRow];	// 0 = dev, 1 = prod, 2 = other
    if(pAction == 0)
	{	// ETG development
		if([developmentServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath1 = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights", developmentServer ];
			serverPath2 = [NSString stringWithFormat:@"http://%@/admin/ManageResourceItem", developmentServer ];
			serverPath3 = [NSString stringWithFormat:@"http://%@/admin/ManageResourceKey", developmentServer ];
            // NOTE: Get distributor ID from NSArray in user defaults via name.
            [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                if ([obj[@"Name"] isEqualToString:@"ETG Internal"]) {
                    myKey = obj[@"ID"];
                    *stop = YES;
                }
            } ];
		}
	}
	if(pAction == 1)
	{	// Harper Production
		if([productionServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath1 = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights", productionServer ];
			serverPath2 = [NSString stringWithFormat:@"http://%@/admin/ManageResourceItem", productionServer ];
			serverPath3 = [NSString stringWithFormat:@"http://%@/admin/ManageResourceKey", productionServer ];
            // NOTE: Get distributor ID from NSArray in user defaults via name.
            [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                if ([obj[@"Name"] isEqualToString:@"eCbt prod"]) {
                    myKey = obj[@"ID"];
                    *stop = YES;
                }
            } ];
		}
	}
	if(pAction == 2)
	{	// OTHER packaging server
		if([[otherServerName stringValue] length] < 6)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
            serverPath1 = @"http://10.40.85.24/cgi-bin/capture.exe";
            serverPath2 = @"http://10.40.85.24/cgi-bin/capture.exe";
            serverPath3 = @"http://10.40.85.24/cgi-bin/capture.exe";
            //                                  serverPath = [NSString stringWithFormat:@"http://%@/admin/ManageDistributionRights", [otherServerName stringValue] ];
            [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                if ([obj[@"Name"] isEqualToString:@"ETG Internal"]) {
                    myKey = obj[@"ID"];
                    *stop = YES;
                }
            } ];
		}
	}
    urnid = [urnid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];    
	NSTimeInterval hourAway = 2 * 60 * 60;
	NSDate *expireDate;
	NSDate *today = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"MM-dd-YY_HH_mm_ss_"];
    self.fileDate = [dateFormatter stringFromDate:today];

	expireDate = [today dateByAddingTimeInterval:hourAway];
    NSString *szExpire = [expireDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S-04:00" timeZone:[NSTimeZone                  timeZoneWithName:@"EST"]
        locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	NSString *expireText = [NSString stringWithFormat:@"<expiration>%@</expiration>\n", szExpire];
	// NOTE: new nonce section
    long max = 23000345772485410;
    long min = 102854372134123;
    long value = (arc4random() % max) + min;
    NSString *newNumn = [NSString stringWithFormat:@"%lu",value];
    // NOTE: Delete from built in distributor ****************************************
    NSString* mydelete = [NSString stringWithFormat:@"<resource>%@</resource>\n", urnid];
    NSData* myBnonce = [newNumn dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce base64EncodedString]];
	NSString *xmlTemplate = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<request action=\"delete\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:nonceText];
	xmlTemplate = [xmlTemplate stringByAppendingString:expireText];
    xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributionRights>\n"];
    // NOTE: distributor ID here
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributor>urn:uuid:00000000-0000-0000-0000-000000000001</distributor>\n"];
    xmlTemplate = [xmlTemplate stringByAppendingString:mydelete];
    xmlTemplate = [xmlTemplate stringByAppendingString:@"</distributionRights>\n"];
    xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributionType>buy</distributionType>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"</request>\n"];
    //
    NSData *xmldata = [NSData dataWithBytes:[xmlTemplate UTF8String] length:[xmlTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize = [[SlapAdobeSerializer alloc] initWithData:xmldata];
    NSData *serialPost = [serialize GetMessage];
    // NOTE Debug only
//    [serialPost writeToFile:@"/Users/slap/del1.bin" atomically:NO];
    NSData * serialPostData = [NSData dataWithData:serialPost];
//    NSData *aKey = [NSData dataWithData:[self builtInDistBin] ];
    NSData *aKey = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey :serialPostData];
//
    NSString *hmacText = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText = [hmacText stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd = [NSString stringWithFormat:@"%@</request>\n", hmacText];
    NSString *xmlToSend = [xmlTemplate stringByReplacingOccurrencesOfString:@"</request>\n" withString:macadd];

    
	NSData *postData = [xmlToSend dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
	[request setURL:[NSURL URLWithString:serverPath1]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	NSError *error;
	NSURLResponse *response;
	NSData *returnData =[NSURLConnection sendSynchronousRequest:request
                                              returningResponse:&response
                                                          error:&error];
	NSString* myresponce;
	myresponce = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = paths[0]; // Get documents directory
    BOOL succeed = [myresponce appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save delete file", nil, nil, nil);
    }
    // NOTE: delete built in load type as test
    value = (arc4random() % max) + min;
    newNumn = [NSString stringWithFormat:@"%lu",value];
    // NOTE: Delete from built in distributor ****************************************
    NSData* myBnonce5 = [newNumn dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText5 = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce5 base64EncodedString]];
	NSString *xmlTemplate5 = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"<request action=\"delete\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate5 = [xmlTemplate5 stringByAppendingString:nonceText5];
	xmlTemplate5 = [xmlTemplate5 stringByAppendingString:expireText];
    xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"<distributionRights>\n"];
    // NOTE: built-in distributor ID here, no need to look at NSArray as we kknow what it should be
	xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"<distributor>urn:uuid:00000000-0000-0000-0000-000000000001</distributor>\n"];
    xmlTemplate5 = [xmlTemplate5 stringByAppendingString:mydelete];
    xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"</distributionRights>\n"];
    xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"<distributionType>loan</distributionType>\n"];
	xmlTemplate5 = [xmlTemplate5 stringByAppendingString:@"</request>\n"];
    //
    NSData *xmldata5 = [NSData dataWithBytes:[xmlTemplate5 UTF8String] length:[xmlTemplate5 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize5 = [[SlapAdobeSerializer alloc] initWithData:xmldata5];
    NSData *serialPost5 = [serialize5 GetMessage];
    // NOTE Debug only
    //    [serialPost writeToFile:@"/Users/slap/del1.bin" atomically:NO];
    NSData * serialPostData5 = [NSData dataWithData:serialPost5];
    //    NSData *aKey = [NSData dataWithData:[self builtInDistBin] ];
    NSData *aKey5 = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey5 :serialPostData5];
    //
    NSString *hmacText5 = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText5 = [hmacText5 stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd5 = [NSString stringWithFormat:@"%@</request>\n", hmacText5];
    NSString *xmlToSend5 = [xmlTemplate5 stringByReplacingOccurrencesOfString:@"</request>\n" withString:macadd5];
    
    
	NSData *postData5 = [xmlToSend5 dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request5 = [[NSMutableURLRequest alloc] init];
	NSString *postLength5 = [NSString stringWithFormat:@"%ld", [postData5 length]];
	[request5 setURL:[NSURL URLWithString:serverPath1]];
	[request5 setHTTPMethod:@"POST"];
	[request5 setValue:postLength5 forHTTPHeaderField:@"Content-Length"];
	[request5 setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request5 setHTTPBody:postData5];
	
	NSData *returnData5 =[NSURLConnection sendSynchronousRequest:request5
                                              returningResponse:&response
                                                          error:&error];
	myresponce = [[NSString alloc] initWithData:returnData5 encoding:NSASCIIStringEncoding];
    succeed = [myresponce appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save delete file", nil, nil, nil);
    }
    
    // NOTE: Now remove remove from eCbt ************************************************
    long value4 = (arc4random() % max) + min;
    NSString *newNumn4 = [NSString stringWithFormat:@"%lu",value4];
    
    NSData* myBnonce4 = [newNumn4 dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText4 = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce4 base64EncodedString]];
	NSString *xmlTemplate4 = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate4 = [xmlTemplate4 stringByAppendingString:@"<request action=\"delete\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate4 = [xmlTemplate4 stringByAppendingString:nonceText4];
	xmlTemplate4 = [xmlTemplate4 stringByAppendingString:expireText];
    xmlTemplate4 = [xmlTemplate4 stringByAppendingString:@"<distributionRights>\n"];
    // distributor here
	NSString *distadd = [NSString stringWithFormat:@"<distributor>%@</distributor>\n", myKey];
    xmlTemplate4 = [xmlTemplate4 stringByAppendingString:distadd];
    xmlTemplate4 = [xmlTemplate4 stringByAppendingString:mydelete];
    xmlTemplate4 = [xmlTemplate4 stringByAppendingString:@"</distributionRights>\n"];
//    xmlTemplate4 = [xmlTemplate4 stringByAppendingString:@"<distributionType>buy</distributionType>\n"];
	xmlTemplate4 = [xmlTemplate4 stringByAppendingString:@"</request>\n"];
    //
    NSData *xmldata4 = [NSData dataWithBytes:[xmlTemplate4 UTF8String] length:[xmlTemplate4 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize4 = [[SlapAdobeSerializer alloc] initWithData:xmldata4];
    NSData *serialPost4 = [serialize4 GetMessage];
    // NOTE Debug only
//    [serialPost writeToFile:@"/Users/slap/del1.bin" atomically:NO];
    NSData * serialPostData4 = [NSData dataWithData:serialPost4];
    //    NSData *aKey = [NSData dataWithData:[self builtInDistBin] ];
    NSData *aKey4 = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey4 :serialPostData4];
    //
    NSString *hmacText4 = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText4 = [hmacText4 stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd4 = [NSString stringWithFormat:@"%@</request>\n", hmacText4];
    NSString *xmlToSend4 = [xmlTemplate4 stringByReplacingOccurrencesOfString:@"</request>\n" withString:macadd4];
    
    
	NSData *postData4 = [xmlToSend4 dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request4 = [[NSMutableURLRequest alloc] init];
	NSString *postLength4 = [NSString stringWithFormat:@"%ld", [postData4 length]];
	[request4 setURL:[NSURL URLWithString:serverPath1]];
	[request4 setHTTPMethod:@"POST"];
	[request4 setValue:postLength4 forHTTPHeaderField:@"Content-Length"];
	[request4 setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request4 setHTTPBody:postData4];
	
	NSURLResponse *response4;
	NSData *returnData4 =[NSURLConnection sendSynchronousRequest:request4
                                              returningResponse:&response4
                                                          error:&error];
	NSString* myresponce4;
	myresponce4 = [[NSString alloc] initWithData:returnData4 encoding:NSASCIIStringEncoding];
    BOOL succeed4 = [myresponce4 appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.self.fileDate]] encoding:NSUTF8StringEncoding];
    [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed4){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save assigment file", nil, nil, nil);
    }

    // NOTE: Now remove remove resource item ************************************************
    long value2 = (arc4random() % max) + min;
    NSString *newNumn2 = [NSString stringWithFormat:@"%lu",value2];
    
    NSData* myBnonce2 = [newNumn2 dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText2 = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce2 base64EncodedString]];
	NSString *xmlTemplate2 = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate2 = [xmlTemplate2 stringByAppendingString:@"<request action=\"delete\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate2 = [xmlTemplate2 stringByAppendingString:nonceText2];
	xmlTemplate2 = [xmlTemplate2 stringByAppendingString:expireText];
    xmlTemplate2 = [xmlTemplate2 stringByAppendingString:@"<resourceItemInfo>\n"];
    xmlTemplate2 = [xmlTemplate2 stringByAppendingString:mydelete];
    xmlTemplate2 = [xmlTemplate2 stringByAppendingString:@"<resourceItem>1</resourceItem>\n"];
    xmlTemplate2 = [xmlTemplate2 stringByAppendingString:@"</resourceItemInfo>\n"];
	xmlTemplate2 = [xmlTemplate2 stringByAppendingString:@"</request>\n"];
    //
    NSData *xmldata2 = [NSData dataWithBytes:[xmlTemplate2 UTF8String] length:[xmlTemplate2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize2 = [[SlapAdobeSerializer alloc] initWithData:xmldata2];
    NSData *serialPost2 = [serialize2 GetMessage];
    // NOTE Debug only
//    [serialPost2 writeToFile:@"/Users/slap/del2.bin" atomically:NO];
    NSData * serialPostData2 = [NSData dataWithData:serialPost2];
//    NSData *aKey2 = [NSData dataWithData:[self builtInDistBin] ];
    NSData *aKey2 = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey2 :serialPostData2];
    //
    NSString *hmacText2 = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText2 = [hmacText2 stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd2 = [NSString stringWithFormat:@"%@</request>\n", hmacText2];
    NSString *xmlToSend2 = [xmlTemplate2 stringByReplacingOccurrencesOfString:@"</request>\n" withString:macadd2];
	NSData *postData2 = [xmlToSend2 dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request2 = [[NSMutableURLRequest alloc] init];
	NSString *postLength2 = [NSString stringWithFormat:@"%ld", [postData2 length]];
	[request2 setURL:[NSURL URLWithString:serverPath2]];
	[request2 setHTTPMethod:@"POST"];
	[request2 setValue:postLength2 forHTTPHeaderField:@"Content-Length"];
	[request2 setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request2 setHTTPBody:postData2];
	
	NSURLResponse *response2;
	NSData *returnData2 =[NSURLConnection sendSynchronousRequest:request2
                                              returningResponse:&response2
                                                          error:&error];
	NSString* myresponce2;
	myresponce2 = [[NSString alloc] initWithData:returnData2 encoding:NSASCIIStringEncoding];
    BOOL succeed2 = [myresponce2 appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed2){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save assigment file", nil, nil, nil);
    }
    // NOTE: Now remove remove resource key  ************************************************
    long value3 = (arc4random() % max) + min;
    NSString *newNumn3 = [NSString stringWithFormat:@"%lu",value3];
    
    NSData* myBnonce3 = [newNumn3 dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText3 = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce3 base64EncodedString]];
	NSString *xmlTemplate3 = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	xmlTemplate3 = [xmlTemplate3 stringByAppendingString:@"<request action=\"delete\" auth=\"builtin\" xmlns=\"http://ns.adobe.com/adept\">\n"];
	xmlTemplate3 = [xmlTemplate3 stringByAppendingString:nonceText3];
	xmlTemplate3 = [xmlTemplate3 stringByAppendingString:expireText];
    xmlTemplate3 = [xmlTemplate3 stringByAppendingString:@"<resourceKey>\n"];
    xmlTemplate3 = [xmlTemplate3 stringByAppendingString:mydelete];
    xmlTemplate3 = [xmlTemplate3 stringByAppendingString:@"</resourceKey>\n"];
	xmlTemplate3 = [xmlTemplate3 stringByAppendingString:@"</request>\n"];
    //
    NSData *xmldata3 = [NSData dataWithBytes:[xmlTemplate3 UTF8String] length:[xmlTemplate3 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serialize3 = [[SlapAdobeSerializer alloc] initWithData:xmldata3];
    NSData *serialPost3 = [serialize3 GetMessage];
    // NOTE Debug only
//    [serialPost3 writeToFile:@"/Users/slap/del3.bin" atomically:NO];
    NSData * serialPostData3 = [NSData dataWithData:serialPost3];
//    NSData *aKey3 = [NSData dataWithData:[self builtInDistBin] ];
    NSData *aKey3 = [NSData dataFromBase64String:[self builtInDist]];
    [self getHmac:aKey3 :serialPostData3];
    //
    NSString *hmacText3 = @"<hmac>SLAPTHIS</hmac>\n";
    hmacText3 = [hmacText3 stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
	NSString *macadd3 = [NSString stringWithFormat:@"%@</request>\n", hmacText3];
    NSString *xmlToSend3 = [xmlTemplate3 stringByReplacingOccurrencesOfString:@"</request>\n" withString:macadd3];
	NSData *postData3 = [xmlToSend3 dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSMutableURLRequest *request3 = [[NSMutableURLRequest alloc] init];
	NSString *postLength3 = [NSString stringWithFormat:@"%ld", [postData3 length]];
	[request3 setURL:[NSURL URLWithString:serverPath3]];
	[request3 setHTTPMethod:@"POST"];
	[request3 setValue:postLength3 forHTTPHeaderField:@"Content-Length"];
	[request3 setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request3 setHTTPBody:postData3];
	
    //	NSError *error;
	NSURLResponse *response3;
	NSData *returnData3 =[NSURLConnection sendSynchronousRequest:request3
                                               returningResponse:&response3
                                                           error:&error];
	NSString* myresponce3;
	myresponce3 = [[NSString alloc] initWithData:returnData3 encoding:NSASCIIStringEncoding];
    NSRange aRange = [myresponce3 rangeOfString:@"E_ADEPT_DATABASE"];
    BOOL myTest =  (aRange.location != NSNotFound);
    if (myTest)
    {
        [mydelete appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@guid_trace.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
        [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    }
    BOOL succeed3 = [myresponce3 appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    [crline appendToFile:[self.deleteFileLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"%@delete.xml", self.fileDate]] encoding:NSUTF8StringEncoding];
    if (!succeed3){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save assigment file", nil, nil, nil);
    }

}

#pragma mark -
#pragma mark ePub or Location decision
// ----------------------------------------------------------------------------
// selectePub --- 
// ----------------------------------------------------------------------------
- (IBAction)selectePub:(id)sender
{
//    NSInteger result;
    NSArray *fileTypes = @[@"epub",@"pdf"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	
	
	[panel setPrompt:@"Choose ePub"]; // Should be localized
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowedFileTypes:fileTypes];
    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];

    if ([panel runModal] == NSFileHandlingPanelOKButton) 
    {
        // get the urls
        NSArray *selectedFiles = [panel URLs];
		NSURL *saveTo = selectedFiles[0];
		NSString *savePath = [saveTo path];
		NSRange xl = [savePath rangeOfString:@"/" options:NSBackwardsSearch];
		NSRange rangeF = NSMakeRange(0, xl.location + 1); 
		[self setValue:[savePath substringWithRange:rangeF] forKey:@"saveLocation"];
		[ePubFile setStringValue:savePath];
    } 
    else 
    {
        // cancel button was clicked
    }    
    [ePubSelect selectCellAtRow:0 column:0];
}
// ----------------------------------------------------------------------------
// selectFolder --- 
// ----------------------------------------------------------------------------
- (IBAction)selectFolder:(id)sender
{
    int result;
    NSArray *fileTypes = @[@"epub",@"pdf"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	
	
	[panel setPrompt:@"Choose folder"]; // Should be localized
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
    [panel setAllowedFileTypes:fileTypes];
    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];

    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];

    result = [panel runModal];
	if (result == NSOKButton)
    {
        // get the urls
        NSArray *selectedFolder = [panel URLs];
		NSURL *readFrom = selectedFolder[0];
		NSString *readPath = [readFrom path];
//		[self makeXmlData:[readFrom relativePath]];
		[ePubDirectory setStringValue:readPath];
    } 
    else 
    {
        // cancel button was clicked
		return;
    }
    [ePubSelect selectCellAtRow:1 column:0];
}
#pragma mark -
#pragma mark Option Sheet control
// -------------------------------------------------------------------------------
//	showOptionsPanel ---
// -------------------------------------------------------------------------------
- (IBAction)showOptionsPanel:(id)sender
{
	[NSApp beginSheet:optionSheet
	   modalForWindow:(NSWindow *)_window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL];
	
	[developmentName setStringValue:developmentServer];
	[productionName setStringValue:productionServer];
    if([myPassword length] > 0)
    {
        [password setStringValue:myPassword];
        [confirmPswd setStringValue:myPassword];
    }
    
	if (useXml) 
	{
		[xmlSelect selectCellAtRow:0 column:0];
	}
	else 
	{
		[xmlSelect selectCellAtRow:1 column:0];
        
	}
}

// -------------------------------------------------------------------------------
//	okOptionsPanel ---
// -------------------------------------------------------------------------------
- (IBAction)okOptionsPanel:(id)sender
{
	BOOL isChanged = NO;
	if(![[developmentName stringValue] isEqualToString:(NSString *)developmentServer])
	{
		developmentServer = [developmentName stringValue];
		isChanged = YES;
	}
	
	if(![[productionName stringValue] isEqualToString:(NSString *)productionServer])
	{
		productionServer = [productionName stringValue];
		isChanged = YES;
	}
	
	if(![[password stringValue] isEqualToString:(NSString *)myPassword])
	{
		myPassword = [password stringValue];
		isChanged = YES;
	}
	
    if (([xmlSelect selectedRow] == 0) && (!useXml)) 
	{
		isChanged = YES;
		useXml = YES;
	}
	
	if (([xmlSelect selectedRow] == 1) && (useXml)) 
	{
		isChanged = YES;
		//		[self setValue:isChanged forKey:@"useXml"];
		useXml = NO;
	}

	if(isChanged)
		[self saveToUserDefaults];
	[optionSheet orderOut:nil];
	[NSApp endSheet:optionSheet];
}
// -------------------------------------------------------------------------------
//	doneOptions ---
// -------------------------------------------------------------------------------
- (IBAction)doneOptions:(NSWindow *)opSheet 
			 developmentServer:(NSString *)developmentServer 
				 productionServer:(NSString *) productionServer
{
	[self saveToUserDefaults];
}
#pragma mark -
#pragma mark Distributor Sheet control
// -------------------------------------------------------------------------------
//	showDistribPanel ---
// -------------------------------------------------------------------------------
- (IBAction)showDistribPanel:(id)sender
{
	[NSApp beginSheet:ditribSheet
	   modalForWindow:(NSWindow *)_window
		modalDelegate:self
	   didEndSelector:NULL
//	   didEndSelector:@selector(cancelDistribSheet:self:)
		  contextInfo:NULL ];
    [distnameselect setDelegate:self];
    distEdit = YES;
    [distnameselect removeAllItems];

    [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* item = obj;
        [distnameselect addItemWithObjectValue:item[@"Name"]];
    }];
}
// ----------------------------------------------------------------------------
// clearDistribPanel --- 
// ----------------------------------------------------------------------------
- (IBAction)clearDistribPanel:(id)sender
{
    [distnameselect selectItemAtIndex:-1]; // First item is at index 0
    [distnameselect setObjectValue:@""];
    [distname setStringValue:@""];
    [distdescrip setStringValue:@""];
    [distid setStringValue:@""];
    [disturl setStringValue:@""];
    [distsecret setStringValue:@""];
}
- (IBAction)deleteDistribPanel:(id)sender
{
    if ([distnameselect indexOfSelectedItem] != -1) {
        NSString * selDist = [distnameselect objectValueOfSelectedItem];
        int shallWe = NSRunAlertPanel(@"Continue ?", [NSString stringWithFormat:@"Delete distributor %@ ?",
                                                      selDist], @"OK", @"Cancel", nil);
        if (shallWe == NSAlertAlternateReturn)
        {
            return;
        }
        [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
            if ([obj[@"Name"] isEqualToString:selDist]) {
                [self.distrubutors removeObject:obj];
                distAltered = YES;
                [self saveToUserDefaults];
                *stop = YES;
            }
        } ];
    } // if
}
// -------------------------------------------------------------------------------
//  cancelDistribSheet --- 
// -------------------------------------------------------------------------------
- (IBAction)cancelDistribSheet:(id)sender
{
	[ditribSheet orderOut:nil];
	[NSApp endSheet:ditribSheet];
    distAltered = NO;
    distEdit = NO;
}
// -------------------------------------------------------------------------------
//  saveDistribSheet --- 
// -------------------------------------------------------------------------------
- (IBAction)saveDistribSheet:(id)sender
{
    if ([distnameselect indexOfSelectedItem] == -1) {
        NSMutableDictionary *distrib = [NSMutableDictionary dictionaryWithCapacity:1];
        distrib[@"Name"] = [distname stringValue];
        distrib[@"Description"] = [distdescrip stringValue];
        distrib[@"ID"] = [distid stringValue];
        distrib[@"URL"] = [disturl stringValue];
        distrib[@"Secret"] = [distsecret stringValue];
        [self.distrubutors addObject:distrib];
        distAltered = YES;
        [self saveToUserDefaults];
    } else {
        NSString * selDist = [distnameselect objectValueOfSelectedItem];
        [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
            if ([obj[@"Name"] isEqualToString:selDist]) {
                [self.distrubutors removeObject:obj];
                NSMutableDictionary *distrib = [NSMutableDictionary dictionaryWithCapacity:1];
                distrib[@"Name"] = [distname stringValue];
                distrib[@"Description"] = [distdescrip stringValue];
                distrib[@"ID"] = [distid stringValue];
                distrib[@"URL"] = [disturl stringValue];
                distrib[@"Secret"] = [distsecret stringValue];
                [self.distrubutors addObject:distrib];
                distAltered = YES;
                [self saveToUserDefaults];
                *stop = YES;
            }
        } ];
    }
}
#pragma mark -
#pragma mark Catalog Assigment selection
// -------------------------------------------------------------------------------
//	selectAssignDistPanel ---
// -------------------------------------------------------------------------------
- (IBAction)selectAssignDistPanel:(id)sender
{
	[NSApp beginSheet:catalogdist
	   modalForWindow:(NSWindow *)_window
		modalDelegate:nil
	   didEndSelector:NULL
     //	   didEndSelector:@selector(doneDistributor:self:)
		  contextInfo:NULL ];
    distEdit = NO;
    isAssign = YES;
    isOverSize = NO;

    [catalogdistselect setDelegate:self];
    [catalogdistselect removeAllItems];
    
	
    [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* item = obj;
        [catalogdistselect addItemWithObjectValue:item[@"Name"]];
    }];
}
// -------------------------------------------------------------------------------
//	overSizeAssignDistPanel ---
// -------------------------------------------------------------------------------
- (IBAction)overSizeAssignDistPanel:(id)sender
{
	[NSApp beginSheet:catalogdist
	   modalForWindow:(NSWindow *)_window
		modalDelegate:nil
	   didEndSelector:NULL
     //	   didEndSelector:@selector(doneDistributor:self:)
		  contextInfo:NULL ];
    distEdit = NO;
    isAssign = YES;
    isOverSize = YES;
    
    [catalogdistselect setDelegate:self];
    [catalogdistselect removeAllItems];
    
	
    [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* item = obj;
        [catalogdistselect addItemWithObjectValue:item[@"Name"]];
    }];
}
// -------------------------------------------------------------------------------
//	doneAssignment ---
// -------------------------------------------------------------------------------
- (IBAction)doneAssignment:(id)sender
{
 	[catalogdist orderOut:nil];
    [NSApp endSheet:catalogdist];
    distEdit = NO;
}
#pragma mark -
#pragma mark Catalog Distributor selection
// -------------------------------------------------------------------------------
//	showDistribPanel ---
// -------------------------------------------------------------------------------
- (IBAction)selectCatalogDistPanel:(id)sender
{
	[NSApp beginSheet:catalogdist
	   modalForWindow:(NSWindow *)_window
		modalDelegate:nil
	   didEndSelector:NULL
//	   didEndSelector:@selector(doneDistributor:self:)
		  contextInfo:NULL ];
    distEdit = NO;
    [catalogdistselect setDelegate:self];
    [catalogdistselect removeAllItems];
    
	
    [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* item = obj;
        [catalogdistselect addItemWithObjectValue:item[@"Name"]];
    }];
}
// -------------------------------------------------------------------------------
//	doneDistributor ---
// -------------------------------------------------------------------------------
- (IBAction)doneDistributor:(id)sender
{
 	[catalogdist orderOut:nil];
    [NSApp endSheet:catalogdist];
    distEdit = NO;
}
// -------------------------------------------------------------------------------
//  runCatalog --- 
// -------------------------------------------------------------------------------
-(IBAction)runCatalog:(id)sender
{
    if (isAssign)
    {
        [catalogdist orderOut:nil];
        [NSApp endSheet:catalogdist];
        int shallWe = NSRunAlertPanel(@"Continue ?", [NSString stringWithFormat:@"Assign For %@ using %@ ?",
                                                      [[packageSelect selectedCell] title] , self.catalogName],
                                      @"OK", @"Cancel", nil);
        if (shallWe == NSAlertAlternateReturn)
        {
            return;
        }
        // Test what kind of file to read for assignment
            if (isOverSize)
            {
                [self overAssignBooks:self];
            }
            else
            {
                [self assignBooks:self];
            }
    }
    else
    {
        [catalogdist orderOut:nil];
        [NSApp endSheet:catalogdist];
        int shallWe = NSRunAlertPanel(@"Continue ?", [NSString stringWithFormat:@"Catalog For %@ using %@ ?",
                                                      [[packageSelect selectedCell] title] , self.catalogName],
                                      @"OK", @"Cancel", nil);
        if (shallWe == NSAlertAlternateReturn)
        {
            return;
        }
        [self getCatalog:self];
    }
}
// -------------------------------------------------------------------------------
//  cancelcatalog --- 
// -------------------------------------------------------------------------------
-(IBAction)cancelcatalog:(id)sender
{
    [catalogdistselect setDelegate:nil];
    [NSApp endSheet:catalogdist];
 	[catalogdist orderOut:nil];
}
#pragma mark -
#pragma mark getCatalog
// -------------------------------------------------------------------------------
//	getCatalog ---
// -------------------------------------------------------------------------------
-(IBAction)getCatalog:(id)sender
{
	NSString *serverPath;
	int pAction = [packageSelect selectedRow];	// 0 = dev, 1 = prod, 2 = other
	// check for selected server information.
	if(pAction == 0)
	{	// ETG development
		if([developmentServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath = [NSString stringWithFormat:@"http://%@/admin/QueryResourceItems", developmentServer ];
            //			serverPath = [NSString stringWithFormat:@"http://10.40.85.24/cgi-bin/capture.exe", developmentServer ];
		}
	}
	if(pAction == 1)
	{	// Harper Production
		if([productionServer length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath = [NSString stringWithFormat:@"http://%@/admin/QueryResourceItems", productionServer ];
		}
	}
	if(pAction == 2)
	{	// OTHER packaging server
		if([[otherServerName stringValue] length] < 8)
		{
			int alertReturn = NSRunAlertPanel(@"Invalid Server", @"Please select a valid address." , @"Cancel", nil, nil);
			if (alertReturn == NSAlertDefaultReturn)
				return;
		}
		else
		{
			serverPath = [otherServerName stringValue];
		}
	}
    
    [transmitButton setEnabled:NO];
    [progress startAnimation:nil];
    // Update fileDate on command issued
    NSDate *today = [NSDate date];
//    self.fileDate = [today descriptionWithCalendarFormat:@"%Y-%m-%d_%H_%M_" timeZone:[NSTimeZone timeZoneWithName:@"EST"]
//                                                  locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"MM-dd-YY_HH_mm_ss_"];
    self.fileDate = [dateFormatter stringFromDate:today];

	NSTimeInterval hourAway = 2 * 60 * 60;
	NSDate *expireDate;
    //	NSDate *today = [NSDate date];
	expireDate = [today dateByAddingTimeInterval:hourAway];
	NSString *szExpire = [expireDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S-04:00" timeZone:[NSTimeZone timeZoneWithName:@"EST"]
                                                            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	// NOTE: new nonce section
	NSString *expireText = [NSString stringWithFormat:@"<expiration>%@</expiration>\n", szExpire];
    NSString *trimexp = [szExpire substringWithRange:NSMakeRange([szExpire length] - 22, 16)];
    NSData* myBnonce = [trimexp dataUsingEncoding:NSUTF8StringEncoding];
	NSString *nonceText = [NSString stringWithFormat:@"<nonce>%@</nonce>\n", [myBnonce base64EncodedString]];
    NSString * xmlTemplate = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
    xmlTemplate = [xmlTemplate stringByAppendingString:@"<request xmlns=\"http://ns.adobe.com/adept\">\n"];
    xmlTemplate = [xmlTemplate stringByAppendingString:@"<distributor>"];
    xmlTemplate = [xmlTemplate stringByAppendingString:self.catalogID];
    xmlTemplate = [xmlTemplate stringByAppendingString:@"</distributor>\n"];
	xmlTemplate = [xmlTemplate stringByAppendingString:nonceText];
	xmlTemplate = [xmlTemplate stringByAppendingString:expireText];
	xmlTemplate = [xmlTemplate stringByAppendingString:@"<QueryResourceItems/>\n"];
    NSString *hmacText = @"<hmac>SLAPTHIS</hmac>\n";
	xmlTemplate = [xmlTemplate stringByAppendingString:@"</request>\n"];
    NSData *xmldata = [NSData dataWithBytes:[xmlTemplate UTF8String] length:[xmlTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	SlapAdobeSerializer *serial = [[SlapAdobeSerializer alloc] initWithData:xmldata];
    NSData *serialPost = [serial GetMessage];
    NSData * serialPostData = [NSData dataWithData:serialPost];
    // using distributor base64 password instead of admin
    // NOTE: distributor base64 password is used here
    NSData *aKey = [NSData dataFromBase64String:self.catalogSecret];
    [self getHmac:aKey :serialPostData];
    hmacText = [hmacText stringByReplacingOccurrencesOfString:@"SLAPTHIS" withString:self.mysigniture];
    xmlTemplate = [xmlTemplate stringByReplacingOccurrencesOfString:@"</request>\n" withString:[NSString stringWithFormat:@"%@</request>\n", hmacText]];
	NSData *postData = [xmlTemplate dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
	// NOTE: debug test here
	NSError *error;
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:serverPath]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/vnd.adobe.adept+xml" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	NSURLResponse *response;
	NSData *returnData =[NSURLConnection sendSynchronousRequest:request
                                              returningResponse:&response
                                                          error:&error];
	NSString* myresponce;
	myresponce = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0]; // Get documents directory
    BOOL succeed = [myresponce writeToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@catalog.xml", self.fileDate]]
                                atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!succeed){
        // Handle error here
        NSRunAlertPanel(@"File save Error", @"Could not save caatalog file", nil, nil, nil);
    }
    [progress stopAnimation:nil];
	[transmitButton setEnabled:YES];
}

#pragma mark -
#pragma mark NSComboBox delegate
// -------------------------------------------------------------------------------
//  comboBoxSelectionDidChange --- 
// -------------------------------------------------------------------------------
- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSString * selDist = [notification.object objectValueOfSelectedItem];
    if (distEdit)
    {
        [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
            if ([obj[@"Name"] isEqualToString:selDist]) {
                [distname setStringValue:obj[@"Name"]];
                [distdescrip setStringValue:obj[@"Description"]];
                [distid setStringValue:obj[@"ID"]];
                [disturl setStringValue:obj[@"URL"]];
                [distsecret setStringValue:obj[@"Secret"]];
                *stop = YES;
            }
        } ];
    }
    else
    {
        [self.distrubutors enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
            if ([obj[@"Name"] isEqualToString:selDist]) {
                self.catalogID = obj[@"ID"];
                self.catalogSecret = obj[@"Secret"];
                self.catalogName = obj[@"Name"];
                *stop = YES;
            }
        } ];
    }
}
#pragma mark -
#pragma mark User Defaults control
// -------------------------------------------------------------------------------
//	saveToUserDefaults ---
// -------------------------------------------------------------------------------
-(void)saveToUserDefaults
{
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	
	if (standardUserDefaults) {
		[standardUserDefaults setObject:developmentServer forKey:@"devName"];
		[standardUserDefaults setObject:productionServer forKey:@"prodName"];
		[standardUserDefaults setObject:myPassword forKey:@"svrPswd"];
		[standardUserDefaults setBool:useXml forKey:@"doXml"];
// NOTE: this caused distributors to go away        if (distAltered) {
            [standardUserDefaults setObject:(NSArray *)self.distrubutors forKey:@"Distrubutors"];
	}
    distAltered = NO;
}
// -------------------------------------------------------------------------------
//	retrieveFromUserDefaults ---
// -------------------------------------------------------------------------------
-(void)retrieveFromUserDefaults
{
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSString *val = nil;
//    NSMutableArray *tmparray = [[NSMutableArray alloc] initWithCapacity:16];
	
	if (standardUserDefaults) 
		val = [standardUserDefaults objectForKey:@"devName"];
	
	if (val != nil) 
	{
		developmentServer = [standardUserDefaults objectForKey:@"devName"];
		productionServer = [standardUserDefaults objectForKey:@"prodName"];
		myPassword = [standardUserDefaults objectForKey:@"svrPswd"];
		useXml = [standardUserDefaults boolForKey:@"doXml"];
		// NOTE: To avoid setting array to null if no entries exist.
		NSArray *tmparray = [standardUserDefaults objectForKey:@"Distrubutors"];
        if ([tmparray count] > 0) {
            self.distrubutors =  [tmparray mutableCopy];
        }
	}
	else 
	{
		developmentServer = @"10.40.85.24:8080";
		productionServer = @"TBD";
		myPassword = @"barada";
		useXml = YES;
	}
    // now the kechain for secure storage
//    if ([tmparray count] > 0) {
//        [tmparray removeAllObjects];
//    }
	return;
}
#pragma mark -
#pragma mark Calculate the SHA1 HMAC
// -------------------------------------------------------------------------------
//	getHmac - :(NSData *)keyData :(NSData *)clearTextData
// -------------------------------------------------------------------------------
-(NSString *)getHmac:(NSData *)keyData :(NSData *)clearTextData
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {0};
    
    CCHmacContext hmacContext;
    CCHmacInit(&hmacContext, kCCHmacAlgSHA1, keyData.bytes, keyData.length);
    CCHmacUpdate(&hmacContext, clearTextData.bytes, clearTextData.length);
    CCHmacFinal(&hmacContext, digest);
    
    NSData *out = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    self.mysigniture = [out base64EncodedString];
    NSString *hash = [out description];
    hash = [hash stringByReplacingOccurrencesOfString:@" " withString:@""];
    hash = [hash stringByReplacingOccurrencesOfString:@"<" withString:@""];
    hash = [hash stringByReplacingOccurrencesOfString:@">" withString:@""];
    return hash;
}
#pragma mark -
#pragma mark Calculate SHA1 for password
-(NSString *)builtInDist
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {0};
    const char *cstr = [myPassword cStringUsingEncoding:NSASCIIStringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:myPassword.length];
    CC_SHA1(data.bytes, data.length, digest);
    NSData *out = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    return [out base64EncodedString];
}
-(NSData*)builtInDistBin
{
    const char *cstr = [myPassword cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:myPassword.length];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, data.length, digest);
    NSData *out = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    return out;
}

#pragma mark -
#pragma mark URL Encode helper
- (NSString *)urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8));
	return result;
}
#pragma mark -
#pragma mark Quit
-(IBAction)bailOut:(id)sender
{
	[NSApp terminate:self];
}

#pragma mark -
#pragma Base DRM catalog selection
// -------------------------------------------------------------------------------
//  selecteCatalog ---
// -------------------------------------------------------------------------------
- (IBAction)selecteCatalog:(id)sender
{
    NSArray *fileTypes = @[@"xml",@"txt"];
 	NSOpenPanel * panel = [NSOpenPanel openPanel];
	NSString *dataPath;
	
	[panel setPrompt:@"Choose DRM Catalog"]; // Should be localized
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowedFileTypes:fileTypes];
    //    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    BOOL didSelect;
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        didSelect = YES;
        // get the urls
    }
    else
    {
        didSelect = NO;
        // cancel button was clicked
        return;
    }
    
    if (didSelect)
    {
        [progress startAnimation:nil];
        NSArray *selectedFiles = [panel URLs];
		NSURL *saveTo = selectedFiles[0];
		dataPath = [saveTo path];
    }
    
    [progress startAnimation:nil];
    // load fail when we spawn a worker thread
    [self goBusy];
//    NSOperationQueue *queue = [NSOperationQueue new];
//    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
//                                                                            selector:@selector(loadCatalogThread)
//                                                                              object:dataPath];
//    [queue addOperation:operation];
//    [operation release];

    [self loadCatalogThread:dataPath];
    
//    [NSThread detachNewThreadSelector:@selector(loadCatalogThread:)
//                             toTarget:self withObject:dataPath];
}
// -------------------------------------------------------------------------------
//  getIsbn2GuidThread ---
// -------------------------------------------------------------------------------
-(void)loadCatalogThread:(NSString*)dataPath
{
    [self.ItemInfo setValue:dataPath forKey:@"fileToLoad"];
    [self.ItemInfo loadItems];
    // send our results back to the main thread
//    [self performSelectorOnMainThread:@selector(goFree)
//                           withObject:nil waitUntilDone:YES];
    [self goFree];
}
-(BOOL)CheckCatalog:(NSString*)searchIsbn
{
    __block BOOL wasFound = NO;
    
    [self.ItemInfo.resourceItems enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
        if ([[object valueForKey:@"identifier"] isEqualToString:(NSString*)searchIsbn]) {
            self.theGuid = [object valueForKey:@"resource"];
            stop = YES;
            wasFound = YES;
        }
    }];
    
    return wasFound;
}

@end

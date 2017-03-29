//
//  AppController.h
//  HCePub
//
//  Created by LaPierre, Stephen on 5/26/10.
//  Copyright 2012 SlapWare. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "resourceItemInfo.h"
#import "resourceItem.h"

//@class SlapParam;


@interface AppController : NSObject <NSApplicationDelegate,NSComboBoxDelegate> {
	IBOutlet NSProgressIndicator *progress;
	IBOutlet NSButton *transmitButton;	
	IBOutlet NSMatrix *ePubSelect;
	IBOutlet NSMatrix *packageSelect;
	IBOutlet NSTextField *ePubFile;
	IBOutlet NSTextField *ePubDirectory;
	IBOutlet NSButton *getFileButton;	
	IBOutlet NSButton *getDirButton;	
	IBOutlet NSButton *justQuit;	
	// option values below here.
	IBOutlet NSWindow *optionSheet;
	IBOutlet NSTextField *password;
	IBOutlet NSTextField *confirmPswd;
	IBOutlet NSTextField *developmentName;
	IBOutlet NSTextField *productionName;
	IBOutlet NSTextField *otherServerName;
	IBOutlet NSTextField *fileToDelete;
	IBOutlet NSTextField *listToDelete;
	IBOutlet NSMatrix *xmlSelect;
//    NSString *mysigniture;
	bool useXml;
	// ditributors values below here.
	IBOutlet NSWindow *ditribSheet;
    IBOutlet NSTextField *distname;
    IBOutlet NSTextField *distdescrip;
    IBOutlet NSTextField *distid;
    IBOutlet NSTextField *disturl;
    IBOutlet NSTextField *distsecret;
    IBOutlet NSComboBox *distnameselect;
	IBOutlet NSButton *distCancel;
	IBOutlet NSButton *distNew;
	IBOutlet NSButton *distSave;
	IBOutlet NSWindow *singleDeleteSheet;
	IBOutlet NSWindow *multiDeleteSheet;
	IBOutlet NSButton *cancelDeleteSingle;
	IBOutlet NSButton *cancelDeleteMulti;
	IBOutlet NSButton *doDeleteSingle;
	IBOutlet NSButton *doDeleteMulti;
	IBOutlet NSButton *selectMultiGuid;
	IBOutlet NSButton *distDelete;
	// ditributors catalog selection.
	IBOutlet NSWindow *catalogdist;
    IBOutlet NSComboBox *catalogdistselect;
	IBOutlet NSButton *catalogRun;
	IBOutlet NSButton *catalogCancel;
	// User defaults and key values
    IBOutlet NSButton *GalleyCheckBox;
}

-(IBAction)transmit:(id)sender;
-(IBAction)bailOut:(id)sender;
-(IBAction)getCatalog:(id)sender;

-(IBAction)selectePub:(id)sender;
-(IBAction)selectFolder:(id)sender;

-(IBAction)showOptionsPanel:(id)sender;
-(IBAction)okOptionsPanel:(id)sender;
-(IBAction)doneOptions:(NSWindow *)opSheet
			 developmentServer:(NSString *)developmentServer 
				 productionServer:(NSString *) productionServer;

-(IBAction)selectAssignDistPanel:(id)sender;
-(IBAction)overSizeAssignDistPanel:(id)sender;
-(IBAction)doneAssignment:(id)sender;

- (IBAction)deleteDistribPanel:(id)sender;
- (IBAction)clearDistribPanel:(id)sender;
- (IBAction)showDistribPanel:(id)sender;
- (IBAction)cancelDistribSheet:(id)sender;
- (IBAction)cancelDeleteSingle:(id)sender;
- (IBAction)cancelDeleteMulti:(id)sender;
- (IBAction)saveDistribSheet:(id)sender;
- (IBAction)doneDistributor:(id)sender;
- (IBAction)showDistribPanel:(id)sender;
- (IBAction)DeleteMultieBook:(id)sender;
- (IBAction)DeleteSingleBook:(id)sender;
- (IBAction)performMultiDelete:(id)sender;
- (IBAction)selecteGuidList:(id)sender;
- (IBAction)selecteCatalog:(id)sender;

-(void)assignBooks:(id)sender;
-(void)sendassign:(NSString*)urnid;
-(void)performDelete:(NSString*)urnid;

-(IBAction)runCatalog:(id)sender;
-(IBAction)cancelcatalog:(id)sender;

-(void)goBusy;
-(void)goFree;
-(void)saveToUserDefaults;
-(void)retrieveFromUserDefaults;
-(NSString *)builtInDist;
//-(void)threadme:(id)params;
-(void)selecteGuidListThread:(NSString*)guidFile;
// for add or replace
-(void)loadCatalogThread:(NSString*)dataPath;
-(BOOL)CheckCatalog:(NSString*)searchIsbn;

-(NSString *)urlEncodeValue:(NSString *)str;
-(NSString *)filePrepare:(NSString *)pfile;
//-(void)sendToDrm:(NSString *)pdata toServer:(NSString *)pserver isSingle:(bool) isSingle;
-(void)sendToDrm:(NSString *)pdata;
-(NSString *)getHmac:(NSData *)keyData :(NSData *)clearTextData;
-(NSData*)builtInDistBin;

@property(readwrite, assign) BOOL readyToPost;
@property(readwrite, assign) BOOL readyToSend;
@property(readwrite, strong) NSString *activeServer;
@property(readwrite, strong) NSString *xml2Send;
@property(readwrite, strong) NSString *fileDate;
@property(readwrite, strong) NSString *saveLocation;
@property(readwrite, strong) NSString *mysigniture;
@property (nonatomic,strong) NSMutableArray *distrubutors;
@property (nonatomic,strong) NSMutableArray *guidsToDelete;
@property (nonatomic, strong) IBOutlet NSWindow *window;
@property(readwrite, strong) NSString *catalogID;
@property(readwrite, strong) NSString *catalogSecret;
@property(readwrite, strong) NSString *catalogName;
@property(readwrite, strong) NSString *deleteFileLocation;
@property(readwrite, strong) NSString *theGuid;
@property(readwrite, assign) BOOL isGalley;
@property (readwrite,strong) resourceItemInfo *ItemInfo;

@end

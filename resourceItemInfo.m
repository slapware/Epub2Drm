//
//  resourceItemInfo.m
//  CatalogParser
//
//  Created by Stephen La Pierre on 8/20/12.
//  Copyright (c) 2012 Stephen La Pierre. All rights reserved.
//

#import "resourceItemInfo.h"
#import "resourceItem.h"
#import "TBXML.h"
#import "TBXML.h"

@implementation resourceItemInfo
{
	TBXML *tbxml;
    BOOL isLoading;
}

//@synthesize resourceItems, fileToLoad;

- (id)init
{
    self = [super init];
    if (self != nil)
	{
        // initialization code
        // NOTE: init the resourceItems arrays
        self.resourceItems = [[NSMutableArray alloc] initWithCapacity:20000];
        isLoading = NO;
//        [self loadItems];
    }
	
    return self;
}

-(void)loadItems
{
    if ([self.resourceItems count] > 0) {
        [self.resourceItems removeAllObjects];
    }
//    [[tbxml alloc] init];
//    NSError *error;
    NSData *xmlData = [NSData dataWithContentsOfFile:self.fileToLoad];
    tbxml = [TBXML newTBXMLWithXMLData:xmlData];
	TBXMLElement *root = tbxml.rootXMLElement;
	
	// if root element is valid
	if (root)
    {
		TBXMLElement *node = [TBXML childElementNamed:@"resourceItemInfo" parentElement:root];
        // if a node element was found
        while (node != nil)
        {
            // NOTE: Important to get child within the node here, not ou of loop.
            TBXMLElement *metadata = [TBXML childElementNamed:@"metadata" parentElement:node];
            // instantiate a node object
            resourceItem *anItem= [[resourceItem alloc] init];
            
            // find the name child element of the node element
            TBXMLElement *resource = [TBXML childElementNamed:@"resource" parentElement:node];
            // if we found a name
            if (resource != nil) {
                // obtain the text from the name element
                anItem.resource = [TBXML textForElement:resource];
            }
            
            // find the status child element of the node element
            TBXMLElement *title = [TBXML childElementNamed:@"dc:title" parentElement:metadata];
            // if we found a status
            if (title != nil) {
                // obtain the text from the status element
                anItem.title = [TBXML textForElement:title];
            }
            
            // find the message child element of the node element
            TBXMLElement *creator = [TBXML childElementNamed:@"dc:creator" parentElement:metadata];
            // if we found a message
            if (creator != nil) {
                // obtain the text from the text element
                anItem.creator = [TBXML textForElement:creator];
            }
            
            // find the URL child element of the node element
            TBXMLElement *format = [TBXML childElementNamed:@"dc:format" parentElement:metadata];
            // if we found a url
            if (format != nil) {
                // obtain the text from the text element
                anItem.format = [TBXML textForElement:format];
            }
            
            // find the date child element of the node element
            TBXMLElement *publisher = [TBXML childElementNamed:@"dc:publisher" parentElement:metadata];
            // if we found a date
            if (publisher != nil) {
                // obtain the text from the text element
                anItem.publisher = [TBXML textForElement:publisher];
            }
            
            // find the date child element of the node element
            TBXMLElement *language = [TBXML childElementNamed:@"dc:language" parentElement:metadata];
            // if we found a time
            if (language != nil) {
                // obtain the text from the text element
                anItem.language = [TBXML textForElement:language];
            }
            
            // find the date child element of the node element
            TBXMLElement *description = [TBXML childElementNamed:@"description" parentElement:node];
            // if we found a time
            if (description != nil) {
                // obtain the text from the text element
                anItem.description = [TBXML textForElement:description];
            }
            
            // find the date child element of the node element
            TBXMLElement *identifier = [TBXML childElementNamed:@"dc:identifier" parentElement:metadata];
            // if we found a time
            if (identifier != nil) {
                // obtain the text from the text element
                anItem.identifier = [TBXML textForElement:identifier];
            }
            
            // find the date child element of the node element
            TBXMLElement *src = [TBXML childElementNamed:@"src" parentElement:node];
            // if we found a time
            if (src != nil) {
                // obtain the text from the text element
                anItem.src = [TBXML textForElement:src];
            }
            
            // add the node object to the nodes array and release the resource
            [self.resourceItems addObject:anItem];
            anItem = nil;
            //				[anItem release];
            
            // find the next sibling element named "resourceItemInfo"
            node = [TBXML nextSiblingNamed:@"resourceItemInfo" searchFromElement:node];
        }
        
        // find the next sibling element named "author"
        node = [TBXML nextSiblingNamed:@"resourceItemInfo" searchFromElement:root];

    }
}

@end

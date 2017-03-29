//
//  resourceItemInfo.h
//  CatalogParser
//
//  Created by Stephen La Pierre on 8/20/12.
//  Copyright (c) 2012 Stephen La Pierre. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TBXML;
@class resourceItem;

@interface resourceItemInfo : NSObject

@property (nonatomic, strong) NSMutableArray *resourceItems;
@property (nonatomic, copy) NSString *fileToLoad;

-(void)loadItems;

@end

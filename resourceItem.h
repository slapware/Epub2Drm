//
//  resourceItem.h
//  CatalogParser
//
//  Created by Stephen La Pierre on 8/20/12.
//  Copyright (c) 2012 Stephen La Pierre. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface resourceItem : NSObject

@property (nonatomic, copy) NSString *resource;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *creator;
@property (nonatomic, copy) NSString *format;
@property (nonatomic, copy) NSString *publisher;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *description;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *src;

@end

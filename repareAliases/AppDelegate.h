//
//  AppDelegate.h
//  repareAliases
//
//  Created by Dominik Pich on 20.01.13.
//  Copyright (c) 2013 Dominik Pich. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDCommandLineInterface.h"

@interface AppDelegate : NSObject <DDCliApplicationDelegate>
{
    NSString * _directory;
    NSDictionary *_paths;
    NSDictionary *_volumeUUIDS;
    int _verbosity;
    BOOL _version;
    BOOL _help;
}
@end
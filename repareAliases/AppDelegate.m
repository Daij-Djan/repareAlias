//
//  AppDelegate.m
//  repareAliases
//
//  Created by Dominik Pich on 20.01.13.
//  Copyright (c) 2013 Dominik Pich. All rights reserved.
//

#import "AppDelegate.h"
#import "NSString+SymLinksAndAliases.h"
#import "FMDatabase.h"

@implementation AppDelegate

- (void) setVerbose: (BOOL) verbose;
{
    if (verbose)
        _verbosity++;
    else if (_verbosity > 0)
        _verbosity--;
}

- (void) setDirectory: (NSString *) file;
{
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir] || !isDir)
    {
        @throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"Path doesnt exist or is no directory: %@", file]
                                             exitCode: EX_USAGE];
    }
    _directory = [file copy];
}

#pragma mark -

- (void) application: (DDCliApplication *) app
    willParseOptions: (DDGetoptLongParser *) optionsParser;
{
    DDGetoptOption optionTable[] =
    {
        // Long         Short   Argument options
        {"directory",  'D',    DDGetoptRequiredArgument},
        {"verbose",    'v',    DDGetoptNoArgument},
        {"version",    0,      DDGetoptNoArgument},
        {"help",       'h',    DDGetoptNoArgument},
        {nil,          0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable];
}

- (int) application: (DDCliApplication *) app
   runWithArguments: (NSArray *) arguments;
{
    if (_help)
    {
        [self printHelp];
        return EXIT_SUCCESS;
    }
    
    if (_version)
    {
        [self printVersion];
        return EXIT_SUCCESS;
    }
    
    if ([arguments count] < 3)
    {
        ddfprintf(stderr, @"%@: At least one rule is required, that means three arguments: [verb] [old] [new]\n", DDCliApp);
        [self printUsage: stderr];
        ddfprintf(stderr, @"Try `%@ --help' for more information.\n",
                  DDCliApp);
        return EX_USAGE;
    }
    
    if(_verbosity>0) ddprintf(@"Building rules...");
    [self buildRules:arguments];
    if(_verbosity>0) ddprintf(@"done\n===\n");
    if(_verbosity>0) ddprintf(@"rules: %@\n%@", _paths, _volumeUUIDS);
    if(_verbosity>0) ddprintf(@"done\n===\n");
    
    if(_verbosity>0) ddprintf(@"Processing dir, looking for library: %@...", _directory);
    NSString *library = [self findLibraryFileAt:_directory];
    if(_verbosity>0) ddprintf(@"done\n");

    if(!library.length) {
        return EX_IOERR;
    }
    
    if(_verbosity>0) ddprintf(@"Processing library, fixing %@...", _directory);
    [self fixPathsInLibraryFileAt:library];
    if(_verbosity>0) ddprintf(@"done\n");
    
    return EXIT_SUCCESS;
}

#pragma mark -

- (void) printUsage: (FILE *) stream;
{
    ddfprintf(stream, @"%@: Usage [OPTIONS] <arguments> [...]\n\n"
              "The arguments must be RULES. A rule is a VERB ARG 1 ARG2. Currently the rules 'path' and 'volume' exist\n\n"
              "a path rule takes two path fragements to exchange (e.g. replace /dominik with /dpich - the second path of each pair is the new path!)\n"
              "a volume rule does the same but with volume UUIDs. (e.g. replace 04D0C367-7A0D-3784-8233-42D2F2646391 with 5B2BE939-94D3-32E0-BC6D-212CE341D087 -- the two volumes must be known to iPhoto (launch the app two make a volume known)", DDCliApp);
}

- (void) printHelp;
{
    [self printUsage: stdout];
    printf("\n"
           "  -I, --directory PATH          Directory of the iPhoto library to repair aliases in\n"
           "  -v, --verbose                 Increase verbosity\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "An application for fixing iPhotos aliases to external images.\n");
}

- (void) printVersion;
{
    ddprintf(@"%@ version %s\n", DDCliApp, @"1.0");
}

#pragma mark -

- (void)buildRules:(NSArray*)args {
    NSMutableDictionary *paths = [NSMutableDictionary dictionaryWithCapacity:args.count/3];
    NSMutableDictionary *volumeUUIDs = [NSMutableDictionary dictionaryWithCapacity:args.count/3];
    NSUInteger c = args.count - 3;
    for (NSUInteger i = 0; i<=c; i+=3) {
        id verb = [args[i] lowercaseString];
        id arg1 = args[i+1];
        id arg2 = args[i+2];
        
        if([verb isEqualToString:@"path"]) {
            if(paths[arg1] != nil) {
                ddprintf(@"Skipping %@ rule for %@, because I already have an existing rule for that", verb, arg1);
                continue;
            }
            
            paths[arg1] = arg2;
        }
        else if([verb isEqualToString:@"volume"]) {
            if(volumeUUIDs[arg1] != nil) {
                ddprintf(@"Skipping %@ rule for %@, because I already have an existing rule for that", verb, arg1);
                continue;
            }
            
            volumeUUIDs[arg1] = arg2;
        }
        else {
            ddprintf(@"Ignoring rule for unknown verb %@", verb);
        }
    }
    
    _paths = paths;
    _volumeUUIDS = volumeUUIDs;
}

- (NSString*)findLibraryFileAt:(NSString*)dir {
    NSString *path = nil;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:dir]
                                             includingPropertiesForKeys:@[NSURLIsAliasFileKey]
                                                                options:0
                                                           errorHandler:
                         ^BOOL(NSURL *url, NSError *error) {
                             ddprintf(@"Error %@ when processing %@, try to continue", error, url);
                             return YES;
                         }];
    for (NSURL *url in enumerator) {
        NSError *error = nil;
        NSNumber *isAliasFile = nil;
        
        if(![url getResourceValue:&isAliasFile forKey:NSURLIsAliasFileKey error:&error]) {
            ddprintf(@"failed to inspect %@ - skipping", url);
        }
        
        if(!isAliasFile.boolValue)
            continue;

        if([url.path rangeOfString:@"Library.apdb"].location == NSNotFound)
            continue;
        
        if(_verbosity>0) ddprintf(@"Processing alias: %@...", url);
        path = [url.path stringByResolvingSymlinksAndAliases];
        if(_verbosity>0) ddprintf(@"done\n");
    }
    
    return path;
}

- (void)fixPathsInLibraryFileAt:(NSString*)libraryDatabase {
    FMDatabase *db = [FMDatabase databaseWithPath:libraryDatabase];
    if(![db open]) {
        ddprintf(@"Failed to open database at %@", libraryDatabase);
        return;
    }
    
    if(![db beginTransaction]) {
        ddprintf(@"Failed to start Transaction to update database: %d, %@", db.lastErrorCode, db.lastErrorMessage);
        [db close];
        return;
    }
    
    id sql = @"SELECT modelId,imagePath,fileVolumeUuid FROM RKMaster";
    FMResultSet *resultSet = [db executeQuery:sql];
    while ([resultSet next]) {
        [self fixPathsForRow:resultSet inDB:db];
        [self fixVolumeForRow:resultSet inDB:db];
    }
    
    if(![db commit]) {
        ddprintf(@"Failed to commit database transaction: %d,%@", [db lastErrorCode], [db lastErrorMessage]);
    }
    
    if(![db close]) {
        ddprintf(@"Failed to propertly close database at %@", libraryDatabase);
    }
}

#pragma mark -

- (void)fixPathsForRow:(FMResultSet*)row inDB:(FMDatabase*)db {
    //get row values
    NSString *modelId = [row stringForColumn:@"modelId"];
    NSString *orgFilename = [row stringForColumn:@"imagePath"];

    //fix path if needed
    NSMutableString *newFilename = [orgFilename mutableCopy];
    for (NSString *orgPathFragment in _paths.allKeys) {
        [newFilename replaceOccurrencesOfString:orgPathFragment withString:_paths[orgPathFragment] options:0 range:NSMakeRange(0, newFilename.length)];
    }
    if(!newFilename.length || [newFilename isEqualToString:orgFilename])
        return;

    //issue a database update
    if(_verbosity>0) ddprintf(@"\nUpdating path %@ to %@...", orgFilename, newFilename);
    id sql = [NSString stringWithFormat:@"UPDATE RKMaster SET imagePath=\"%@\" WHERE modelId=\"%@\"", newFilename, modelId];
    BOOL br = [db executeUpdate:sql];
    if(!br || sqlite3_changes(db.sqliteHandle)==0)
        ddprintf(@"failed with db error: %d,%@", db.lastErrorCode, db.lastErrorMessage);
    if(_verbosity>0) ddprintf(@"done\n");
}

- (void)fixVolumeForRow:(FMResultSet*)row inDB:(FMDatabase*)db {
    //get row values
    NSString *modelId = [row stringForColumn:@"modelId"];
    NSString *orgVolumeID = [row stringForColumn:@"fileVolumeUuid"];
    NSString *orgVolumeUUID = nil;
    
    //get org UUID
    id sql = [NSString stringWithFormat:@"SELECT diskUuid FROM RKVolume WHERE uuid=\"%@\"", orgVolumeID];
    FMResultSet *volumeInfo = [db executeQuery:sql];
    while ([volumeInfo next]) {
        orgVolumeUUID = [volumeInfo stringForColumn:@"diskUuid"];
    }

    //replace if needed
    NSString *newVolumeUUID = _volumeUUIDS[orgVolumeUUID];
    NSString *newVolumeID;
    if(!newVolumeUUID)
        return;

    //get new ID
    sql = [NSString stringWithFormat:@"SELECT uuid FROM RKVolume WHERE diskUuid=\"%@\"", newVolumeUUID];
    volumeInfo = [db executeQuery:sql];
    while ([volumeInfo next]) {
        newVolumeID = [volumeInfo stringForColumn:@"uuid"];
    }
    
    if(!newVolumeID) {
        ddprintf(@"error insertion of new volume not implemented [write to RKVolume to do it], skippping rule");
        return;
    }
    
    //issue a database update
    if(_verbosity>0) ddprintf(@"\nUpdating volume %@ to %@...", orgVolumeID, newVolumeID);
    sql = [NSString stringWithFormat:@"UPDATE RKMaster SET fileVolumeUuid=\"%@\" WHERE modelId=\"%@\"", newVolumeID, modelId];
    BOOL br = [db executeUpdate:sql];
    if(!br || sqlite3_changes(db.sqliteHandle)==0)
        ddprintf(@"failed with db error: %d,%@", db.lastErrorCode, db.lastErrorMessage);
    if(_verbosity>0) ddprintf(@"done\n");
}

@end

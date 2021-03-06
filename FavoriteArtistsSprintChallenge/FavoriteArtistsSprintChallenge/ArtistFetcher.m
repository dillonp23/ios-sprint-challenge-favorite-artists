//
//  ArtistFetcher.m
//  FavoriteArtistsSprintChallenge
//
//  Created by Dillon P on 4/19/20.
//  Copyright © 2020 Dillon's Lambda Team. All rights reserved.
//

#import "ArtistFetcher.h"

static NSString *const ArtistFetcherBaseURLString = @"https://www.theaudiodb.com/api/v1/json/1/search.php";

@implementation ArtistFetcher

-(void)fetchArtistFromServer:(NSString *)artistName WithCompletionHandler:(ArtistFetcherCompletionHandler)completionHandler
{
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithString:ArtistFetcherBaseURLString];
    
    urlComponents.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"s" value:artistName],
    ];
    
    NSURL *url = urlComponents.URL;
    NSLog(@"Artist fetching url is: %@", url);
    
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        if (error) {
            NSLog(@"Error getting artist info: %@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            
            return;
        }
        
        NSError *jsonError;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!dictionary) {
            NSLog(@"Error decoding JSON: %@", jsonError);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, jsonError);
            });
        }
        
        NSArray *artistsDictionariesArray = [dictionary objectForKey:@"artists"];
        if (![artistsDictionariesArray isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, [[NSError alloc] initWithDomain:@"No Artists Array" code:-2 userInfo:nil]);
            });
        }
        
        if (!artistsDictionariesArray) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, [[NSError alloc] initWithDomain:@"No Artists Array" code:-2 userInfo:nil]);
            });
        } else {
            NSDictionary *artistDictionary = [artistsDictionariesArray objectAtIndex:0];
            if (![artistDictionary isKindOfClass:[NSDictionary class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, [[NSError alloc] initWithDomain:@"No Artist Dictionary" code:-2 userInfo:nil]);
                });
            } else {
                Artist *artist = [[Artist alloc] initWithDictionary:artistDictionary];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(artist, nil);
                });
            }
        }
        
    }] resume];
}

// MARK: - Initial App Set-Up Methods

- (void)createOrLoadArtistDictionary
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *artistsDictionaryURL = [self getLocalArtistsDictionaryURL];
    
    if (![fileManager fileExistsAtPath:artistsDictionaryURL.path]) {
        NSError *error = nil;
        [fileManager createFileAtPath:artistsDictionaryURL.path contents:nil attributes:nil];
        if (!error) {
            error = [self createLocalArtistDictionary];
            if (error) {
                NSLog(@"Error saving dictionary to URL: %@", error);
            }
        }
        
    } else {
        NSDictionary *loadedArtists = [[NSDictionary alloc] initWithContentsOfURL:artistsDictionaryURL];
        self.localArtistDictionary = loadedArtists;
        self.allArtists = [[NSMutableArray alloc] init];
        for (NSDictionary *singleArtistDictionary in loadedArtists.allValues) {
            [self parseLocalArtistDataWithDictionary:singleArtistDictionary];
        }
    }
}

- (NSError *)createLocalArtistDictionary
{
    NSURL *url = [self getLocalArtistsDictionaryURL];
    Artist *testArtist = [[Artist alloc] initWithArtistName:@"Test" yearFounded:1999 artistBio:@"This is a test artist"];
    NSDictionary *testDictionary = [testArtist toDictionary];
    NSString *testKey = testArtist.artistName;
    
    Artist *anotherArtist = [[Artist alloc] initWithArtistName:@"Test2" yearFounded:1999 artistBio:@"This is a test artist"];
    NSDictionary *anotherDictionary = [anotherArtist toDictionary];
    NSString *anotherKey = anotherArtist.artistName;
    
    NSDictionary *testArtistsDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:testDictionary, testKey, anotherDictionary, anotherKey, nil];
    NSError *error = nil;
    [testArtistsDictionary writeToURL:url error:&error];
    
    if (!error) {
        self.localArtistDictionary = testArtistsDictionary;
        self.allArtists = [[NSMutableArray alloc] init];
        for (NSDictionary *singleArtistDictionary in self.localArtistDictionary.allValues) {
            [self parseLocalArtistDataWithDictionary:singleArtistDictionary];
        }
        return nil;
    } else {
        return error;
    }
}

- (void)saveLocalDictionaryWithNewArtist:(Artist *)artist
{
    NSURL *url = [self getLocalArtistsDictionaryURL];
    NSMutableDictionary *artistsDictionary = [[NSMutableDictionary alloc] initWithDictionary:self.localArtistDictionary];
    
    NSDictionary *newArtistDetailsDictionary = [artist toDictionary];
    NSString *newArtistKey = artist.artistName;
    NSDictionary *newArtistDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:newArtistDetailsDictionary, newArtistKey, nil];
    
    [artistsDictionary addEntriesFromDictionary:newArtistDictionary];
    
    NSError *error = nil;
    [artistsDictionary writeToURL:url error:&error];
    
    if (!error) {
        self.localArtistDictionary = artistsDictionary;
        [self.allArtists removeAllObjects];
        for (NSDictionary *singleArtistDictionary in self.localArtistDictionary.allValues) {
            [self parseLocalArtistDataWithDictionary:singleArtistDictionary];
        }
    }
}



// MARK: - Helper Functions

- (void)parseLocalArtistDataWithDictionary:(NSDictionary *)dictionary
{
    Artist *singleArtist = [[Artist alloc] initWithDictionary:dictionary];
    [self.allArtists addObject:singleArtist];
}


- (NSURL *)getLocalArtistsDictionaryURL
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"artists.plist"];
    
    NSURL *artistsDictionaryURL = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
    
    return artistsDictionaryURL;
}




@end

/*
 *  CCAudioPlayer - Objective-C Audio player support remote and local files, Sitting on top of AVPlayer:
 *
 *      https://github.com/yechunjun/CCAudioPlayer
 *
 *  This code is distributed under the terms and conditions of the MIT license.
 *
 *  Author:
 *      Chun Ye <chunforios@gmail.com>
 *
 */

#import "Track.h"

@implementation Track

@end

@implementation Track (Provider)

+ (void)load
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self remoteTracks];
    });
}

+ (NSArray *)remoteTracks
{
    static NSArray *tracks = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://douban.fm/j/mine/playlist?type=n&channel=1004693&from=mainsite"]];
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:NULL
                                                         error:NULL];
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        
        NSMutableArray *allTracks = [NSMutableArray array];
        for (NSDictionary *song in [dict objectForKey:@"song"]) {
            Track *track = [[Track alloc] init];
            [track setArtist:[song objectForKey:@"artist"]];
            [track setTitle:[song objectForKey:@"title"]];
            [track setAudioFileURL:[NSURL URLWithString:[song objectForKey:@"url"]]];
            [allTracks addObject:track];
        }
        
        tracks = [allTracks copy];
        NSLog(@"%@", tracks);
    });
    return tracks;
}

@end
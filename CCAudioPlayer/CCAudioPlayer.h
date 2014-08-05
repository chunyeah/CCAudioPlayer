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

#import <Foundation/Foundation.h>

#define CCLog(fmt, ...)    NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

typedef NS_ENUM(NSInteger, CCAudioPlayerState) {
    CCAudioPlayerStateNone = 0,
    CCAudioPlayerStateRunning = 1, // Player and audio file get ready for playing
    CCAudioPlayerStateBuffering = (1 << 1), // Buffering the audio content. If player status is playing but no buffer to play, player will be this state
    CCAudioPlayerStatePlaying = (1 << 2), // Playing
    CCAudioPlayerStatePaused = (1 << 3), // Paused
    CCAudioPlayerStateStopped = (1 << 4), // Raised when an audio file has finished playing
    CCAudioPlayerStateError = (1 << 5), // Raised when an unexpected and possibly unrecoverable error has occured
    CCAudioPlayerStateDisposed = (1 << 6) // Audio player is disposed
};

typedef NS_ENUM(NSInteger, CCAudioPlayerErrorCode) {
    CCAudioPlayerErrorNone = 0,
    CCAudioPlayerErrorPlayerInitializeFailed, // Player initialize failed
    CCAudioPlayerErrorBytesInitializeFailed, // Audio file initialize failed
    CCAudioPlayerErrorUnknow //Audio item play failed, but unknow reason
};

@interface CCAudioPlayer : NSObject

/// Initializes a new CCAudioPlayer with the given url, the url supports remote and local audio file.
- (instancetype)initWithContentsOfURL:(NSURL *)url;

+ (instancetype)audioPlayerWithContentsOfURL:(NSURL *)url;

@property (nonatomic, readonly) NSTimeInterval progress; // Gets the current item progress in seconds, Support KVO

@property (nonatomic, readonly) CCAudioPlayerState playerState; // Gets the current player state, Support KVO

@property (nonatomic, strong, readonly) NSURL *url; // Gets the current playing url

@property (nonatomic, readonly) NSTimeInterval duration; // Gets the current item duration in seconds

@property (nonatomic, readonly) CCAudioPlayerErrorCode errorCode; // Gets the error code when the player state is error

@property (nonatomic, readonly) BOOL isPlaying; // Gets the current player is playing or not

// Track Player Status Block, update progress and player state
- (void)trackPlayerProgress:(void (^)(NSTimeInterval progress))progressHandler playerState:(void(^)(CCAudioPlayerState playerState))playerStateHandler;

- (void)play;

- (void)pause;

- (void)seekToTime:(NSTimeInterval)toTime;

// Disposes the CCAudioPlayer and frees up all resources.
// Make sure that call this method when you don't need current player.
// If you want to play next audio file, you need call [xxx dispose] firstly, then create a new CCAudioPlayer.
- (void)dispose;

@end

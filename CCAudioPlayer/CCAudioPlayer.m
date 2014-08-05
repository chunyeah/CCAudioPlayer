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

#import "CCAudioPlayer.h"

@import AVFoundation;

typedef NS_ENUM(NSInteger, CCAudioPlayerPauseReason) {
    CCAudioPlayerPauseReasonNotPause = 0,
    CCAudioPlayerPauseReasonUserPause,
    CCAudioPlayerPauseReasonForcePause
};

@interface CCAudioPlayer ()
{
@private
    AVQueuePlayer *_player;
    AVPlayerItem *_playerItem;
    
    UIBackgroundTaskIdentifier _backgroundTaskId;
    UIBackgroundTaskIdentifier _removedTaskId;
    
    id _timeObserver;
    
    CCAudioPlayerPauseReason _pauseReason;
    
    BOOL _routeChangedWhilePlaying;
    BOOL _interruptedWhilePlaying;
    
    BOOL _alreadyBeginPlay;
    
    BOOL _seeking;
}

@property (nonatomic, strong) NSURL *url;

@property (nonatomic) NSTimeInterval duration;

@property (nonatomic) NSTimeInterval progress;

@property (nonatomic) CCAudioPlayerState playerState;

@property (nonatomic) CCAudioPlayerErrorCode errorCode;

@property (nonatomic, copy) void (^trackProgressBlock)(NSTimeInterval progress);

@property (nonatomic, copy) void (^trackPlayerStateBlock)(CCAudioPlayerState playerState);

@end

@implementation CCAudioPlayer

#pragma mark - Initialize & Life

- (instancetype)initWithContentsOfURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        NSParameterAssert(url);
        
        [self setupPlayBackAudioSession];
        
        self.url = url;
        
        self.playerState = CCAudioPlayerStateNone;
        
        [self setupNotifications];
        
        [self longTimeBufferAtBackground];
        
        [self initializePlayer];
    }
    return self;
}

+ (instancetype)audioPlayerWithContentsOfURL:(NSURL *)url
{
    return [[CCAudioPlayer alloc] initWithContentsOfURL:url];
}

- (void)dealloc
{
    CCLog(@"");
}

#pragma mark - Public

- (void)play
{
    if (_playerItem) {
        
        [_player play];
        
        if (self.playerState == CCAudioPlayerStateRunning || self.playerState == CCAudioPlayerStateNone) {
            self.playerState = CCAudioPlayerStateBuffering;
        } else if (self.playerState != CCAudioPlayerStateBuffering) {
            self.playerState = CCAudioPlayerStatePlaying;
        }
        
        _alreadyBeginPlay = YES;
        
        _pauseReason = CCAudioPlayerPauseReasonNotPause;
    }
}

- (void)pause
{
    if (_playerItem) {
        
        [_player pause];
        
        self.playerState = CCAudioPlayerStatePaused;
        
        _pauseReason = CCAudioPlayerPauseReasonUserPause;
    }
}

- (void)seekToTime:(NSTimeInterval)toTime
{
    if (_playerItem) {
        if (toTime < 0.0) {
            toTime = 0.0;
        }
        
        self.progress = toTime;
        
        _seeking = YES;
        
        typeof(self) __weak weakSelf = self;
        [_playerItem seekToTime:CMTimeMakeWithSeconds(toTime, 1.0) completionHandler:^(BOOL finished) {
            CCAudioPlayer *strongSelf = weakSelf;
            strongSelf->_seeking = NO;
        }];
        
        if (CMTimeGetSeconds(_playerItem.duration) < toTime) {
            [self play];
        }
    }
}

- (void)dispose
{
    [_player pause];
 
    [self clearTimeObserver];

    if (_playerItem) {
        [self cleanupPlayerItem:_playerItem];
        _playerItem = nil;
    }
    
    if (_player) {
        [_player removeObserver:self forKeyPath:@"status"];
        _player = nil;
    }
    
    [self longTimeBufferBackgroundCompleted];
    
    self.playerState = CCAudioPlayerStateDisposed;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.trackProgressBlock) {
        self.trackProgressBlock = nil;
    }
    
    if (self.trackPlayerStateBlock) {
        self.trackPlayerStateBlock = nil;
    }
}

- (NSTimeInterval)duration
{
    if (_playerItem) {
        NSArray *loadedRanges = _playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0) {
            CMTimeRange range = [loadedRanges[0] CMTimeRangeValue];
            return CMTimeGetSeconds((range.duration));
        } else {
            return 0.0f;
        }
    } else {
        return 0.0f;
    }
}

- (BOOL)isPlaying
{
    return (nil != _playerItem) ? (0.0 != _player.rate) : NO;
}

- (void)trackPlayerProgress:(void (^)(NSTimeInterval))progressHandler playerState:(void (^)(CCAudioPlayerState))playerStateHandler
{
    if (progressHandler) {
        self.trackProgressBlock = progressHandler;
    }
    if (playerStateHandler) {
        self.trackPlayerStateBlock = playerStateHandler;
    }
}

#pragma mark - Private

- (void)setPlayerState:(CCAudioPlayerState)playerState
{
    if (_playerState != playerState) {
        _playerState = playerState;
        
        if (self.trackPlayerStateBlock) {
            self.trackPlayerStateBlock(_playerState);
        }
    }
}

- (void)setProgress:(NSTimeInterval)progress
{
    _progress = progress;
    if (self.trackProgressBlock) {
        self.trackProgressBlock(_progress);
    }
}

- (void)initializePlayer
{
    _player = [[AVQueuePlayer alloc] init];
    [_player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self addItemToPlayer];
}

- (void)addItemToPlayer
{
    _playerItem = [self createPlayerItemWithUrl:self.url];
    if (_playerItem) {
        [_player insertItem:_playerItem afterItem:nil];
    }
}

- (void)setupNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)longTimeBufferAtBackground
{
    typeof(self) __weak weakSelf = self;
    _backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        CCAudioPlayer *strongSelf = weakSelf;
        [[UIApplication sharedApplication] endBackgroundTask:strongSelf->_removedTaskId];
        strongSelf->_backgroundTaskId = UIBackgroundTaskInvalid;
    }];
    
    if (_backgroundTaskId != UIBackgroundTaskInvalid && _removedTaskId == 0 ? YES : (_removedTaskId != UIBackgroundTaskInvalid)) {
        [[UIApplication sharedApplication] endBackgroundTask: _removedTaskId];
    }
    _removedTaskId = _backgroundTaskId;
}

- (void)longTimeBufferBackgroundCompleted
{
    if (_backgroundTaskId != UIBackgroundTaskInvalid && _removedTaskId != _backgroundTaskId) {
        [[UIApplication sharedApplication] endBackgroundTask: _backgroundTaskId];
        _removedTaskId = _backgroundTaskId;
    }
}

- (void)setErrorCode:(CCAudioPlayerErrorCode)errorCode
{
    _errorCode = errorCode;
    
    if (errorCode == CCAudioPlayerErrorNone) {
        CCLog(@"CCAudioPlayerErrorNone");
    } else if (errorCode == CCAudioPlayerErrorPlayerInitializeFailed) {
        CCLog(@"CCAudioPlayerErrorPlayerInitializeFailed");
    } else if (errorCode == CCAudioPlayerErrorBytesInitializeFailed) {
        CCLog(@"CCAudioPlayerErrorBytesInitializeFailed");
    } else if (errorCode == CCAudioPlayerErrorUnknow) {
        CCLog(@"CCAudioPlayerErrorUnknow");
    }
}

- (void)clearTimeObserver
{
    if (_timeObserver) {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

- (void)removeCurrentItem
{
    if (_playerItem) {
        [_player pause];
        
        _pauseReason = CCAudioPlayerPauseReasonForcePause;
        
        [self cleanupPlayerItem:_playerItem];
        
        _playerItem = nil;
    }
}

- (void)replayCurrentPlayItemToTime:(NSTimeInterval)seekTime
{
    [self removeCurrentItem];
    [self addItemToPlayer];
    [self seekToTime:seekTime];
}

#pragma mark - AVPlayerItem

- (AVPlayerItem *)createPlayerItemWithUrl:(NSURL *)url
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    if (item) {
        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemCompleted:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToComplete:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
    }
    return item;
}

- (void)cleanupPlayerItem:(AVPlayerItem *)item
{
    [self clearTimeObserver];
    
    [item removeObserver:self forKeyPath:@"status" context:NULL];
    
    [item removeObserver:self forKeyPath:@"loadedTimeRanges" context:NULL];
    
    [item removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:NULL];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
}

- (void)playerItemCompleted:(NSNotification *)notification
{
    self.playerState = CCAudioPlayerStateStopped;
}

- (void)playerItemFailedToComplete:(NSNotification *)notification
{
    self.playerState = CCAudioPlayerStateError;
    self.errorCode = CCAudioPlayerErrorUnknow;
}

#pragma mark - Interruption & Route changed

- (void)handleInterruptionNotification:(NSNotification *)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSUInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (interuptionType == AVAudioSessionInterruptionTypeBegan && _pauseReason != CCAudioPlayerPauseReasonForcePause && _pauseReason != CCAudioPlayerPauseReasonUserPause) {
        _interruptedWhilePlaying = YES;
        [self pause];
        _pauseReason = CCAudioPlayerPauseReasonForcePause;
    } else if (interuptionType == AVAudioSessionInterruptionTypeEnded && _interruptedWhilePlaying && _pauseReason != CCAudioPlayerPauseReasonForcePause && _pauseReason != CCAudioPlayerPauseReasonUserPause) {
        [self setupPlayBackAudioSession];
        _interruptedWhilePlaying = NO;
        [self play];
    }
}

- (void)handleRouteChangeNotification:(NSNotification *)notification
{
    NSDictionary *routeChangeDict = notification.userInfo;
    NSUInteger routeChangeType = [[routeChangeDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    if (routeChangeType == AVAudioSessionRouteChangeReasonOldDeviceUnavailable && _pauseReason != CCAudioPlayerPauseReasonForcePause && _pauseReason != CCAudioPlayerPauseReasonUserPause) {
        _routeChangedWhilePlaying = YES;
        [self pause];
        _pauseReason = CCAudioPlayerPauseReasonForcePause;
    } else if (routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable && _routeChangedWhilePlaying) {
        _routeChangedWhilePlaying = NO;
        [self play];
    }

}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _player && [keyPath isEqualToString:@"status"]) {
        NSNumber *changeKind = change[NSKeyValueChangeKindKey];
        if ([@(NSKeyValueChangeSetting) isEqual:changeKind]) {
            if (_player.status == AVPlayerStatusReadyToPlay) {
                self.playerState = CCAudioPlayerStateRunning;
            } else {
                self.playerState = CCAudioPlayerStateError;
                self.errorCode = CCAudioPlayerErrorPlayerInitializeFailed;
            }
        }
    } else if (object == _playerItem && [keyPath isEqualToString:@"status"]) {
        NSNumber *changeKind = [change objectForKey:NSKeyValueChangeKindKey];
        if ([@(NSKeyValueChangeSetting) isEqual:changeKind]) {
            
            NSUInteger playerItemIndex = [_player.items indexOfObject:_playerItem];
            AVPlayerItemStatus playerItemStatus = AVPlayerItemStatusUnknown;
            id updateStatus = [change objectForKey:NSKeyValueChangeNewKey];
            
            if (updateStatus) {
                playerItemStatus = [updateStatus integerValue];
            } else {
                if (playerItemIndex == NSNotFound) {
                    playerItemStatus = AVPlayerItemStatusFailed;
                } else {
                    playerItemStatus = _playerItem.status;
                }
            }
            
            if (playerItemStatus == AVPlayerItemStatusReadyToPlay) {
                self.playerState = CCAudioPlayerStateRunning;
                
                [self clearTimeObserver];
                
                typeof(self) __weak weakSelf = self;
                _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
                    CCAudioPlayer *strongSelf = weakSelf;
                    if (!strongSelf->_seeking) {
                        strongSelf.progress = CMTimeGetSeconds(time);
                    }
                }];
                
                if (self.isPlaying) {
                    self.playerState = CCAudioPlayerStatePlaying;
                }
            } else {
                self.playerState = CCAudioPlayerStateError;
                self.errorCode = CCAudioPlayerErrorBytesInitializeFailed;
            }
        }
    } else if (object == _playerItem && [keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && timeRanges.count > 0) {
            CMTimeRange timeRange = [timeRanges[0] CMTimeRangeValue];
            if (_player.rate == 0 && _pauseReason != CCAudioPlayerPauseReasonForcePause) {
                if (self.isPlaying) {
                    self.playerState = CCAudioPlayerStateBuffering;
                }
                [self longTimeBufferAtBackground];
                
                CMTime bufferedTime = CMTimeAdd(timeRange.start, timeRange.duration);
                CMTime milestone = CMTimeAdd(_player.currentTime, CMTimeMakeWithSeconds(2.0f, timeRange.duration.timescale));
                if (CMTIME_COMPARE_INLINE(bufferedTime , >, milestone) && _player.currentItem.status == AVPlayerItemStatusReadyToPlay && !_interruptedWhilePlaying && !_routeChangedWhilePlaying) {
                    if (_pauseReason == CCAudioPlayerPauseReasonForcePause) {
                        if (!self.isPlaying && _alreadyBeginPlay) {
                            [_player play];
                            self.playerState = CCAudioPlayerStatePlaying;
                            [self longTimeBufferBackgroundCompleted];
                        }
                    }
                }
            }
        }
    } else if (object == _playerItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if (!_playerItem.playbackLikelyToKeepUp) {
            if (_pauseReason == CCAudioPlayerPauseReasonForcePause) {
                NSTimeInterval currentTime = self.progress;
                [self replayCurrentPlayItemToTime:currentTime];
            }
        }
    }
}

#pragma mark - AudioSession Setup

- (void)setupPlayBackAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    if (audioSession.category != AVAudioSessionCategoryPlayback) {
        UIDevice *device = [UIDevice currentDevice];
        if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
            if (device.multitaskingSupported) {
                
                NSError *setCategoryError = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayback
                         withOptions:AVAudioSessionCategoryOptionAllowBluetooth
                               error:&setCategoryError];
                
                NSError *activationError = nil;
                [audioSession setActive:YES error:&activationError];
            }
        }
    }
}

@end

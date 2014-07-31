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

#import "DemoViewController.h"
#import "CCAudioPlayer.h"
#import "Track.h"

@interface DemoViewController ()
{
@private
    UILabel *_titleLabel;
    UILabel *_statusLabel;
    
    UIButton *_buttonPlayPause;
    UIButton *_buttonNext;

    UISlider *_progressSlider;

    CCAudioPlayer *_audioPlayer;
    
    NSArray *_tracks;
    NSUInteger _currentTrackIndex;
}

@end

@implementation DemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 64.0, CGRectGetWidth([self.view bounds]), 30.0)];
    [_titleLabel setFont:[UIFont systemFontOfSize:20.0]];
    [_titleLabel setTextColor:[UIColor blackColor]];
    [_titleLabel setTextAlignment:NSTextAlignmentCenter];
    [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.view addSubview:_titleLabel];
    
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, CGRectGetMaxY([_titleLabel frame]) + 10.0, CGRectGetWidth([self.view bounds]), 30.0)];
    [_statusLabel setFont:[UIFont systemFontOfSize:16.0]];
    [_statusLabel setTextColor:[UIColor colorWithWhite:0.4 alpha:1.0]];
    [_statusLabel setTextAlignment:NSTextAlignmentCenter];
    [_statusLabel setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.view addSubview:_statusLabel];
    
    _buttonPlayPause = [UIButton buttonWithType:UIButtonTypeSystem];
    [_buttonPlayPause setFrame:CGRectMake(80.0, CGRectGetMaxY([_statusLabel frame]) + 20.0, 60.0, 20.0)];
    [_buttonPlayPause setTitle:@"Play" forState:UIControlStateNormal];
    [_buttonPlayPause addTarget:self action:@selector(_actionPlayPause:) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:_buttonPlayPause];
    
    _buttonNext = [UIButton buttonWithType:UIButtonTypeSystem];
    [_buttonNext setFrame:CGRectMake(CGRectGetWidth([self.view bounds]) - 80.0 - 60.0, CGRectGetMinY([_buttonPlayPause frame]), 60.0, 20.0)];
    [_buttonNext setTitle:@"Next" forState:UIControlStateNormal];
    [_buttonNext addTarget:self action:@selector(_actionNext:) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:_buttonNext];
    
    _progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(20.0, CGRectGetMaxY([_buttonNext frame]) + 20.0, CGRectGetWidth([self.view bounds]) - 20.0 * 2.0, 40.0)];
    _progressSlider.continuous = NO;
    [_progressSlider addTarget:self action:@selector(_actionSliderProgress:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_progressSlider];
    
    _tracks = [Track remoteTracks];
    
    [self _resetStreamer];
}

#pragma mark - Private

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"progress"]) {
        [_progressSlider setValue:_audioPlayer.progress / _audioPlayer.duration animated:YES];
    } else {
        switch (_audioPlayer.playerState) {
            case CCAudioPlayerStatePlaying:
            {
                _statusLabel.text = @"Playing";
                [_buttonPlayPause setTitle:@"Pause" forState:UIControlStateNormal];
            }
                break;
            case CCAudioPlayerStateBuffering:
            {
                _statusLabel.text = @"Buffering";
            }
                break;
                
            case CCAudioPlayerStatePaused:
            {
                _statusLabel.text = @"Paused";
                [_buttonPlayPause setTitle:@"Play" forState:UIControlStateNormal];
            }
                break;
        
            case CCAudioPlayerStateStopped:
            {
                _statusLabel.text = @"Play to End";
                
                [self _actionNext:nil];
            }
                break;
            default:
                break;
        }
    }
}

- (void)_actionSliderProgress:(id)sender
{
    [_audioPlayer seekToTime:_audioPlayer.duration * _progressSlider.value];
}

- (void)_actionPlayPause:(id)sender
{
    if (_audioPlayer.isPlaying) {
        [_audioPlayer pause];
        [_buttonPlayPause setTitle:@"Play" forState:UIControlStateNormal];
    } else {
        [_audioPlayer play];
        [_buttonPlayPause setTitle:@"Pause" forState:UIControlStateNormal];
    }
}

- (void)_actionNext:(id)sender
{
    if (++_currentTrackIndex >= [_tracks count]) {
        _currentTrackIndex = 0;
    }
    
    [self _resetStreamer];
}

- (void)_resetStreamer
{
    if (_audioPlayer) {
        [_audioPlayer dispose];
        [_audioPlayer removeObserver:self forKeyPath:@"progress"];
        [_audioPlayer removeObserver:self forKeyPath:@"playerState"];
        _audioPlayer = nil;
    }
    
    [_progressSlider setValue:0.0 animated:NO];
    
    if (_tracks.count != 0) {
        Track *track = [_tracks objectAtIndex:_currentTrackIndex];
        NSString *title = [NSString stringWithFormat:@"%@ - %@", track.artist, track.title];
        [_titleLabel setText:title];
        
        _audioPlayer = [CCAudioPlayer audioPlayerWithContentsOfURL:track.audioFileURL];
        [_audioPlayer addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:NULL];
        [_audioPlayer addObserver:self forKeyPath:@"playerState" options:NSKeyValueObservingOptionNew context:NULL];
        [_audioPlayer play];
    } else {
        NSLog(@"No tracks available");
    }
}

@end

CCAudioPlayer
=============

* CCAudioPlayer support remote and local audio files, Sitting on top of AVPlayer.
* And It provides useful basic player functionalities.

### Features

* Supporting both local and remote media.
* Simple APIs.
* Handle Interruption and Route change.
* If player suspended bacause of buffering issue, auto-resume the playback when buffered size reached 2 secs.

### Manually install

* Download [CCAudioPlayer](https://github.com/yechunjun/CCAudioPlayer.git), drag _CCAudioPlayer.h_ and _CCAudioPlayer.m_ into your Xcode project and you are ready to go.

* XCode providing GUI checkbox to enable various background modes. Enable **Audio and AirPlay**, you can find this section from _Project -> Capabilities -> Background Modes_.

### How to Use

* A working demonstration is included inside example folder. You can get a simple music app.(Example uses [Douban.fm](http://www.douban.com) music apis to test.)

#### Setup
    NSURL *audioURL = [NSURL URLWithString:urlString]; // Support Local or remote
    CCAudioPlayer *audioPlayer = [CCAudioPlayer audioPlayerWithContentsOfURL:audioURL];

#### Player Status

    CCAudioPlayerStateRunning // Player and audio file get ready for playing
    CCAudioPlayerStateBuffering // Buffering the audio content
    CCAudioPlayerStatePlaying // Playing
    CCAudioPlayerStatePaused // Paused
    CCAudioPlayerStateStopped // Raised when an audio file has finished playing
    CCAudioPlayerStateError // Raised when an unexpected and possibly unrecoverable error has occured
    CCAudioPlayerStateDisposed // Audio player is disposed
    
    // Use KVO
    [audioPlayer addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:NULL];
    [audioPlayer addObserver:self forKeyPath:@"playerState" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Or Use Block API
    [audioPlayer trackPlayerProgress:^(NSTimeInterval progress) {
        NSLog(@"Player progress update.");
    } playerState:^(CCAudioPlayerState playerState) {
        NSLog(@"Player state update.");
    }];

#### Player Control
    [audioPlayer play];
    [audioPlayer pause];
    [audioPlayer seekToTime:1.0f];
    
### License
* All source code is licensed under the MIT License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum FileType { file, network, asset }

enum PlayerType { feed, full }

class FlutterVideoPlayer extends StatefulWidget {
  const FlutterVideoPlayer({
    Key key,
    this.fileType = FileType.network,
    this.playerType = PlayerType.feed,
    @required this.videoUrl,
    this.autoPlay = true,
    this.muteDefault = true,
    this.height = 200.0,
  }) : super(key: key);

  //file type for loading resource
  final FileType fileType;

  //player type
  //feed without controls only shows duration and mute button
  //full with controls
  final PlayerType playerType;

  //video url
  final String videoUrl;

  //auto play video on load
  final bool autoPlay;

  //mutes video by default
  final bool muteDefault;

  //height for video player, default 200.0
  final double height;

  static RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  _FlutterVideoPlayerState createState() => _FlutterVideoPlayerState();
}

class _FlutterVideoPlayerState extends State<FlutterVideoPlayer>
    with RouteAware, SingleTickerProviderStateMixin {
  VideoPlayerController _controller;
  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    switch (widget.fileType) {
      case FileType.asset:
        _controller = VideoPlayerController.asset(widget.videoUrl);
        break;
      case FileType.file:
        _controller = VideoPlayerController.file(File(widget.videoUrl));
        break;
      case FileType.network:
        _controller = VideoPlayerController.network(widget.videoUrl);
        break;
    }
    await _controller.initialize().then((value) {
      if (mounted) {
        setState(() {});
      }
    });
    _controller.addListener(() {
      if (!_controller.value.isPlaying &&
          _controller.value.position == _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
    });
  }

  @override
  void didUpdateWidget(FlutterVideoPlayer oldWidget) {
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    FlutterVideoPlayer.routeObserver.subscribe(this, ModalRoute.of(context));
    super.didChangeDependencies();
  }

  @override
  void didPopNext() {
    if (!_controller.value.isPlaying && widget.autoPlay) {
      _controller.play();
    } else {
      _controller.pause();
    }
    super.didPopNext();
  }

  @override
  void didPushNext() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    }
    super.didPushNext();
  }

  @override
  void dispose() {
    FlutterVideoPlayer.routeObserver.unsubscribe(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: MediaQuery.of(context).size.width,
      child: widget.playerType == PlayerType.feed
          ? _buildFeedPlayer()
          : _buildFullPlayer(),
    );
  }

  Widget _buildFeedPlayer() {
    if (_controller.value.initialized && widget.autoPlay) {
      _controller.play();
    }
    return _controller.value.initialized
        ? Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              Positioned(
                top: 10.0,
                right: 10.0,
                height: 25.0,
                child: DurationTimer(controller: _controller),
              ),
              Positioned(
                bottom: 10.0,
                right: 10.0,
                child: IconButton(
                  icon: _controller.value.volume == 0
                      ? Icon(Icons.volume_up)
                      : Icon(Icons.volume_off),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.volume == 0) {
                        _controller.setVolume(100.0);
                      } else {
                        _controller.setVolume(0.0);
                      }
                    });
                  },
                ),
              ),
            ],
          )
        : Center(
            child: CircularProgressIndicator(),
          );
  }

  _buildFullPlayer() {
    return _controller.value.initialized
        ? Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              Positioned(
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                height: 40.0,
                child: Container(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                        },
                        icon: _controller.value.isPlaying
                            ? Icon(Icons.pause)
                            : Icon(Icons.play_arrow),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                        ),
                      ),
                      IconButton(
                        icon: _controller.value.volume == 0
                            ? Icon(Icons.volume_up)
                            : Icon(Icons.volume_off),
                        onPressed: () {
                          setState(() {
                            if (_controller.value.volume == 0) {
                              _controller.setVolume(100.0);
                            } else {
                              _controller.setVolume(0.0);
                            }
                          });
                        },
                      )
                    ],
                  ),
                ),
              ),
            ],
          )
        : Center(
            child: CircularProgressIndicator(),
          );
  }
}

class DurationTimer extends StatefulWidget {
  final VideoPlayerController controller;

  const DurationTimer({Key key, @required this.controller}) : super(key: key);
  @override
  _DurationTimerState createState() => _DurationTimerState();
}

class _DurationTimerState extends State<DurationTimer>
    with TickerProviderStateMixin {
  AnimationController _animationController;

  @override
  void initState() {
    _initController();
    super.initState();
  }

  _initController() {
    _animationController = AnimationController(
      vsync: this,
      duration: widget.controller.value.duration,
    )..forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(4.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: _CountDown(
        animation: StepTween(
          begin: widget.controller.value.duration.inSeconds,
          end: 0,
        ).animate(_animationController),
      ),
    );
  }
}

class _CountDown extends AnimatedWidget {
  final Animation<int> animation;

  const _CountDown({
    Key key,
    @required this.animation,
  }) : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) {
    Duration clockTimer = Duration(seconds: animation.value);

    String timerText = '';
    if (clockTimer.inHours > 0) {
      timerText =
          '${clockTimer.inHours.remainder(60).toString().padLeft(2, '0')}:${clockTimer.inMinutes.remainder(60).toString()}:${(clockTimer.inSeconds.remainder(60) % 60).toString().padLeft(2, '0')}';
    } else {
      timerText =
          '${clockTimer.inMinutes.remainder(60).toString()}:${(clockTimer.inSeconds.remainder(60) % 60).toString().padLeft(2, '0')}';
    }
    return Center(
      child: Text(
        "$timerText",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
        ),
      ),
    );
  }
}

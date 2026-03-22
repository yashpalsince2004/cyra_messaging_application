import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/status/domain/status_model.dart';
import 'dart:async';

class StoryViewScreen extends StatefulWidget {
  final StatusModel status;

  const StoryViewScreen({super.key, required this.status});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _timer;
  double _percent = 0.0;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _progressController = AnimationController(vsync: this);
  }

  void _startTimer() {
    _percent = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _percent += 0.01; // 5 seconds per story (50ms * 100)
          if (_percent > 1) {
            _nextStory();
          }
        });
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.status.photoUrls.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startTimer();
    } else {
      _percent = 0.0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _previousStory();
            } else {
              _nextStory();
            }
          },
          onLongPressStart: (_) => _timer?.cancel(),
          onLongPressEnd: (_) => _startTimer(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Story Media
              CachedNetworkImage(
                imageUrl: widget.status.photoUrls[_currentIndex],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              
              // Top UI Layer (Bars + Profile)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    // Progress Bars
                    Row(
                      children: List.generate(
                        widget.status.photoUrls.length,
                        (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: LinearProgressIndicator(
                                value: _getProgressValue(index),
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // User Info
                    Row(
                      children: [
                        const BackButton(color: Colors.white),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            widget.status.username.isNotEmpty ? widget.status.username[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.status.username,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Reply Bar
              if (widget.status.uid != FirebaseAuth.instance.currentUser?.uid)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: _showReplySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Reply', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplySheet() {
    _timer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Reply to ${widget.status.username}...',
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      // Note: Requires creating a chat and sending a message.
                      // For this phase, we mock the send action.
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!')));
                    }
                    Navigator.pop(ctx);
                    _startTimer();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!')));
                  Navigator.pop(ctx);
                  _startTimer();
                },
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _startTimer());
  }

  double _getProgressValue(int index) {
    if (index < _currentIndex) {
      return 1.0;
    } else if (index == _currentIndex) {
      return _percent;
    } else {
      return 0.0;
    }
  }
}

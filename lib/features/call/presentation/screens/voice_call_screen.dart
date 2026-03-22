import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/call/data/call_repository.dart';
import 'package:cyra/features/call/domain/call_model.dart';
import 'package:cyra/core/services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String receiverId;
  final bool isIncoming;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.receiverId,
    this.isIncoming = false,
  });

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  CallStatus _callStatus = CallStatus.calling;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Request permissions
    final hasPermission = await _webrtcService.requestPermissions();
    if (!hasPermission) {
      _showError('Microphone permission required');
      Navigator.of(context).pop();
      return;
    }

    // Set up WebRTC callbacks
    _webrtcService.onLocalStream = (stream) {
      setState(() {});
    };

    _webrtcService.onRemoteStream = (stream) {
      setState(() {});
    };

    _webrtcService.onIceCandidate = (candidate) {
      _sendIceCandidate(candidate);
    };

    _webrtcService.onCallConnected = () {
      setState(() {
        _callStatus = CallStatus.connected;
      });
      _startCallTimer();
    };

    _webrtcService.onCallEnded = () {
      _endCall();
    };

    // Initialize peer connection
    await _webrtcService.initializePeerConnection();

    if (widget.isIncoming) {
      _handleIncomingCall();
    } else {
      _handleOutgoingCall();
    }
  }

  Future<void> _handleOutgoingCall() async {
    final callRepo = ref.read(callRepositoryProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Create call document
      final callId = await callRepo.createCall(
        callerId: currentUser.uid,
        receiverId: widget.receiverId,
      );

      // Create offer
      final offer = await _webrtcService.createOffer();
      if (offer != null) {
        await callRepo.setOffer(callId, offer);
      }

      // Listen for call updates
      callRepo.getCallStream(callId).listen((call) {
        if (call != null) {
          setState(() {
            _callStatus = call.status;
          });

          if (call.status == CallStatus.ended) {
            _endCall();
          } else if (call.answer != null &&
              call.status == CallStatus.connected) {
            _webrtcService.setRemoteDescription(call.answer!, 'answer');
          }

          // Handle ICE candidates
          if (call.iceCandidates != null) {
            for (var candidate in call.iceCandidates!) {
              _webrtcService.addIceCandidate(
                RTCIceCandidate(
                  candidate['candidate'],
                  candidate['sdpMid'],
                  candidate['sdpMLineIndex'],
                ),
              );
            }
          }
        }
      });
    } catch (e) {
      _showError('Failed to start call: $e');
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleIncomingCall() async {
    final callRepo = ref.read(callRepositoryProvider);

    // Update status to ringing
    await callRepo.updateCallStatus(widget.callId, CallStatus.ringing);

    // Listen for call updates
    callRepo.getCallStream(widget.callId).listen((call) {
      if (call != null) {
        setState(() {
          _callStatus = call.status;
        });

        if (call.status == CallStatus.ended) {
          _endCall();
        } else if (call.offer != null) {
          _webrtcService.setRemoteDescription(call.offer!, 'offer');
          _acceptCall();
        }

        // Handle ICE candidates
        if (call.iceCandidates != null) {
          for (var candidate in call.iceCandidates!) {
            _webrtcService.addIceCandidate(
              RTCIceCandidate(
                candidate['candidate'],
                candidate['sdpMid'],
                candidate['sdpMLineIndex'],
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _acceptCall() async {
    final callRepo = ref.read(callRepositoryProvider);

    try {
      // Create answer
      final answer = await _webrtcService.createAnswer();
      if (answer != null) {
        await callRepo.setAnswer(widget.callId, answer);
        await callRepo.updateCallStatus(widget.callId, CallStatus.connected);
      }
    } catch (e) {
      _showError('Failed to accept call: $e');
    }
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    final callRepo = ref.read(callRepositoryProvider);
    final candidateMap = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };

    try {
      await callRepo.addIceCandidate(widget.callId, candidateMap);
    } catch (e) {
      debugPrint('Error sending ICE candidate: $e');
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    _webrtcService.endCall();
    final callRepo = ref.read(callRepositoryProvider);
    callRepo.endCall(widget.callId);
    Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webrtcService.toggleMute(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _webrtcService.toggleSpeaker(_isSpeakerOn);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  Text(
                    widget.receiverId, // Replace with actual name
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Call status
                  Text(
                    _callStatus == CallStatus.connected
                        ? _formatDuration(_callDuration)
                        : _callStatus.name.toUpperCase(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: _toggleMute,
                    isActive: _isMuted,
                  ),

                  // Speaker button
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    onPressed: _toggleSpeaker,
                    isActive: _isSpeakerOn,
                  ),

                  // End call button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

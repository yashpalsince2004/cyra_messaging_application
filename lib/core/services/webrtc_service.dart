import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function()? onCallConnected;
  Function()? onCallEnded;

  // Configuration for STUN/TURN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      // Add TURN servers for production
    ],
  };

  Future<bool> requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    return microphoneStatus.isGranted;
  }

  Future<void> initializePeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    // Add local stream
    _localStream = await _getUserMedia();
    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
      onLocalStream?.call(_localStream!);
    }

    // Set up event listeners
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate);
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      onRemoteStream?.call(stream);
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallConnected?.call();
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onCallEnded?.call();
      }
    };
  }

  Future<MediaStream?> _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': false, // Voice call only
    };

    try {
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('Error getting user media: $e');
      return null;
    }
  }

  Future<String?> createOffer() async {
    if (_peerConnection == null) return null;

    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      return offer.sdp;
    } catch (e) {
      debugPrint('Error creating offer: $e');
      return null;
    }
  }

  Future<String?> createAnswer() async {
    if (_peerConnection == null) return null;

    try {
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      return answer.sdp;
    } catch (e) {
      debugPrint('Error creating answer: $e');
      return null;
    }
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    if (_peerConnection == null) return;

    try {
      RTCSessionDescription description = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      debugPrint('Error setting remote description: $e');
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) return;

    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('Error adding ICE candidate: $e');
    }
  }

  void toggleMute(bool mute) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !mute;
      });
    }
  }

  void toggleSpeaker(bool speaker) {
    // For mobile, this would switch between earpiece and speaker
    // Implementation depends on platform-specific code
  }

  Future<void> endCall() async {
    try {
      _localStream?.dispose();
      _remoteStream?.dispose();
      await _peerConnection?.close();
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
      onCallEnded?.call();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  void dispose() {
    endCall();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
import 'package:cyra/core/constants/api_constants.dart';

final aiServiceProvider = Provider((ref) => AiService());

/// Enhancement modes with tailored system prompts for Groq API.
enum EnhanceMode {
  enhance(
    label: 'Improve',
    icon: 'auto_awesome',
    systemPrompt: 'You improve grammar, clarity and tone while keeping the original meaning. Return only the improved sentence. Do not add quotes.',
  ),
  grammar(
    label: 'Grammar',
    icon: 'spellcheck',
    systemPrompt: 'Fix grammar and spelling errors only. Keep the meaning and tone identical. Return only the corrected sentence. Do not add quotes.',
  ),
  friendly(
    label: 'Friendly',
    icon: 'sentiment_satisfied',
    systemPrompt: 'Rewrite this message in a warm, casual, friendly tone. Keep the meaning. Return only the rewritten sentence. Do not add quotes.',
  ),
  professional(
    label: 'Professional',
    icon: 'work',
    systemPrompt: 'Rewrite this message in a formal, professional tone suitable for work communication. Return only the rewritten sentence. Do not add quotes.',
  );

  final String label;
  final String icon;
  final String systemPrompt;

  const EnhanceMode({
    required this.label,
    required this.icon,
    required this.systemPrompt,
  });
}

class AiService {
  final GoogleTranslator _translator = GoogleTranslator();

  // ─── Caches ───────────────────────────────────────────────
  final Map<String, String> _translationCache = {};
  final Map<String, String> _enhanceCache = {};

  // Prevent duplicate in-flight requests
  final Map<String, Future<String>> _pendingRequests = {};

  // ─── Language Codes ───────────────────────────────────────
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Hindi': 'hi',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
    'Chinese': 'zh-cn',
    'Arabic': 'ar',
  };

  // ═══════════════════════════════════════════════════════════
  //  TRANSLATION (Google Translate — free, no key)
  // ═══════════════════════════════════════════════════════════

  Future<String> translateMessage(String message, String language) async {
    if (message.trim().isEmpty) return message;

    final cacheKey = '${message}_$language';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      final langCode = languageCodes[language] ?? 'en';
      final translation = await _translator.translate(message, to: langCode);
      _translationCache[cacheKey] = translation.text;
      return translation.text;
    } catch (e) {
      debugPrint('Translation error: $e');
      return message;
    }
  }

  Future<List<String>> translateBatch(List<String> messages, String language) async {
    final langCode = languageCodes[language] ?? 'en';
    List<String> results = [];

    for (String msg in messages) {
      if (msg.trim().isEmpty) {
        results.add(msg);
        continue;
      }

      final cacheKey = '${msg}_$language';
      if (_translationCache.containsKey(cacheKey)) {
        results.add(_translationCache[cacheKey]!);
        continue;
      }

      try {
        final translation = await _translator.translate(msg, to: langCode);
        _translationCache[cacheKey] = translation.text;
        results.add(translation.text);
      } catch (e) {
        debugPrint('Batch translation error for "$msg": $e');
        results.add(msg);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════
  //  AI TEXT ENHANCEMENT (Groq API — llama-3.1-8b-instant)
  // ═══════════════════════════════════════════════════════════

  /// Enhances text using Groq API with the specified mode.
  /// Includes caching and duplicate-request prevention.
  Future<String> enhanceText(String input, {EnhanceMode mode = EnhanceMode.enhance}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;

    // Check cache
    final cacheKey = '${mode.name}_$trimmed';
    if (_enhanceCache.containsKey(cacheKey)) {
      return _enhanceCache[cacheKey]!;
    }

    // Prevent duplicate in-flight requests
    if (_pendingRequests.containsKey(cacheKey)) {
      return _pendingRequests[cacheKey]!;
    }

    final future = _callGroqApi(trimmed, mode);
    _pendingRequests[cacheKey] = future;

    try {
      final result = await future;
      _enhanceCache[cacheKey] = result;
      return result;
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  /// Backward-compatible — used by existing code
  Future<String> enhanceMessage(String message) async {
    return enhanceText(message, mode: EnhanceMode.enhance);
  }

  /// Makes the actual HTTP call to Groq API.
  Future<String> _callGroqApi(String userMessage, EnhanceMode mode) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groqEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConstants.groqApiKey}',
        },
        body: jsonEncode({
          'model': ApiConstants.groqModel,
          'temperature': 0.3,
          'max_tokens': 60,
          'messages': [
            {
              'role': 'system',
              'content': mode.systemPrompt,
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
        return userMessage; // Fallback to original
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit reached. Please wait a moment and try again.');
      } else {
        debugPrint('Groq API error ${response.statusCode}: ${response.body}');
        throw Exception('AI service error (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Check your internet connection.');
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Groq API error: $e');
      throw Exception('Failed to connect to AI service.');
    }
  }
}

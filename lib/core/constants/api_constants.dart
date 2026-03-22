/// Groq API configuration constants.
/// 
/// ⚠️  SECURITY NOTE: In production, move the API key to a backend
/// service (Firebase Cloud Functions) to avoid exposing it in the app.
/// See: https://firebase.google.com/docs/functions
class ApiConstants {
  ApiConstants._();

  /// Your Groq API key — get one free at https://console.groq.com
  /// Replace the placeholder below with your actual key (starts with gsk_...)
  static const String groqApiKey = 'YOUR_API_KEY_HERE';

  /// Groq chat completions endpoint (OpenAI-compatible)
  static const String groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// Model optimized for fast inference
  static const String groqModel = 'llama-3.1-8b-instant';
}

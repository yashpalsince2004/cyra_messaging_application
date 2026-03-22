import 'package:flutter/material.dart';
import 'package:cyra/core/services/ai_service.dart';

/// Bottom sheet that shows AI enhancement mode options.
/// Returns the enhanced text string when a mode completes,
/// or null if the user cancels.
class AiEnhanceSheet extends StatefulWidget {
  final String originalText;
  final AiService aiService;

  const AiEnhanceSheet({
    super.key,
    required this.originalText,
    required this.aiService,
  });

  @override
  State<AiEnhanceSheet> createState() => _AiEnhanceSheetState();
}

class _AiEnhanceSheetState extends State<AiEnhanceSheet> {
  EnhanceMode? _activeMode;
  String? _errorMessage;

  Future<void> _onModeTapped(EnhanceMode mode) async {
    setState(() {
      _activeMode = mode;
      _errorMessage = null;
    });

    try {
      final result = await widget.aiService.enhanceText(
        widget.originalText,
        mode: mode,
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeMode = null;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI Enhance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose how to improve your message',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Enhancement mode buttons — 2x2 grid
            Row(
              children: [
                _buildModeCard(context, EnhanceMode.enhance, Icons.auto_awesome, const Color(0xFF7C4DFF)),
                const SizedBox(width: 10),
                _buildModeCard(context, EnhanceMode.grammar, Icons.spellcheck, const Color(0xFF00BFA5)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildModeCard(context, EnhanceMode.friendly, Icons.sentiment_satisfied_alt, const Color(0xFFFF6D00)),
                const SizedBox(width: 10),
                _buildModeCard(context, EnhanceMode.professional, Icons.work_outline, const Color(0xFF2979FF)),
              ],
            ),

            const SizedBox(height: 12),

            // Preview of original text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your message:', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(
                    widget.originalText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
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

  Widget _buildModeCard(BuildContext context, EnhanceMode mode, IconData icon, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = _activeMode == mode;
    final isDisabled = _activeMode != null && _activeMode != mode;

    return Expanded(
      child: GestureDetector(
        onTap: (isLoading || isDisabled) ? null : () => _onModeTapped(mode),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isLoading
                  ? accentColor.withAlpha(30)
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLoading ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: isLoading ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  )
                else
                  Icon(icon, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLoading ? 'Working...' : mode.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

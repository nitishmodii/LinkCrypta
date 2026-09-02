import 'package:flutter/material.dart';

class LinkEmptyState extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback? onAddPressed;

  const LinkEmptyState({
    super.key,
    required this.isDarkMode,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                    : const Color(0xFF3B82F6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.link_off,
                size: 60,
                color: isDarkMode 
                    ? const Color(0xFF3B82F6).withOpacity(0.7)
                    : const Color(0xFF3B82F6).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Links Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start building your link collection by adding your first link. '
              'Keep all your important URLs organized in one place.',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? const Color(0xFF1E293B).withOpacity(0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: isDarkMode 
                    ? Border.all(color: const Color(0xFF334155))
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('📁', 'Organize with categories'),
                  _buildTip('⭐', 'Mark favorites for quick access'),
                  _buildTip('🔗', 'Add descriptions for better organization'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

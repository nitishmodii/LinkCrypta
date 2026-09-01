import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/password_entry.dart';
import 'encryption_service.dart';

enum PasswordStrength { veryWeak, weak, fair, good, strong, veryStrong }

class PasswordHealthReport {
  final int totalPasswords;
  final int weakPasswords;
  final int duplicatePasswords;
  final int compromisedPasswords;
  final int expiredPasswords;
  final double overallScore;
  final List<PasswordAnalysis> passwordAnalyses;

  PasswordHealthReport({
    required this.totalPasswords,
    required this.weakPasswords,
    required this.duplicatePasswords,
    required this.compromisedPasswords,
    required this.expiredPasswords,
    required this.overallScore,
    required this.passwordAnalyses,
  });
}

class PasswordAnalysis {
  final PasswordEntry entry;
  final PasswordStrength strength;
  final int strengthScore;
  final bool isDuplicate;
  final bool isCompromised;
  final bool isExpired;
  final int ageInDays;
  final List<String> issues;
  final List<String> suggestions;

  PasswordAnalysis({
    required this.entry,
    required this.strength,
    required this.strengthScore,
    required this.isDuplicate,
    required this.isCompromised,
    required this.isExpired,
    required this.ageInDays,
    required this.issues,
    required this.suggestions,
  });
}

class PasswordHealthService {
  static const int _passwordExpiryDays = 90;
  static const String _hibpApiUrl = 'https://api.pwnedpasswords.com/range/';

  /// Analyzes all passwords and generates a comprehensive health report
  static Future<PasswordHealthReport> analyzePasswords(List<PasswordEntry> entries) async {
    final List<PasswordAnalysis> analyses = [];
    final Map<String, List<PasswordEntry>> passwordGroups = {};
    
    // Decrypt and group passwords for duplicate detection
    for (final entry in entries) {
      try {
        final decryptedPassword = EncryptionService.decryptString(entry.password);
        if (passwordGroups.containsKey(decryptedPassword)) {
          passwordGroups[decryptedPassword]!.add(entry);
        } else {
          passwordGroups[decryptedPassword] = [entry];
        }
      } catch (e) {
        // Skip entries that can't be decrypted
        continue;
      }
    }

    // Analyze each password
    for (final entry in entries) {
      try {
        final decryptedPassword = EncryptionService.decryptString(entry.password);
        final analysis = await _analyzePassword(entry, decryptedPassword, passwordGroups);
        analyses.add(analysis);
      } catch (e) {
        // Create a basic analysis for passwords that can't be decrypted
        analyses.add(PasswordAnalysis(
          entry: entry,
          strength: PasswordStrength.veryWeak,
          strengthScore: 0,
          isDuplicate: false,
          isCompromised: false,
          isExpired: _isPasswordExpired(entry),
          ageInDays: _getPasswordAge(entry),
          issues: ['Cannot decrypt password'],
          suggestions: ['Update password encryption'],
        ));
      }
    }

    // Calculate overall statistics
    final weakCount = analyses.where((a) => a.strengthScore < 60).length;
    final duplicateCount = analyses.where((a) => a.isDuplicate).length;
    final compromisedCount = analyses.where((a) => a.isCompromised).length;
    final expiredCount = analyses.where((a) => a.isExpired).length;
    
    final overallScore = _calculateOverallScore(analyses);

    return PasswordHealthReport(
      totalPasswords: entries.length,
      weakPasswords: weakCount,
      duplicatePasswords: duplicateCount,
      compromisedPasswords: compromisedCount,
      expiredPasswords: expiredCount,
      overallScore: overallScore,
      passwordAnalyses: analyses,
    );
  }

  /// Analyzes a single password
  static Future<PasswordAnalysis> _analyzePassword(
    PasswordEntry entry,
    String password,
    Map<String, List<PasswordEntry>> passwordGroups,
  ) async {
    final strengthScore = calculatePasswordStrength(password);
    final strength = _getStrengthLevel(strengthScore);
    final isDuplicate = passwordGroups[password]!.length > 1;
    final isCompromised = await _checkPasswordCompromised(password);
    final isExpired = _isPasswordExpired(entry);
    final ageInDays = _getPasswordAge(entry);
    
    final issues = <String>[];
    final suggestions = <String>[];

    // Identify issues and suggestions
    if (strengthScore < 30) {
      issues.add('Very weak password');
      suggestions.add('Use a longer password with mixed characters');
    } else if (strengthScore < 60) {
      issues.add('Weak password');
      suggestions.add('Add more complexity with symbols and numbers');
    }

    if (isDuplicate) {
      issues.add('Password is reused');
      suggestions.add('Use unique passwords for each account');
    }

    if (isCompromised) {
      issues.add('Password found in data breaches');
      suggestions.add('Change password immediately');
    }

    if (isExpired) {
      issues.add('Password is older than $_passwordExpiryDays days');
      suggestions.add('Consider updating password regularly');
    }

    if (password.length < 8) {
      issues.add('Password too short');
      suggestions.add('Use at least 12 characters');
    }

    return PasswordAnalysis(
      entry: entry,
      strength: strength,
      strengthScore: strengthScore,
      isDuplicate: isDuplicate,
      isCompromised: isCompromised,
      isExpired: isExpired,
      ageInDays: ageInDays,
      issues: issues,
      suggestions: suggestions,
    );
  }

  /// Calculates password strength score (0-100)
  static int calculatePasswordStrength(String password) {
    int score = 0;
    
    // Length scoring
    if (password.length >= 8) score += 25;
    if (password.length >= 12) score += 25;
    if (password.length >= 16) score += 10;
    
    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 10;
    
    // Penalty for common patterns
    if (password.toLowerCase().contains('password')) score -= 20;
    if (password.toLowerCase().contains('123456')) score -= 20;
    if (password.toLowerCase().contains('qwerty')) score -= 20;
    
    // Bonus for entropy
    final entropy = _calculateEntropy(password);
    if (entropy > 50) score += 10;
    
    return score.clamp(0, 100);
  }

  /// Calculates password entropy
  static double _calculateEntropy(String password) {
    final charFreq = <String, int>{};
    for (int i = 0; i < password.length; i++) {
      final char = password[i];
      charFreq[char] = (charFreq[char] ?? 0) + 1;
    }
    
    double entropy = 0;
    for (final freq in charFreq.values) {
      final probability = freq / password.length;
      entropy -= probability * (log(probability) / log(2));
    }
    
    return entropy * password.length;
  }

  /// Converts strength score to level
  static PasswordStrength _getStrengthLevel(int score) {
    if (score >= 90) return PasswordStrength.veryStrong;
    if (score >= 75) return PasswordStrength.strong;
    if (score >= 60) return PasswordStrength.good;
    if (score >= 40) return PasswordStrength.fair;
    if (score >= 20) return PasswordStrength.weak;
    return PasswordStrength.veryWeak;
  }

  /// Checks if password has been compromised using HaveIBeenPwned API
  static Future<bool> _checkPasswordCompromised(String password) async {
    try {
      // Hash the password with SHA-1
      final bytes = utf8.encode(password);
      final digest = sha1.convert(bytes);
      final hash = digest.toString().toUpperCase();
      
      // Use k-anonymity: send only first 5 characters
      final prefix = hash.substring(0, 5);
      final suffix = hash.substring(5);
      
      final response = await http.get(Uri.parse('$_hibpApiUrl$prefix'));
      
      if (response.statusCode == 200) {
        // Check if our suffix appears in the response
        return response.body.contains(suffix);
      }
      
      return false; // Assume safe if API call fails
    } catch (e) {
      return false; // Assume safe if check fails
    }
  }

  /// Checks if password is expired
  static bool _isPasswordExpired(PasswordEntry entry) {
    final now = DateTime.now();
    final daysSinceUpdate = now.difference(entry.updatedAt).inDays;
    return daysSinceUpdate > _passwordExpiryDays;
  }

  /// Gets password age in days
  static int _getPasswordAge(PasswordEntry entry) {
    final now = DateTime.now();
    return now.difference(entry.updatedAt).inDays;
  }

  /// Calculates overall security score
  static double _calculateOverallScore(List<PasswordAnalysis> analyses) {
    if (analyses.isEmpty) return 0.0;
    
    double totalScore = 0;
    for (final analysis in analyses) {
      double passwordScore = analysis.strengthScore.toDouble();
      
      // Apply penalties
      if (analysis.isDuplicate) passwordScore *= 0.7;
      if (analysis.isCompromised) passwordScore *= 0.3;
      if (analysis.isExpired) passwordScore *= 0.9;
      
      totalScore += passwordScore;
    }
    
    return (totalScore / analyses.length).clamp(0.0, 100.0);
  }

  /// Gets strength color for UI
  static String getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return '#FF0000';
      case PasswordStrength.weak:
        return '#FF6600';
      case PasswordStrength.fair:
        return '#FFAA00';
      case PasswordStrength.good:
        return '#AAFF00';
      case PasswordStrength.strong:
        return '#66FF00';
      case PasswordStrength.veryStrong:
        return '#00FF00';
    }
  }

  /// Gets strength description
  static String getStrengthDescription(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 'Very Weak';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }
}

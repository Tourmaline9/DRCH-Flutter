import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

class AiVerificationService {

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == 'yes' || v == '1';
    }
    return false;
  }

  // TODO: Move API key to secure server/env before production release.
  static const String _apiKey = 'AIzaSyCpVlCjRhyOnaVmnH2MybRzjvI_yuS1OY0';

  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
  );

  Future<Map<String, dynamic>> verifyReport({
    required Uint8List imageBytes,
    required String description,
    required String selectedType,
  }) async {
    final prompt = '''
You are an AI disaster verification system.

Analyze the uploaded image and report description.
You must determine if this report should be FLAGGED as potentially fake/misleading.

User selected type: "$selectedType"
User description: "$description"

Important checks:
1) Does the image show a real disaster scene matching the description/type?
2) Is the image likely a screenshot/repost (phone screenshot, social media post, TV/news screen, or monitor capture)?
3) Is there any visual mismatch, editing/manipulation signs, or context inconsistency?

Return ONLY valid JSON. No markdown. No extra text.

JSON format:
{
  "is_disaster": true,
  "confidence": 0.0,
  "ai_summary": "short visual summary",
  "match_score": 1,
  "alert_type": "Fire",
  "is_flagged": false,
  "flag_reason": "short reason why flagged or why not flagged",
  "explanation": "2-3 short sentences explaining the decision",
  "possible_screenshot": false,
  "mismatch_points": ["point 1", "point 2"]
}
''';

    try {
      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ])
      ];

      final response = await _model.generateContent(content);
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty AI response');
      }

      final raw = response.text!.trim();
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Invalid JSON format from AI');
      }

      final jsonString = raw.substring(jsonStart, jsonEnd + 1);
      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      final mismatchPoints = (parsed['mismatch_points'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          <String>[];

      return {
        'is_disaster': _asBool(parsed['is_disaster']),
        'confidence': (parsed['confidence'] ?? 0).toDouble(),
        'ai_summary': parsed['ai_summary'] ?? 'No summary provided',
        'match_score': (parsed['match_score'] ?? 0).toInt(),
        'alert_type': parsed['alert_type'] ?? 'Unknown',
        'is_flagged': _asBool(parsed['is_flagged']),
        'flag_reason': parsed['flag_reason'] ?? 'No specific flag reason provided.',
        'explanation': parsed['explanation'] ?? 'No detailed explanation provided.',
        'possible_screenshot': _asBool(parsed['possible_screenshot']),
        'mismatch_points': mismatchPoints,
      };
    } catch (e) {
      print('🔥 GEMINI ERROR: $e');
      rethrow;
    }
  }
}

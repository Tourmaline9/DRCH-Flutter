import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiVerificationService {

  // 🔥 Put your restricted API key here
  static const String _apiKey = "AIzaSyCpVlCjRhyOnaVmnH2MybRzjvI_yuS1OY0";

  final GenerativeModel _model = GenerativeModel(
  model: 'gemini-2.5-flash', // stable multimodal model
  apiKey: _apiKey,
  );

  Future<Map<String, dynamic>> verifyReport({
  required Uint8List imageBytes,
  required String description,
  required String selectedType,
  }) async {

  final prompt = """
You are an AI disaster verification system.

Analyze the image and description.

User selected type: "$selectedType"
User description: "$description"

Return ONLY valid JSON. No markdown. No explanation.

JSON format:

{
  "is_disaster": true,
  "confidence": 0.0,
  "ai_summary": "short visual summary",
  "match_score": 1,
  "alert_type": "Fire"
}
""";

  try {

  final content = [
  Content.multi([
  DataPart('image/jpeg', imageBytes),
  TextPart(prompt),
  ])
  ];

  final response = await _model.generateContent(content);

  if (response.text == null || response.text!.isEmpty) {
  throw Exception("Empty AI response");
  }

  final raw = response.text!.trim();

  // 🔥 Extract JSON safely
  final jsonStart = raw.indexOf('{');
  final jsonEnd = raw.lastIndexOf('}');

  if (jsonStart == -1 || jsonEnd == -1) {
  throw Exception("Invalid JSON format from AI");
  }

  final jsonString =
  raw.substring(jsonStart, jsonEnd + 1);

  final Map<String, dynamic> parsed =
  jsonDecode(jsonString);

  return {
  "is_disaster": parsed["is_disaster"] ?? false,
  "confidence":
  (parsed["confidence"] ?? 0).toDouble(),
  "ai_summary":
  parsed["ai_summary"] ?? "No summary provided",
  "match_score":
  (parsed["match_score"] ?? 0).toInt(),
  "alert_type":
  parsed["alert_type"] ?? "Unknown",
  };

  } catch (e) {

    print("🔥 GEMINI ERROR: $e");
    rethrow;   // temporarily rethrow to see real error


  }
  }
  }

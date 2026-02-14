import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  final String apiKey = "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";

  // ================= IMAGE ANALYSIS =================

  Future<Map<String, dynamic>> analyzeImage(Uint8List imageBytes) async {
    final response = await http.post(
      Uri.parse(
          "https://api-inference.huggingface.co/models/google/vit-base-patch16-224"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/octet-stream",
      },
      body: imageBytes,
    );

    if (response.statusCode != 200) {
      throw Exception("Image AI failed");
    }

    final result = jsonDecode(response.body);

    final topPrediction = result[0];

    return {
      "label": topPrediction["label"],
      "confidence": topPrediction["score"],
    };
  }

  // ================= TEXT ANALYSIS =================

  Future<double> analyzeText(String description) async {
    final response = await http.post(
      Uri.parse(
          "https://api-inference.huggingface.co/models/facebook/bart-large-mnli"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "inputs": description,
        "parameters": {
          "candidate_labels": [
            "fire",
            "flood",
            "accident",
            "earthquake",
            "explosion"
          ]
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Text AI failed");
    }

    final result = jsonDecode(response.body);

    return result["scores"][0]; // top confidence
  }
}

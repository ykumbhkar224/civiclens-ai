import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiConfig {
  static String get apiKey => dotenv.env['GEMINI_API_KEY']!;

  // Primary model for text analysis, classification, and civic content
  static GenerativeModel get flashModel => GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.7,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 2048,
    ),
    safetySettings: _safetySetting,
  );

  // Vision model for image-based report analysis
  static GenerativeModel get visionModel => GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.4,
      topK: 32,
      topP: 0.95,
      maxOutputTokens: 1024,
    ),
    safetySettings: _safetySetting,
  );

  // Pro model for complex civic analysis and policy summaries
  static GenerativeModel get proModel => GenerativeModel(
    model: 'gemini-2.5-pro',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.5,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 4096,
    ),
    safetySettings: _safetySetting,
  );

  static List<SafetySetting> get _safetySetting => [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.mediumAndAbove),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.mediumAndAbove),
    SafetySetting(
      HarmCategory.sexuallyExplicit,
      HarmBlockThreshold.mediumAndAbove,
    ),
    SafetySetting(
      HarmCategory.dangerousContent,
      HarmBlockThreshold.mediumAndAbove,
    ),
  ];
}

import 'ai_service_base.dart';

/// Image analysis service powered by AIService.
class ImageAnalyzer {
  final AIService ai;

  ImageAnalyzer(this.ai);

  /// Analyze image content and generate description and tags.
  Future<ImageAnalysis> analyzeImage(String imagePath) => ai.analyzeImage(imagePath);

  /// Detect objects in the provided image.
  Future<List<DetectedObject>> detectObjects(String imagePath) => ai.detectObjects(imagePath);

  /// Verify image quality for form submission.
  Future<QualityCheck> checkImageQuality(String imagePath) => ai.checkImageQuality(imagePath);
}

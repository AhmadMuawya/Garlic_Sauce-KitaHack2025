// lib/models/analysis_result_model.dart

class AnalysisResult {
  final bool isSuccess; // Was the overall process successful?
  final String? prediction; // The identified issue (or status message)
  final double? confidence; // Optional: Confidence score (0.0 to 1.0)
  final String? advise; // Actionable tips or advice
  final String? errorMessage; // Error message if isSuccess is false
  final String? imageUrl; // Optional: Include URL if generated/needed

  const AnalysisResult({
    required this.isSuccess,
    this.prediction,
    this.confidence,
    this.advise,
    this.errorMessage,
    this.imageUrl, // Added imageUrl
  });

  // Factory constructor for error
  factory AnalysisResult.error(String message) {
    return AnalysisResult(
      isSuccess: false,
      errorMessage: message,
    );
  }

  // Factory constructor for success
  // Adapt parameters as needed for different success scenarios
  factory AnalysisResult.success({
    String? prediction,
    double? confidence,
    String? advise,
    String? imageUrl,
  }) {
    return AnalysisResult(
      isSuccess: true,
      prediction: prediction ?? "Operation successful.", // Default message
      confidence: confidence,
      advise: advise,
      imageUrl: imageUrl,
      errorMessage: null,
    );
  }
}

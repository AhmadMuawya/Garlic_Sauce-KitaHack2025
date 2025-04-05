// lib/constants/api_constants.dart

class ApiConstants {
  // --- Base URLs ---
  // Replace with your actual backend base URLs
  static const String storageApiBaseUrl =
      "https://your-storage-api-base-url.com"; // e.g., Firebase Storage REST API endpoint or your custom backend
  static const String analysisApiBaseUrl = "https://your-analysis-ai-api.com";

  // --- Endpoints ---
  // Replace with your specific API endpoint paths
  static const String uploadImageEndpoint =
      "/upload"; // Example endpoint for image upload
  static const String analyzeEndpoint =
      "/analyze"; // Example endpoint for analysis

  // --- API Keys / Auth Tokens (Placeholder) ---
  // !! IMPORTANT: Do NOT hardcode sensitive keys directly in source code for production.
  // Use environment variables, secure storage, or a configuration service.
  // These are placeholders for demonstration.
  static const String placeholderStorageApiKey =
      "YOUR_STORAGE_API_KEY_IF_NEEDED";
  static const String placeholderAnalysisApiKey =
      "YOUR_ANALYSIS_API_KEY_IF_NEEDED";
  static const String placeholderAuthToken = "Bearer YOUR_AUTH_TOKEN_IF_NEEDED";
}

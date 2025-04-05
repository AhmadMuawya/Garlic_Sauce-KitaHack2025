// lib/services/firebase_service.dart

import 'dart:convert'; // For jsonEncode/Decode
import 'dart:io';
import 'package:agri_ai_assistant/models/analysis_result_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
// No cloud_functions import needed
import 'package:http/http.dart' as http; // Use http package

class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- _uploadImage function (Stays the same, uses Firebase Storage SDK) ---
  Future<
      ({
        bool isSuccess,
        String? imageUrl,
        String? errorMessage,
        String? storagePath
      })> _uploadImage(String cropId, File imageFile) async {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileExtension = imageFile.path.split('.').last;
    final String fileName = '$timestamp.$fileExtension';
    // Consistent path based on previous code
    final String storagePath =
        'images/$cropId/$fileName'; // Changed from 'images/'
    final Reference storageRef = _storage.ref().child(storagePath);
    print("FirebaseService: Attempting to upload to: $storagePath");
    try {
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg', // Adjust as needed
        customMetadata: <String, String>{
          'cropId': cropId,
          'uploadedAt': timestamp
        },
      );
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print("FirebaseService: Upload successful. URL: $downloadUrl");
      // Also return the storagePath, as the function might need it
      return (
        isSuccess: true,
        imageUrl: downloadUrl,
        errorMessage: null,
        storagePath: storagePath
      );
    } on FirebaseException catch (e) {
      print(
          "FirebaseService: Upload failed - Code: ${e.code}, Message: ${e.message}");
      return (
        isSuccess: false,
        imageUrl: null,
        errorMessage: 'Storage Error: ${e.message ?? e.code}',
        storagePath: null
      );
    } catch (e) {
      print("FirebaseService: Upload failed - Unexpected: $e");
      return (
        isSuccess: false,
        imageUrl: null,
        errorMessage: 'Unexpected upload error: $e',
        storagePath: null
      );
    }
  }

  // --- MODIFIED: Calls the 'diagoniseCrop' onRequest Function using HTTP --- http: ^1.1.0
  Future<AnalysisResult> _fetchAnalysisViaHttp(
      String cropType, String? imageUrl, String? imagePath) async {
    // --- Use the EXACT Cloud Run URL provided ---
    final Uri functionUri = Uri.parse(
        "https://diagonisecrop-f6hm6f2zoq-uc.a.run.app"); // <-- USE THIS URL

    print("FirebaseService: Calling Cloud Run URL: $functionUri");
    print(
        "FirebaseService: Payload - cropType: $cropType, imageUrl: $imageUrl, imagePath: $imagePath");

    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      // If your Cloud Run service requires authentication (e.g., IAM Invoker role, ID token):
      // You might need to fetch an ID token and add it as a Bearer token here.
      // 'Authorization': 'Bearer YOUR_ID_TOKEN',
    };

    final Map<String, dynamic> body = {
      'cropType': cropType,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      // 'userId': 'some_flutter_user_id' // Add if needed
    };

    try {
      final http.Response response = await http.post(
        functionUri,
        headers: headers,
        body: jsonEncode(body),
      );

      print("FirebaseService: Cloud Run Status Code: ${response.statusCode}");
      print("FirebaseService: Cloud Run Response Body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return AnalysisResult.success(
            prediction: data['prediction'] as String?,
            confidence: (data['confidence'] as num?)?.toDouble(),
            advise: data['advice'] as String?,
            imageUrl: imageUrl,
          );
        } catch (e) {
          print("FirebaseService: Failed to parse Cloud Run response: $e");
          return AnalysisResult.error(
              "Failed to parse analysis response: ${response.body}");
        }
      } else {
        // Handle non-200 (e.g., 404 if URL path wrong, 403 Forbidden, 500 Internal Server Error)
        return AnalysisResult.error(
            "Analysis request failed (Status ${response.statusCode}): ${response.body}");
      }
    } on SocketException catch (e) {
      print("FirebaseService: Network error calling Cloud Run: $e");
      return AnalysisResult.error(
          "Network Error: Could not connect to analysis service.");
    } on http.ClientException catch (e) {
      print("FirebaseService: HTTP Client error calling Cloud Run: $e");
      return AnalysisResult.error(
          "Connection Error: Failed to call analysis service.");
    } catch (e) {
      print("FirebaseService: Unexpected error calling Cloud Run: $e");
      return AnalysisResult.error(
          "An unexpected error occurred during analysis: $e");
    }
  }

  // --- Public Method: getAnalysis (Stays the same) ---
  Future<AnalysisResult> getAnalysis(String? cropId, File? imageFile) async {
    // ... (no changes needed here, it calls the updated _fetchAnalysisViaHttp) ...
    if (cropId == null || cropId.isEmpty) {
      return AnalysisResult.error("Crop ID is missing.");
    }
    String? imageUrl;
    String? storagePathForFunction;
    if (imageFile != null) {
      print("FirebaseService: Image file provided, attempting upload...");
      final uploadResult = await _uploadImage(cropId, imageFile);
      if (!uploadResult.isSuccess) {
        return AnalysisResult.error(
            "Image upload failed: ${uploadResult.errorMessage ?? 'Unknown reason'}");
      }
      imageUrl = uploadResult.imageUrl;
      storagePathForFunction = uploadResult.storagePath;
      print(
          "FirebaseService: Image uploaded successfully, proceeding to analysis.");
    } else {
      print(
          "FirebaseService: No image file provided, proceeding to analysis without image.");
    }
    return await _fetchAnalysisViaHttp(
        cropId, imageUrl, storagePathForFunction);
  }
}

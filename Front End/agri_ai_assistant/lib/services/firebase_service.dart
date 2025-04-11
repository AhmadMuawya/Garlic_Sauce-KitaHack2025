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
      String? storagePath,
    })
  >
  _uploadImage(String cropId, File imageFile) async {
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
          'uploadedAt': timestamp,
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
        storagePath: storagePath,
      );
    } on FirebaseException catch (e) {
      print(
        "FirebaseService: Upload failed - Code: ${e.code}, Message: ${e.message}",
      );
      return (
        isSuccess: false,
        imageUrl: null,
        errorMessage: 'Storage Error: ${e.message ?? e.code}',
        storagePath: null,
      );
    } catch (e) {
      print("FirebaseService: Upload failed - Unexpected: $e");
      return (
        isSuccess: false,
        imageUrl: null,
        errorMessage: 'Unexpected upload error: $e',
        storagePath: null,
      );
    }
  }

  // --- MODIFIED: Calls the 'diagoniseCrop' onRequest Function using HTTP --- http: ^1.1.0
  Future<AnalysisResult> _fetchAnalysisViaHttp(
    String cropType,
    String? imageUrl,
    String? imagePath,
  ) async {
    final Uri functionUri = Uri.parse(
      "https://diagonisecrop-f6hm6f2zoq-uc.a.run.app",
    ); // Your Diagnosis Endpoint
    print("FirebaseService: Calling HTTP Function URL: $functionUri");
    // ... (Payload setup, headers - same as before) ...
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final Map<String, dynamic> body = {
      'cropType': cropType,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'userId': 'test_user01', // Pass if needed
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
          // --- PARSE diagnosisId ---
          // **IMPORTANT**: Adjust 'diagnosisId' key if your function returns it differently
          final String? diagnosisId =
              data['diagnosisId'] as String?; // Example parsing

          return AnalysisResult.success(
            prediction: data['disease'] as String?,
            confidence: (data['confidence'] as num?)?.toDouble(),
            advise: data['advice'] as String?,
            imageUrl: imageUrl,
            diagnosisId: diagnosisId, // <-- Store the parsed ID
          );
        } catch (e) {
          /* ... JSON parsing error handling ... */
          print("FirebaseService: Failed to parse function response: $e");
          return AnalysisResult.error(
            "Failed to parse analysis response: ${response.body}",
          );
        }
      } else {
        /* ... HTTP error handling ... */
        return AnalysisResult.error(
          "Analysis request failed (Status ${response.statusCode}): ${response.body}",
        );
      }
    } catch (e) {
      /* ... Network/Other error handling ... */
      if (e is SocketException) {
        print("FirebaseService: Network error calling Cloud Run: $e");
        return AnalysisResult.error(
          "Network Error: Could not connect to analysis service.",
        );
      } else if (e is http.ClientException) {
        print("FirebaseService: HTTP Client error calling Cloud Run: $e");
        return AnalysisResult.error(
          "Connection Error: Failed to call analysis service.",
        );
      } else {
        print("FirebaseService: Unexpected error calling Cloud Run: $e");
        return AnalysisResult.error(
          "An unexpected error occurred during analysis: $e",
        );
      }
    }
  }

  // --- NEW: handleChatMessage Method ---
  Future<({bool isSuccess, String? errorMessage, String? aiReply})>
  handleChatMessage({
    // Added aiReply to return type
    required String userId,
    required String diagnosisId,
    required String userMessage,
  }) async {
    final Uri functionUri = Uri.parse(
      "https://handlechatmessage-f6hm6f2zoq-uc.a.run.app",
    ); // Chat Endpoint
    print("FirebaseService: Calling Handle Chat URL: $functionUri");

    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final Map<String, dynamic> body = {
      "userId": userId,
      "diagnosisId": diagnosisId,
      "userMessage": userMessage,
    };

    try {
      final http.Response response = await http.post(
        functionUri,
        headers: headers,
        body: jsonEncode(body),
      );
      print("FirebaseService: Handle Chat Status Code: ${response.statusCode}");
      print("FirebaseService: Handle Chat Response Body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          // --- PARSE THE AI REPLY ---
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String? reply = data['reply'] as String?;
          if (reply != null) {
            return (
              isSuccess: true,
              errorMessage: null,
              aiReply: reply,
            ); // Return success with reply
          } else {
            // Success status but no reply field found in JSON
            return (
              isSuccess: true,
              errorMessage: null,
              aiReply: null,
            ); // Or handle as error?
          }
        } catch (e) {
          // JSON parsing error on success response
          print("FirebaseService: Failed to parse handleChat response: $e");
          return (
            isSuccess: false,
            errorMessage: "Failed to parse reply: ${response.body}",
            aiReply: null,
          );
        }
      } else {
        // Handle error status codes from chat handler function
        return (
          isSuccess: false,
          errorMessage:
              "Failed to send message (Status ${response.statusCode}): ${response.body}",
          aiReply: null,
        );
      }
    } catch (e) {
      // Handle Network/Other errors
      if (e is SocketException) {
        return (
          isSuccess: false,
          errorMessage: "Network Error: Could not send message.",
          aiReply: null,
        );
      }
      if (e is http.ClientException) {
        return (
          isSuccess: false,
          errorMessage: "Connection Error: Failed to send message.",
          aiReply: null,
        );
      }
      print("FirebaseService: Unexpected error calling handle chat: $e");
      return (
        isSuccess: false,
        errorMessage: "An unexpected error occurred while sending message.",
        aiReply: null,
      );
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
          "Image upload failed: ${uploadResult.errorMessage ?? 'Unknown reason'}",
        );
      }
      imageUrl = uploadResult.imageUrl;
      storagePathForFunction = uploadResult.storagePath;
      print(
        "FirebaseService: Image uploaded successfully, proceeding to analysis.",
      );
    } else {
      print(
        "FirebaseService: No image file provided, proceeding to analysis without image.",
      );
    }
    return await _fetchAnalysisViaHttp(
      cropId,
      imageUrl,
      storagePathForFunction,
    );
  }
}

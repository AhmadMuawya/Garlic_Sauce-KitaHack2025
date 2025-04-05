// // lib/s/api_test_.dart

// import 'dart:io';
// import 'package:agri_ai_assistant/models/analysis_result_model.dart'; // Your model
// import 'package:agri_ai_assistant/providers/app_provider.dart';
// import 'package:agri_ai_assistant/services/firebase_service.dart'; // Your Firebase service
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart'; // Add url_launcher to pubspec.yaml to open URL

// class ApiTest extends StatefulWidget {
//   const ApiTest({super.key});

//   @override
//   State<ApiTest> createState() => _ApiTestState();
// }

// class _ApiTestState extends State<ApiTest> {
//   // Instantiate the Firebase service
//   final FirebaseService _firebaseService = FirebaseService();

//   // State variables
//   bool _isLoading = false;
//   String _statusMessage = 'Ready to test Firebase Storage upload.';
//   AnalysisResult? _result; // Store the full result

//   // Trigger the upload test
//   Future<void> _runUploadTest() async {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = true;
//       _statusMessage = 'Starting image upload test...';
//       _result = null;
//     });

//     try {
//       // Get data from provider
//       final appProvider = Provider.of<AppProvider>(context, listen: false);
//       final String? cropId = appProvider.selectedCropId;
//       final File? imageFile =
//           appProvider.imagePath; // Recommended rename: imageFile

//       // --- Input Validation ---
//       if (cropId == null || cropId.isEmpty) {
//         setState(() {
//           _isLoading = false;
//           _statusMessage =
//               'Error: No Crop ID selected. Please go back and select a crop.';
//         });
//         return;
//       }
//       if (imageFile == null) {
//         setState(() {
//           _isLoading = false;
//           _statusMessage =
//               'Error: No Image selected/captured. Please go back and provide an image.';
//         });
//         return;
//       }

//       print("--- Running Upload Test ---");
//       print("Crop ID: $cropId");
//       print("Image File Path: ${imageFile.path}");
//       print("-------------------------");
//       setState(() {
//         _statusMessage = 'Uploading image for $cropId...';
//       });

//       // --- Call the service's upload function ---
//       final analysisResult =
//           await _firebaseService._uploadImage(cropId, imageFile);

//       if (!mounted) return; // Check mount status again

//       // Update UI based on the result
//       setState(() {
//         _isLoading = false;
//         _result = analysisResult; // Store the result

//         if (analysisResult.isSuccess) {
//           _statusMessage = 'Firebase Storage Upload SUCCESSFUL!';
//         } else {
//           _statusMessage =
//               'Firebase Storage Upload FAILED: ${analysisResult.errorMessage ?? 'Unknown error'}';
//         }
//       });
//     } catch (e) {
//       // Catch errors *outside* the service call (less likely here)
//       if (!mounted) return;
//       print("Error during upload test execution: $e");
//       setState(() {
//         _isLoading = false;
//         _statusMessage = 'An unexpected error occurred during the test: $e';
//         _result = null;
//       });
//     }
//   }

//   // Helper to launch URL
//   Future<void> _launchUrl(String? urlString) async {
//     if (urlString == null) return;
//     final Uri url = Uri.parse(urlString);
//     if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
//       print('Could not launch $url');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Could not open URL: $urlString')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appProvider = Provider.of<AppProvider>(context, listen: false);
//     final selectedCropId = appProvider.selectedCropId;
//     final imageFile = appProvider.imagePath;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Firebase Upload Test'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text('Testing Upload for:',
//                   style: Theme.of(context).textTheme.titleMedium),
//               const SizedBox(height: 8),
//               Text('Crop ID: ${selectedCropId ?? "Not Selected"}'),
//               Text('Image Provided: ${imageFile != null ? "Yes" : "No"}'),
//               if (imageFile != null)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8.0),
//                   child: Image.file(imageFile, height: 100, fit: BoxFit.cover),
//                 ),
//               const SizedBox(height: 30),

//               // --- Status Display ---
//               Text(
//                 'Status:',
//                 style: Theme.of(context).textTheme.titleLarge,
//               ),
//               const SizedBox(height: 8),
//               if (_isLoading)
//                 const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 10.0),
//                   child: CircularProgressIndicator(),
//                 ),
//               Text(
//                 _statusMessage,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: _result == null
//                       ? Colors.blueGrey
//                       : (_result!.isSuccess ? Colors.green : Colors.red),
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // --- Result Details (if available) ---
//               if (_result != null && !_isLoading) ...[
//                 const Divider(),
//                 Text(
//                   'Upload Result Details:',
//                   style: Theme.of(context).textTheme.titleMedium,
//                 ),
//                 const SizedBox(height: 8),
//                 Text('Success: ${_result!.isSuccess}'),
//                 // Show messages from the result
//                 Text('Message: ${_result!.prediction ?? 'N/A'}'),
//                 Text('Details: ${_result!.advise ?? 'N/A'}'),
//                 if (_result!.isSuccess && _result!.imageUrl != null) ...[
//                   const SizedBox(height: 10),
//                   Text('Image URL:',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   SelectableText(_result!.imageUrl!), // Make URL selectable
//                   TextButton.icon(
//                     // Add button to open URL
//                     icon: Icon(Icons.open_in_new, size: 18),
//                     label: Text("Open URL"),
//                     onPressed: () => _launchUrl(_result!.imageUrl),
//                   )
//                 ] else if (!_result!.isSuccess) ...[
//                   Text('Error: ${_result!.errorMessage ?? 'N/A'}'),
//                 ],
//                 const Divider(),
//                 const SizedBox(height: 20),
//               ],

//               // --- Test Trigger Button ---
//               ElevatedButton.icon(
//                 icon: const Icon(Icons.cloud_upload),
//                 label: const Text('Run Upload Test'),
//                 style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 30, vertical: 15)),
//                 // Disable button if no image or during loading
//                 onPressed:
//                     _isLoading || imageFile == null ? null : _runUploadTest,
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

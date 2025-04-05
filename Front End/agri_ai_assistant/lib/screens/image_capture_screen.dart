import 'dart:io';

import 'package:agri_ai_assistant/constants/app_constants.dart';
import 'package:agri_ai_assistant/models/crop_model.dart';
import 'package:agri_ai_assistant/providers/app_provider.dart';
//`import 'package:agri_ai_assistant/screens/api_test.dart';
import 'package:agri_ai_assistant/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (image != null) {
        File imageFile = File(image.path); // Convert XFile to File

        Provider.of<AppProvider>(context, listen: false)
            .setImagePath(imageFile);
      } else {
        print('No image captured.');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image selection cancelled.'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print("Error picking image: $e");
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final selectedCropId = appProvider.selectedCropId;
    final imagePath = appProvider.imagePath;

    final selectedCropName = selectedCropId == 'default'
        ? 'plant'
        : crops
            .firstWhere((crop) => crop.id == selectedCropId,
                orElse: () => const Crop(
                    id: 'default',
                    name: 'Unknown',
                    imagePath: '',
                    description: 'No description available'))
            .name; //3ashan algaho

    return Scaffold(
      appBar: AppBar(
        title: Text(imagePath == null
            ? 'Add Image for $selectedCropName'
            : 'Review Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Clear selection and navigate back to crop selection
            Provider.of<AppProvider>(context, listen: false).setImagePath(null);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_search,
                          size: 60,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add an image of the $selectedCropName',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        )
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )),
            ),
            const SizedBox(height: 24), // lelspace

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                //capture
                ElevatedButton.icon(
                  onPressed: () => _captureImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(imagePath == null ? 'Capture' : 'Retake'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                //upload from gallery

                ElevatedButton.icon(
                  onPressed: () => _captureImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(imagePath == null ? 'Upload' : 'Change'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16), // lelspace

            //proceed button
            ElevatedButton.icon(
              icon: const Icon(Icons.forward),
              label: const Text('Proceed to chat'),
              onPressed: imagePath == null
                  ? null
                  : () {
                      print('Proceeding to API Test Screen.');
                      // Navigate to test screen instead of ChatScreen
                      Navigator.of(context).push(
                        // Use push, not pushReplacement, so you can go back
                        MaterialPageRoute(
                            builder: (context) => const ChatScreen()),
                      );
                    },
            ),
            const SizedBox(height: 8), // lelspace

            //skip button
            TextButton(
              child: const Text('Skip and proceed to chat'),
              onPressed: () {
                Provider.of<AppProvider>(context, listen: false)
                    .setImagePath(null);
                print('skip image capture');

                //navigate to chat screen
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const ChatScreen()));
              },
            ),
            const Spacer(), // lelspace
          ],
        ),
      ),
    );
  }
}

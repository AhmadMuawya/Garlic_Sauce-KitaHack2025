import 'package:agri_ai_assistant/constants/app_constants.dart'; // Import our crop data
import 'package:agri_ai_assistant/models/crop_model.dart';
import 'package:agri_ai_assistant/providers/app_provider.dart';
import 'package:agri_ai_assistant/screens/image_capture_screen.dart'; // Placeholder for next screen
import 'package:agri_ai_assistant/widgets/crop_card.dart'; // Import the card widget
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CropSelectionScreen extends StatelessWidget {
  const CropSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Crop> ourcrops = crops;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Crop'),
        // Optional: Add a subtle background color if desired
        // backgroundColor: Colors.green.shade50,
        // elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: 1.0,
          ),
          itemCount: ourcrops.length,
          itemBuilder: (context, index) {
            final crop = ourcrops[index];

            return CropCard(
              crop: crop,
              onTap: () {
                print('selected crop: ${crop.name}');

                //update the selected crop in the provider
                Provider.of<AppProvider>(
                  context,
                  listen: false,
                ).setSelectedCropId(crop.id);

                //navigate to the next screen (image capture screen)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ImageCaptureScreen(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

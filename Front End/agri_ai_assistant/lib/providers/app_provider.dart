import 'dart:io';

import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  String? _selectedCropId;
  File? _imagePath;

  String? get selectedCropId => _selectedCropId;
  File? get imagePath => _imagePath;

  void setSelectedCropId(String? cropId) {
    if (_selectedCropId != cropId) {
      _selectedCropId = cropId;

      print("Crop selected: $_selectedCropId");
      notifyListeners();
    }
  }

  void setImagePath(File? path) {
    _imagePath = path;

    print("Image selected: $_imagePath");
    notifyListeners();
  }

  void clearSelection() {
    _selectedCropId = null;
    _imagePath = null;
    print("Selection cleared");
    notifyListeners();
  }
}

// app_provider.dart

import 'dart:io';
import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  String? _selectedCropId;
  File? _imagePath;
  final List<String> _userMessages = [];
  final List<String> _assistantMessages = [];

  String? get selectedCropId => _selectedCropId;
  File? get imagePath => _imagePath;
  List<String> get userMessages => _userMessages;
  List<String> get assistantMessages => _assistantMessages;

  void setSelectedCropId(String? cropId) {
    if (_selectedCropId != cropId) {
      _selectedCropId = cropId;
      notifyListeners();
    }
  }

  void setImagePath(File? path) {
    _imagePath = path;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCropId = null;
    _imagePath = null;
    notifyListeners();
  }

  void addUserMessage(String message) {
    _userMessages.add(message);
    notifyListeners();
  }

  void addAssistantMessage(String message) {
    _assistantMessages.add(message);
    notifyListeners();
  }
}

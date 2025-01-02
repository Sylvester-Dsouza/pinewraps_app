import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;

class FileHandlerService {
  /// Downloads and opens a file from a URL
  Future<void> downloadAndOpenFile(String url, String filename) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      
      // Download file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file');
      }
      
      // Save file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Open file
      await openFile(filePath);
    } catch (e) {
      print('Error handling file: $e');
      rethrow;
    }
  }
  
  /// Opens a file from local path
  Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening file: $e');
      rethrow;
    }
  }
  
  /// Shares a file using platform's share dialog
  Future<void> shareFile(String filePath) async {
    try {
      final result = await OpenFile.share(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to share file: ${result.message}');
      }
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }
}

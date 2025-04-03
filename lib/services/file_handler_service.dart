import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch $filePath');
      }
    } catch (e) {
      print('Error opening file: $e');
      rethrow;
    }
  }

  /// Shares a file using platform's share dialog
  Future<void> shareFile(String filePath) async {
    try {
      // Since we don't have OpenFile.share, we'll just open the file
      // In a real implementation, you might want to use a sharing plugin
      await openFile(filePath);
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }
}

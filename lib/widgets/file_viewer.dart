import 'package:flutter/material.dart';
import '../services/file_handler_service.dart';

class FileViewer extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const FileViewer({
    Key? key,
    required this.fileUrl,
    required this.fileName,
  }) : super(key: key);

  @override
  State<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<FileViewer> {
  final FileHandlerService _fileHandler = FileHandlerService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openFile();
  }

  Future<void> _openFile() async {
    try {
      await _fileHandler.downloadAndOpenFile(
        widget.fileUrl,
        widget.fileName,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error opening file:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _openFile();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

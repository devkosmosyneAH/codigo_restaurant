// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Future<String?> saveJsonFile({
  required String fileName,
  required String jsonContent,
}) async {
  final blob = html.Blob([jsonContent], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return fileName;
}

Future<String?> pickJsonFileContent() async {
  final input = html.FileUploadInputElement();
  input.accept = '.json,application/json';

  final completer = Completer<String?>();

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = html.FileReader();

    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (!completer.isCompleted) {
        completer.complete(result is String ? result : null);
      }
    });

    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}

import 'web_json_file_bridge_stub.dart'
    if (dart.library.html) 'web_json_file_bridge_web.dart'
    as impl;

Future<String?> saveJsonFile({
  required String fileName,
  required String jsonContent,
}) {
  return impl.saveJsonFile(fileName: fileName, jsonContent: jsonContent);
}

Future<String?> pickJsonFileContent() {
  return impl.pickJsonFileContent();
}

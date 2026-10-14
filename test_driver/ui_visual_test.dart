import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('dist/ui-review/android');
  await directory.create(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) => writeResponseData(
      data,
      destinationDirectory: directory.path,
      testOutputFilename: 'ui-results',
    ),
  );
}

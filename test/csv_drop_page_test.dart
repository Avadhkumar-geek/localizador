import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localizador/csv_processor.dart'; // Assuming this is the correct import
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import 'package:csv/csv.dart';

// Helper class to hold the expected data parsed from a CSV
class CsvVerificationData {
  final List<String> languageCodes;
  // A map where: key=languageCode, value=Map<stringKey, translation>
  final Map<String, Map<String, String>> translations;

  CsvVerificationData({
    required this.languageCodes,
    required this.translations,
  });
}

void runCsvPageTests() {
  group('CsvProcessor Tests', () {
    late Directory tempDir;
    late CsvProcessor processor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('csv_test_');
      processor = CsvProcessor();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // =========================================================================
    // DYNAMIC TEST - This test can handle any valid CSV content.
    // =========================================================================
    test('should correctly process any valid CSV file dynamically', () async {
      // ARRANGE
      // 1. Define any CSV content you want to test.
      // This example includes a new language (de) and a missing translation.
      const csvContent = '''
key,es,fr,de
greeting,"Hola","Bonjour","Guten Tag"
farewell,"Adiós","Au revoir",
question,"Cómo estás?","Comment ça va?","Wie geht's?"
''';

      // 2. Create the temporary CSV file with this content.
      final testCsvFile = File(path.join(tempDir.path, 'dynamic_test.csv'));
      await testCsvFile.writeAsString(csvContent);

      // 3. Parse this CSV to get our "expected results" model.
      final verificationData = _parseCsvForVerification(csvContent);

      // ACT
      final result = await processor.processCsv(testCsvFile, tempDir.path);

      // ASSERT
      expect(result.isSuccess, isTrue);
      expect(
        result.message,
        // The number of files should match the number of languages in the header.
        contains(
          '${verificationData.languageCodes.length} language file(s) generated/updated',
        ),
      );

      // Dynamically verify the contents of each generated file.
      for (final langCode in verificationData.languageCodes) {
        final expectedStringsForLang = verificationData.translations[langCode]!;

        final xmlFile = File(
          path.join(tempDir.path, 'values-$langCode', 'strings.xml'),
        );

        // Verify the file was created
        expect(
          await xmlFile.exists(),
          isTrue,
          reason: 'File for language "$langCode" should be created.',
        );

        final doc = XmlDocument.parse(await xmlFile.readAsString());
        final stringsInXml = doc.findAllElements('string').toList();

        // Verify the number of strings is correct (it shouldn't include empty translations)
        expect(
          stringsInXml.length,
          expectedStringsForLang.length,
          reason:
              'Correct number of strings for language "$langCode" should be present.',
        );

        // Verify each key-value pair
        for (final entry in expectedStringsForLang.entries) {
          final expectedKey = entry.key;
          final expectedValue = entry.value;

          final xmlElement = stringsInXml.firstWhere(
            (el) => el.getAttribute('name') == expectedKey,
            orElse: () => throw StateError(
              'Key "$expectedKey" not found in strings.xml for language "$langCode"',
            ),
          );

          expect(
            xmlElement.innerText,
            expectedValue,
            reason:
                'Translation for key "$expectedKey" in language "$langCode" should be correct.',
          );
        }
      }
    });

    // =========================================================================
    // PRESERVED TESTS - These tests cover specific edge cases and error handling
    // that are still valuable and not covered by the dynamic test.
    // =========================================================================

    test(
      'should update existing strings.xml file without removing non-CSV strings',
      () async {
        // This test is valuable because it tests the MERGE logic specifically.
        // ARRANGE
        const csvContent = 'key,es\nhello,Hola\n';
        final testCsvFile = File(path.join(tempDir.path, 'update.csv'));
        await testCsvFile.writeAsString(csvContent);

        final valuesEsDir = Directory(path.join(tempDir.path, 'values-es'))
          ..createSync(recursive: true);
        final esFile = File(path.join(valuesEsDir.path, 'strings.xml'));
        await esFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="manually_added">This should be preserved.</string>
    <string name="hello">Old Hello</string>
</resources>
''');

        // ACT
        await processor.processCsv(testCsvFile, tempDir.path);

        // ASSERT
        final esDoc = XmlDocument.parse(await esFile.readAsString());
        final strings = esDoc.findAllElements('string').toList();
        expect(strings.length, 2);
        expect(
          strings
              .firstWhere((el) => el.getAttribute('name') == 'manually_added')
              .innerText,
          'This should be preserved.',
        );
        expect(
          strings
              .firstWhere((el) => el.getAttribute('name') == 'hello')
              .innerText,
          'Hola',
        );
      },
    );

    test('should show error for non-existent file', () async {
      final nonExistentFile = File('non_existent.csv');
      final result = await processor.processCsv(nonExistentFile, tempDir.path);

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Failed to process CSV'));
    });

    test('should handle CSV with invalid format - no data rows', () async {
      final invalidCsvFile = File(path.join(tempDir.path, 'invalid.csv'));
      await invalidCsvFile.writeAsString('key,es,fr');
      final result = await processor.processCsv(invalidCsvFile, tempDir.path);

      expect(result.isSuccess, isFalse);
      expect(result.error, 'CSV must have a header and at least one data row.');
    });

    test('should handle CSV with invalid format - no language columns', () async {
      final invalidCsvFile = File(path.join(tempDir.path, 'invalid2.csv'));
      await invalidCsvFile.writeAsString('key\nhello');
      final result = await processor.processCsv(invalidCsvFile, tempDir.path);

      expect(result.isSuccess, isFalse);
      expect(
        result.error,
        'CSV header must have at least a "key" column and one language column.',
      );
    });
  });
}

/// Helper function to parse CSV content into a structured verification model.
/// This allows the test to know what to expect from any given CSV.
CsvVerificationData _parseCsvForVerification(String csvContent) {
  final csvTable = const CsvToListConverter(eol: '\n').convert(csvContent);
  final header = csvTable.first.map((e) => e.toString().trim()).toList();
  final languageCodes = header.sublist(1);
  final dataRows = csvTable.sublist(1);

  final translations = <String, Map<String, String>>{};
  for (final langCode in languageCodes) {
    translations[langCode] = {};
  }

  for (final row in dataRows) {
    final key = row.first.toString().trim();
    if (key.isEmpty) continue;

    for (int i = 0; i < languageCodes.length; i++) {
      final langCode = languageCodes[i];
      final langColumnIndex = i + 1;

      if (row.length > langColumnIndex) {
        final value = row[langColumnIndex].toString();
        // Only add non-empty translations to our expectation model
        if (value.isNotEmpty) {
          translations[langCode]![key] = value;
        }
      }
    }
  }

  return CsvVerificationData(
    languageCodes: languageCodes,
    translations: translations,
  );
}

void main() {
  runCsvPageTests();
}

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

class CsvProcessor {
  /// Process a CSV file and generate Android strings.xml files
  ///
  /// [csvFile] - The CSV file to process
  /// [resFolderPath] - The path to the Android res folder
  ///
  /// Returns a [CsvProcessorResult] containing success/error information
  Future<CsvProcessorResult> processCsv(
    File csvFile,
    String resFolderPath,
  ) async {
    try {
      if (!await csvFile.exists()) {
        return CsvProcessorResult.error(
          'Failed to process CSV: File does not exist at ${csvFile.path}',
        );
      }

      final content = await csvFile.readAsString();
      final csvTable = const CsvToListConverter(eol: '\n').convert(content);

      if (csvTable.length < 2) {
        return CsvProcessorResult.error(
          'CSV must have a header and at least one data row.',
        );
      }

      final header = csvTable.first.map((e) => e.toString()).toList();
      if (header.length < 2) {
        return CsvProcessorResult.error(
          'CSV header must have at least a "key" column and one language column.',
        );
      }

      final dataRows = csvTable.sublist(1);
      final langCodes = header.sublist(1);
      int filesGenerated = 0;

      // Create files for each language in the header
      for (int i = 0; i < langCodes.length; i++) {
        final langCode = langCodes[i].trim();
        final langColumnIndex = i + 1;

        if (langCode.isEmpty) continue;

        // Create values directory using platform-agnostic path handling
        final valuesDir = Directory(
          path.join(resFolderPath, 'values-$langCode'),
        );
        if (!await valuesDir.exists()) {
          await valuesDir.create(recursive: true);
        }

        final stringsFile = File(path.join(valuesDir.path, 'strings.xml'));
        XmlDocument document;
        XmlElement resourcesElement;

        if (await stringsFile.exists()) {
          final fileContent = await stringsFile.readAsString();
          // Avoid parsing an empty file, which would cause an error
          if (fileContent.trim().isEmpty) {
            final builder = XmlBuilder();
            builder.processing('xml', "version='1.0' encoding='utf-8'");
            builder.element('resources', nest: () {});
            document = builder.buildDocument();
          } else {
            document = XmlDocument.parse(fileContent);
          }
          resourcesElement = document.rootElement;
        } else {
          // If file doesn't exist, create a new XML document structure
          final builder = XmlBuilder();
          builder.processing('xml', "version='1.0' encoding='utf-8'");
          builder.element('resources', nest: () {});
          document = builder.buildDocument();
          resourcesElement = document.rootElement;
        }

        // Find all existing string elements by their key for quick lookups
        final existingStringElements = <String, XmlElement>{};
        for (var element in resourcesElement.findAllElements('string')) {
          final key = element.getAttribute('name');
          if (key != null) {
            existingStringElements[key] = element;
          }
        }

        // Iterate through CSV rows to update existing or add new strings
        for (final row in dataRows) {
          if (row.length > langColumnIndex) {
            final key = row.first.toString().trim();
            final value = row[langColumnIndex].toString();

            if (key.isNotEmpty && value.isNotEmpty) {
              if (existingStringElements.containsKey(key)) {
                // --- UPDATE a string that already exists in the file ---
                final elementToUpdate = existingStringElements[key]!;
                elementToUpdate.children.clear(); // Remove old text/children
                elementToUpdate.children.add(
                  XmlText(value),
                ); // Add new text (XmlText handles escaping)
              } else {
                // --- ADD a new string resource to the end ---
                final newStringElement = XmlElement(
                  XmlName('string'),
                  [XmlAttribute(XmlName('name'), key)],
                  [XmlText(value)],
                );
                resourcesElement.children.add(newStringElement);
              }
            }
          }
        }

        // Write the updated XML content back to the file with proper formatting
        await stringsFile.writeAsString(
          document.toXmlString(pretty: true, indent: '    '),
        );
        filesGenerated++;
      }

      return CsvProcessorResult.success(
        '$filesGenerated language file(s) generated/updated successfully!',
      );
    } catch (e) {
      return CsvProcessorResult.error('Failed to process CSV: $e');
    }
  }
}

class CsvProcessorResult {
  final bool isSuccess;
  final String? message;
  final String? error;

  CsvProcessorResult._({required this.isSuccess, this.message, this.error});

  factory CsvProcessorResult.success(String message) {
    return CsvProcessorResult._(isSuccess: true, message: message);
  }

  factory CsvProcessorResult.error(String error) {
    return CsvProcessorResult._(isSuccess: false, error: error);
  }
} // import 'dart:io';

// import 'package:csv/csv.dart';
// import 'package:path/path.dart' as path;
// import 'package:xml/xml.dart';

// class CsvProcessor {
//   /// Process a CSV file and generate Android strings.xml files
//   ///
//   /// [csvFile] - The CSV file to process
//   /// [resFolderPath] - The path to the Android res folder
//   ///
//   /// Returns a [CsvProcessorResult] containing success/error information
//   Future<CsvProcessorResult> processCsv(
//     File csvFile,
//     String resFolderPath,
//   ) async {
//     try {
//       final content = await csvFile.readAsString();
//       final csvTable = const CsvToListConverter(eol: '\n').convert(content);

//       if (csvTable.length < 2) {
//         return CsvProcessorResult.error(
//           'CSV must have a header and at least one data row.',
//         );
//       }

//       final header = csvTable.first.map((e) => e.toString()).toList();
//       if (header.length < 2) {
//         return CsvProcessorResult.error(
//           'CSV header must have at least a "key" column and one language column.',
//         );
//       }

//       final dataRows = csvTable.sublist(1);
//       final langCodes = header.sublist(1);
//       int filesGenerated = 0;

//       // Create files for each language in the header
//       for (int i = 0; i < langCodes.length; i++) {
//         final langCode = langCodes[i].trim();
//         final langColumnIndex = i + 1;

//         if (langCode.isEmpty) continue;

//         // Create values directory using platform-agnostic path handling
//         final valuesDir = Directory(
//           path.join(resFolderPath, 'values-$langCode'),
//         );
//         if (!await valuesDir.exists()) {
//           await valuesDir.create(recursive: true);
//         }

//         final stringsFile = File(path.join(valuesDir.path, 'strings.xml'));
//         XmlDocument document;
//         XmlElement resourcesElement;

//         if (await stringsFile.exists()) {
//           final fileContent = await stringsFile.readAsString();
//           // Avoid parsing an empty file, which would cause an error
//           if (fileContent.trim().isEmpty) {
//             final builder = XmlBuilder();
//             builder.processing('xml', "version='1.0' encoding='utf-8'");
//             builder.element('resources', nest: () {});
//             document = builder.buildDocument();
//           } else {
//             document = XmlDocument.parse(fileContent);
//           }
//           resourcesElement = document.rootElement;
//         } else {
//           // If file doesn't exist, create a new XML document structure
//           final builder = XmlBuilder();
//           builder.processing('xml', "version='1.0' encoding='utf-8'");
//           builder.element('resources', nest: () {});
//           document = builder.buildDocument();
//           resourcesElement = document.rootElement;
//         }

//         // Find all existing string elements by their key for quick lookups
//         final existingStringElements = <String, XmlElement>{};
//         for (var element in resourcesElement.findAllElements('string')) {
//           final key = element.getAttribute('name');
//           if (key != null) {
//             existingStringElements[key] = element;
//           }
//         }

//         // Iterate through CSV rows to update existing or add new strings
//         for (final row in dataRows) {
//           if (row.length > langColumnIndex) {
//             final key = row.first.toString().trim();
//             final value = row[langColumnIndex].toString();

//             if (key.isNotEmpty) {
//               if (existingStringElements.containsKey(key)) {
//                 // --- UPDATE a string that already exists in the file ---
//                 final elementToUpdate = existingStringElements[key]!;
//                 elementToUpdate.children.clear(); // Remove old text/children
//                 elementToUpdate.children.add(
//                   XmlText(value),
//                 ); // Add new text (XmlText handles escaping)
//               } else {
//                 // --- ADD a new string resource to the end ---
//                 final newStringElement = XmlElement(
//                   XmlName('string'),
//                   [XmlAttribute(XmlName('name'), key)],
//                   [XmlText(value)],
//                 );
//                 resourcesElement.children.add(newStringElement);
//               }
//             }
//           }
//         }

//         // Write the updated XML content back to the file with proper formatting
//         await stringsFile.writeAsString(
//           document.toXmlString(pretty: true, indent: '    '),
//         );
//         filesGenerated++;
//       }

//       return CsvProcessorResult.success(
//         '$filesGenerated language file(s) generated/updated successfully!',
//       );
//     } catch (e) {
//       return CsvProcessorResult.error('Failed to process CSV: $e');
//     }
//   }
// }

// class CsvProcessorResult {
//   final bool isSuccess;
//   final String? message;
//   final String? error;

//   CsvProcessorResult._({required this.isSuccess, this.message, this.error});

//   factory CsvProcessorResult.success(String message) {
//     return CsvProcessorResult._(isSuccess: true, message: message);
//   }

//   factory CsvProcessorResult.error(String error) {
//     return CsvProcessorResult._(isSuccess: false, error: error);
//   }
// }

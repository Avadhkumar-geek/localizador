import 'dart:io';

import 'package:flutter/material.dart';
import 'package:localizador/csv_drop_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localizador',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.light),
        fontFamily: Platform.isWindows
            ? 'Segoe UI'
            : Platform.isMacOS
            ? 'SF Pro Display'
            : 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.dark),
        fontFamily: Platform.isWindows
            ? 'Segoe UI'
            : Platform.isMacOS
            ? 'SF Pro Display'
            : 'Roboto',
      ),
      home: const CsvDropPage(),
    );
  }
}

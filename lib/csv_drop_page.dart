import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:localizador/csv_processor.dart';
import 'package:localizador/dot_pattern_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CsvDropPage extends StatefulWidget {
  const CsvDropPage({super.key});

  @override
  State<CsvDropPage> createState() => CsvDropPageState();
}

class CsvDropPageState extends State<CsvDropPage>
    with TickerProviderStateMixin {
  bool _dragging = false;
  String? _error;
  String? _successMessage;
  String? _selectedPath;
  List<String> _recentPaths = [];
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _loadRecentPaths();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentPaths() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentPaths = prefs.getStringList('recent_paths') ?? [];
      _selectedPath = prefs.getString('last_selected_path');
    });
  }

  Future<void> _saveRecentPath(String path) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove path if it already exists
    _recentPaths.removeWhere((p) => p == path);

    // Add to beginning
    _recentPaths.insert(0, path);

    // Keep only last 5 paths
    if (_recentPaths.length > 5) {
      _recentPaths = _recentPaths.take(5).toList();
    }

    await prefs.setStringList('recent_paths', _recentPaths);
    await prefs.setString('last_selected_path', path);

    setState(() {
      _selectedPath = path;
    });
  }

  String _truncatePath(String fullPath) {
    // For display purposes, show last 2 directory levels
    final parts = fullPath.split(Platform.pathSeparator);
    if (parts.length > 2) {
      return '...${Platform.pathSeparator}${parts[parts.length - 2]}${Platform.pathSeparator}${parts[parts.length - 1]}';
    }
    return fullPath;
  }

  // The _escapeXml function is no longer needed as the xml package handles it.

  // Public getters for testing
  String? get error => _error;
  String? get successMessage => _successMessage;

  // Public method for testing
  Future<void> processCsv(File file, String resFolderPath) async {
    await _processCsv(file, resFolderPath);
  }

  Future<void> _processCsv(File file, String resFolderPath) async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _successMessage = null;
    });

    final processor = CsvProcessor();
    final result = await processor.processCsv(file, resFolderPath);

    if (result.isSuccess) {
      await _saveRecentPath(resFolderPath);
      _successController.forward();

      setState(() {
        _error = null;
        _successMessage = result.message;
        _isProcessing = false;
      });
    } else {
      setState(() {
        _error = result.error;
        _successMessage = null;
        _isProcessing = false;
      });
    }
  }

  Future<String?> _selectPath() async {
    if (_selectedPath != null && _recentPaths.isNotEmpty) {
      final result = await _showPathSelectionDialog();
      if (result == 'BROWSE') {
        return await getDirectoryPath(
          confirmButtonText: 'Select Android res folder',
        );
      }
      return result;
    } else {
      return await getDirectoryPath(
        confirmButtonText: 'Select Android res folder',
      );
    }
  }

  Future<void> _selectAndProcessFile() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) {
      // User canceled the picker
      return;
    }

    final folderPath = await _selectPath();
    if (folderPath == null) {
      setState(() => _error = 'No folder selected. Operation cancelled.');
      return;
    }
    await _processCsv(File(file.path), folderPath);
  }

  Future<String?> _showPathSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Output Folder'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedPath != null) ...[
                const Text(
                  'Current Path:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedPath!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_recentPaths.isNotEmpty) ...[
                const Text(
                  'Recent Paths:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...(_recentPaths
                    .take(3)
                    .map(
                      (path) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(path),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _truncatePath(path),
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (_selectedPath != null)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedPath),
              child: const Text('Use Current'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('BROWSE'),
            child: const Text('Browse...'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDrop(List<XFile> files) async {
    setState(() {
      _error = null;
      _successMessage = null;
      _dragging = false;
    });

    if (files.isEmpty) return;

    final file = files.first;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      setState(() => _error = 'Please drop a CSV file.');
      return;
    }

    final folderPath = await _selectPath();
    if (folderPath == null) {
      setState(() => _error = 'No folder selected. Operation cancelled.');
      return;
    }

    await _processCsv(File(file.path), folderPath);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width < 900;
    final isLandscape = screenSize.width > screenSize.height;

    // Responsive dimensions
    final dropZoneWidth = isSmallScreen
        ? screenSize.width * 0.9
        : isMediumScreen
        ? screenSize.width * 0.8
        : 600.0;

    final dropZoneHeight = isSmallScreen
        ? isLandscape
              ? screenSize.height * 0.6
              : screenSize.height * 0.45
        : isMediumScreen
        ? 350.0
        : 400.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Localizador',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18 : 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_recentPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showPathSelectionDialog(),
              tooltip: 'Path Settings',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add some top spacing on larger screens
                  if (!isSmallScreen)
                    SizedBox(height: screenSize.height * 0.05),

                  // Status indicator
                  if (_selectedPath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: isSmallScreen ? 14 : 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Output folder configured',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main drop zone
                  AnimatedBuilder(
                    animation: _dragging ? _pulseAnimation : _successAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _dragging ? _pulseAnimation.value : 1.0,
                        child: DropTarget(
                          onDragDone: (detail) => _handleDrop(detail.files),
                          onDragEntered: (detail) =>
                              setState(() => _dragging = true),
                          onDragExited: (detail) =>
                              setState(() => _dragging = false),
                          child: Container(
                            width: dropZoneWidth,
                            height: dropZoneHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer.withAlpha(25),
                                  Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                      .withAlpha(25),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                isSmallScreen ? 20 : 24,
                              ),
                              border: Border.all(
                                color: _dragging
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outline.withAlpha(77),
                                width: _dragging ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                if (_dragging)
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(51),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Background pattern
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DotPatternPainter(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline.withAlpha(25),
                                      // spacing: isSmallScreen ? 15.0 : 20.0,
                                    ),
                                  ),
                                ),

                                // Content
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 16.0 : 24.0,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Icon with animation
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 16 : 24,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _dragging
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withAlpha(25)
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withAlpha(128),
                                            shape: BoxShape.circle,
                                          ),
                                          child: _isProcessing
                                              ? SizedBox(
                                                  width: isSmallScreen
                                                      ? 32
                                                      : 48,
                                                  height: isSmallScreen
                                                      ? 32
                                                      : 48,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                  ),
                                                )
                                              : Icon(
                                                  _dragging
                                                      ? Icons.file_download
                                                      : Icons.upload_file,
                                                  size: isSmallScreen ? 32 : 48,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                        ),

                                        SizedBox(
                                          height: isSmallScreen ? 16 : 24,
                                        ),

                                        // Main text
                                        Text(
                                          _isProcessing
                                              ? 'Processing your CSV file...'
                                              : _dragging
                                              ? 'Drop your CSV file here!'
                                              : isSmallScreen
                                              ? 'Drag & drop CSV file'
                                              : 'Drag and drop your CSV file',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                fontSize: isSmallScreen
                                                    ? 18
                                                    : 24,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),

                                        SizedBox(
                                          height: isSmallScreen ? 8 : 12,
                                        ),
                                        // Click to select button
                                        TextButton.icon(
                                          onPressed: _selectAndProcessFile,
                                          icon: const Icon(Icons.folder_open),
                                          label: const Text(
                                            'Or click to select a file',
                                          ),
                                        ),

                                        SizedBox(
                                          height: isSmallScreen ? 20 : 32,
                                        ),

                                        // Status messages
                                        if (_error != null)
                                          Container(
                                            padding: EdgeInsets.all(
                                              isSmallScreen ? 12 : 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.errorContainer,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.error_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onErrorContainer,
                                                  size: isSmallScreen ? 18 : 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _error!,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onErrorContainer,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: isSmallScreen
                                                          ? 12
                                                          : 14,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        if (_successMessage != null)
                                          ScaleTransition(
                                            scale: _successAnimation,
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                isSmallScreen ? 12 : 16,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color:
                                                        Colors.green.shade700,
                                                    size: isSmallScreen
                                                        ? 18
                                                        : 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      _successMessage!,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: isSmallScreen
                                                            ? 12
                                                            : 14,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 32),

                  // File format info
                  Container(
                    width: dropZoneWidth,
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(128),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Expected CSV Format',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          isSmallScreen
                              ? 'key,en,es,fr\nwelcome,Welcome,Bienvenido,Bienvenue'
                              : 'key,en,es,fr\nwelcome,Welcome,Bienvenido,Bienvenue\ngoodbye,Goodbye,Adiós,Au revoir',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(178),
                                fontSize: isSmallScreen ? 10 : 12,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Add bottom spacing
                  if (!isSmallScreen)
                    SizedBox(height: screenSize.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

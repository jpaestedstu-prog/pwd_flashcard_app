import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'hive_service.dart';

/// Handles exporting and importing custom flashcards as JSON files.
///
/// The file format is a JSON array of flashcard objects, making it
/// easy for teachers to share custom word sets between devices.
class FlashcardExportService {
  FlashcardExportService._();

  /// Exports all custom flashcards to a JSON file and opens the
  /// platform share sheet so the user can save or send it.
  static Future<void> exportCards() async {
    final cards = HiveService.getCustomCards();
    if (cards.isEmpty) return;

    final jsonList = cards.map((c) => c.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    // Write to a temp file
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/flashlearn_cards_$timestamp.json');
    await file.writeAsString(jsonString);

    // Share
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FlashLearn PWD – Custom Flashcards',
      text: 'Here are ${cards.length} custom flashcards exported from FlashLearn PWD.',
    );
  }

  /// Opens a file picker for the user to select a JSON file,
  /// parses the flashcards, and saves them to Hive.
  ///
  /// Returns the number of cards successfully imported, or -1 on error.
  static Future<int> importCards() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return 0;

    try {
      final path = result.files.single.path;
      if (path == null) return -1;

      final file = File(path);
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;

      int imported = 0;
      for (final item in jsonList) {
        if (item is Map<String, dynamic>) {
          try {
            final card = Flashcard.fromJson(item);
            // Avoid duplicates by checking existing custom card IDs
            final existing = HiveService.getCustomCards();
            final alreadyExists = existing.any((c) => c.id == card.id);
            if (!alreadyExists) {
              await HiveService.saveCustomCard(card);
              imported++;
            }
          } catch (e, stack) {
            ErrorHandler.report(e, stack, 'FlashcardImport');
          }
        }
      }
      return imported;
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'FlashcardImport');
      return -1;
    }
  }
}

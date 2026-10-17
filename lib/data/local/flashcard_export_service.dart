import 'dart:convert';
import 'dart:typed_data';
import '../../core/utils/error_handler.dart';
import '../../core/utils/share_file.dart';
import '../models/models.dart';
import 'hive_service.dart';

/// Handles exporting and importing custom flashcards as JSON files.
///
/// The file format is a JSON array of flashcard objects, making it
/// easy for teachers to share custom word sets between devices.
class FlashcardExportService {
  FlashcardExportService._();

  /// Exports all custom flashcards to a JSON file and opens the
  /// platform share sheet so the user can save or send it (a browser
  /// downloads it). Returns how many cards went: 0 when there are none,
  /// which the caller says, rather than a tap that does nothing.
  static Future<int> exportCards() async {
    final cards = HiveService.getCustomCards();
    if (cards.isEmpty) return 0;

    final jsonList = cards.map((c) => c.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await ShareFile.share(
      [
        ShareFile.text(
          jsonString,
          name: 'flashlearn_cards_$timestamp.json',
          mimeType: 'application/json',
        ),
      ],
      subject: 'FlashLearn PWD – Custom Flashcards',
      text: 'Here are ${cards.length} custom flashcards exported from FlashLearn PWD.',
    );
    return cards.length;
  }

  /// Opens a file picker for the user to select a JSON file,
  /// parses the flashcards, and saves them to Hive.
  ///
  /// Returns the number of cards successfully imported, or -1 on error.
  static Future<int> importCards() async {
    // Bytes, not a path: a browser hands over no path.
    final Uint8List? bytes;
    try {
      bytes = await PickFile.bytes(extensions: ['json']);
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'FlashcardImport');
      return -1;
    }
    if (bytes == null) return 0;

    try {
      final content = utf8.decode(bytes);
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/share_file.dart';

/// The files exports hand over: named so every platform can write them.
void main() {
  group('ShareFile.safeName', () {
    test('a learner\'s name with a slash no longer points into a folder', () {
      // "Cognitive/Learning Anak" is a real profile name (the disability
      // category's label). The progress CSV was written to
      // <tmp>/FlashLearn_Data_Cognitive/Learning Anak_….csv, a folder that
      // does not exist, and the export failed.
      expect(
        ShareFile.safeName('FlashLearn_Data_Cognitive/Learning Anak_2026.csv'),
        'FlashLearn_Data_Cognitive_Learning Anak_2026.csv',
      );
    });

    test('every character a file system refuses is replaced', () {
      expect(ShareFile.safeName(r'a\b:c*d?e"f<g>h|i.csv'),
          'a_b_c_d_e_f_g_h_i.csv');
      expect(ShareFile.safeName('tab\there.csv'), 'tab_here.csv');
    });

    test('ordinary names, Filipino letters and emoji are left alone', () {
      expect(ShareFile.safeName('progress_Grade_3_2026-10-17.csv'),
          'progress_Grade_3_2026-10-17.csv');
      expect(ShareFile.safeName('Niño Peñaflor.json'), 'Niño Peñaflor.json');
      expect(ShareFile.safeName('🐶 Bantay.csv'), '🐶 Bantay.csv');
    });

    test('a name with nothing left still names a file', () {
      expect(ShareFile.safeName('   '), 'FlashLearn');
    });
  });

  test('text files carry their bytes in UTF-8, Filipino letters included', () {
    final f = ShareFile.text('Salitâ,Niño\n', name: 'x.csv',
        mimeType: 'text/csv');
    expect(f.name, 'x.csv');
    expect(f.mimeType, 'text/csv');
    expect(utf8.decode(f.bytes), 'Salitâ,Niño\n');
  });
}

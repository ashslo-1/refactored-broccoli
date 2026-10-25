/*
 * FLauncher
 * Copyright (C) 2024 Jules
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:flauncher/models/watch_next_program.dart';

void main() {
  group('WatchNextProgram', () {
    test('fromMap parses map fields correctly', () {
      final program = WatchNextProgram.fromMap({
        'id': 101,
        'packageName': 'com.netflix.ninja',
        'title': 'Test Show',
        'description': 'Test Description',
        'watchNextType': 0,
        'lastEngagementTime': 1600000000,
        'playbackPosition': 5000,
        'duration': 10000,
        'intentUri': 'https://netflix.com/watch/101',
        'posterArtUri': 'content://android.media.tv/poster/101',
      });

      expect(program.id, 101);
      expect(program.packageName, 'com.netflix.ninja');
      expect(program.title, 'Test Show');
      expect(program.description, 'Test Description');
      expect(program.watchNextType, 0);
      expect(program.lastEngagementTime, 1600000000);
      expect(program.playbackPosition, 5000);
      expect(program.duration, 10000);
      expect(program.intentUri, 'https://netflix.com/watch/101');
      expect(program.posterArtUri, 'content://android.media.tv/poster/101');
      expect(program.safeProgress, 0.5);
    });

    test('safeProgress calculates ratio within [0.0, 1.0]', () {
      final program = WatchNextProgram(
        id: 1,
        packageName: 'com.example',
        title: 'Title',
        description: 'Desc',
        watchNextType: 0,
        lastEngagementTime: 0,
        playbackPosition: 250,
        duration: 1000,
        intentUri: '',
        posterArtUri: '',
      );

      expect(program.safeProgress, 0.25);
    });

    test('safeProgress returns 0.0 when duration or playbackPosition is zero or negative', () {
      final p1 = WatchNextProgram(
        id: 1,
        packageName: 'com.example',
        title: 'Title',
        description: 'Desc',
        watchNextType: 0,
        lastEngagementTime: 0,
        playbackPosition: 500,
        duration: 0,
        intentUri: '',
        posterArtUri: '',
      );
      expect(p1.safeProgress, 0.0);

      final p2 = WatchNextProgram(
        id: 2,
        packageName: 'com.example',
        title: 'Title',
        description: 'Desc',
        watchNextType: 0,
        lastEngagementTime: 0,
        playbackPosition: -10,
        duration: 1000,
        intentUri: '',
        posterArtUri: '',
      );
      expect(p2.safeProgress, 0.0);

      final p3 = WatchNextProgram(
        id: 3,
        packageName: 'com.example',
        title: 'Title',
        description: 'Desc',
        watchNextType: 0,
        lastEngagementTime: 0,
        playbackPosition: 100,
        duration: -500,
        intentUri: '',
        posterArtUri: '',
      );
      expect(p3.safeProgress, 0.0);
    });

    test('safeProgress clamps to 1.0 when playbackPosition exceeds duration', () {
      final program = WatchNextProgram(
        id: 1,
        packageName: 'com.example',
        title: 'Title',
        description: 'Desc',
        watchNextType: 0,
        lastEngagementTime: 0,
        playbackPosition: 1500,
        duration: 1000,
        intentUri: '',
        posterArtUri: '',
      );

      expect(program.safeProgress, 1.0);
    });
  });
}

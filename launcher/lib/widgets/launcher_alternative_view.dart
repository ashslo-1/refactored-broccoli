/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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

import 'dart:async';
import 'dart:math';

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/date_time_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class AlternativeLauncherView extends StatelessWidget {
  const AlternativeLauncherView({super.key});

  @override
  Widget build(BuildContext context) => Selector<SettingsService, (String, String, String, String)>(
    selector: (_, service) => (
      service.timeFormat,
      service.dateFormat,
      service.screensaverClockStyle,
      service.screensaverAnimationStyle,
    ),
    builder: (context, formats, _) {
      final (timeFormat, dateFormat, clockStyle, animStyle) = formats;

      if (animStyle == SCREENSAVER_ANIMATION_BOUNCE) {
        return _BouncingDvdClock(
          timeFormat: timeFormat,
          dateFormat: dateFormat,
          clockStyle: clockStyle,
        );
      } else if (animStyle == SCREENSAVER_ANIMATION_FADE) {
        return _FadingScreensaverClock(
          timeFormat: timeFormat,
          dateFormat: dateFormat,
          clockStyle: clockStyle,
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildClock(context, timeFormat, clockStyle),
            const SizedBox(height: 16),
            DateTimeWidget(
              dateFormat,
              textStyle: Theme.of(context).textTheme.headlineLarge!.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 12)],
              ),
            ),
          ],
        ),
      );
    },
  );

  static Widget buildClock(BuildContext context, String timeFormat, String style, {Color? textColor}) {
    final FontWeight fontWeight;
    final double fontSize;
    final double letterSpacing;
    final String? fontFamily;

    switch (style) {
      case 'bold':
        fontWeight = FontWeight.bold;
        fontSize = 140;
        letterSpacing = -2.0;
        fontFamily = null;
      case 'retro':
        fontWeight = FontWeight.w400;
        fontSize = 120;
        letterSpacing = 4.0;
        fontFamily = 'monospace';
      case 'elegant':
        fontWeight = FontWeight.w300;
        fontSize = 120;
        letterSpacing = 3.0;
        fontFamily = 'serif';
      case 'neon':
        fontWeight = FontWeight.w100;
        fontSize = 130;
        letterSpacing = 4.0;
        fontFamily = null;
      case 'pixel':
        fontWeight = FontWeight.w700;
        fontSize = 110;
        letterSpacing = 6.0;
        fontFamily = 'monospace';
      case 'digital':
        fontWeight = FontWeight.w300;
        fontSize = 120;
        letterSpacing = 2.0;
        fontFamily = 'monospace';
      default: // minimal
        fontWeight = FontWeight.w200;
        fontSize = 120;
        letterSpacing = 2.0;
        fontFamily = null;
    }

    final mainStyle = Theme.of(context).textTheme.displayLarge!.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      color: textColor,
      shadows: const [Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 16)],
    );

    // Check if format has AM/PM (contains 'a')
    final hasAmPm = timeFormat.contains('a');
    if (!hasAmPm) {
      return DateTimeWidget(timeFormat, textStyle: mainStyle);
    }

    // Split: render time without AM/PM at full size, AM/PM at 35% size on same line
    final timeOnly = timeFormat.replaceAll(RegExp(r'\s*a\s*'), '').trim();
    final amPmStyle = mainStyle.copyWith(
      fontSize: fontSize * 0.35,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
      color: textColor,
    );

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DateTimeWidget(timeOnly, textStyle: mainStyle),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DateTimeWidget('a', animate: false, textStyle: amPmStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _BouncingDvdClock extends StatefulWidget {
  final String timeFormat;
  final String dateFormat;
  final String clockStyle;

  const _BouncingDvdClock({
    required this.timeFormat,
    required this.dateFormat,
    required this.clockStyle,
  });

  @override
  State<_BouncingDvdClock> createState() => _BouncingDvdClockState();
}

class _BouncingDvdClockState extends State<_BouncingDvdClock> with SingleTickerProviderStateMixin {
  static const List<Color> _dvdColors = [
    Colors.white,
    Color(0xFF00E5FF), // Cyan
    Color(0xFFB388FF), // Purple
    Color(0xFF76FF03), // Electric Lime
    Color(0xFFFFD700), // Gold
    Color(0xFFFF4081), // Hot Pink
    Color(0xFFFFAB40), // Coral
  ];

  late Ticker _ticker;
  double _x = 60.0;
  double _y = 60.0;
  double _vx = 1.8;
  double _vy = 1.3;
  int _colorIndex = 0;
  final GlobalKey _contentKey = GlobalKey();
  Size _contentSize = const Size(360, 180);
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_contentKey.currentContext != null) {
      final renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.size != Size.zero) {
        _contentSize = renderBox.size;
      }
    }

    final double dt = _lastElapsed == Duration.zero
        ? 0.016
        : ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(0.005, 0.05);
    _lastElapsed = elapsed;

    final mediaQuery = MediaQuery.of(context).size;
    final maxWidth = mediaQuery.width;
    final maxHeight = mediaQuery.height;

    double newX = _x + _vx * 60.0 * dt;
    double newY = _y + _vy * 60.0 * dt;
    bool bounced = false;

    if (newX <= 0) {
      newX = 0;
      _vx = _vx.abs();
      bounced = true;
    } else if (newX + _contentSize.width >= maxWidth) {
      newX = (maxWidth - _contentSize.width).clamp(0.0, maxWidth);
      _vx = -_vx.abs();
      bounced = true;
    }

    if (newY <= 0) {
      newY = 0;
      _vy = _vy.abs();
      bounced = true;
    } else if (newY + _contentSize.height >= maxHeight) {
      newY = (maxHeight - _contentSize.height).clamp(0.0, maxHeight);
      _vy = -_vy.abs();
      bounced = true;
    }

    setState(() {
      _x = newX;
      _y = newY;
      if (bounced) {
        _colorIndex = (_colorIndex + 1) % _dvdColors.length;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _dvdColors[_colorIndex];

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: _x,
          top: _y,
          child: Container(
            key: _contentKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AlternativeLauncherView.buildClock(
                  context,
                  widget.timeFormat,
                  widget.clockStyle,
                  textColor: currentColor,
                ),
                const SizedBox(height: 12),
                DateTimeWidget(
                  widget.dateFormat,
                  textStyle: Theme.of(context).textTheme.headlineLarge!.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: currentColor.withOpacity(0.85),
                    shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FadingScreensaverClock extends StatefulWidget {
  final String timeFormat;
  final String dateFormat;
  final String clockStyle;

  const _FadingScreensaverClock({
    required this.timeFormat,
    required this.dateFormat,
    required this.clockStyle,
  });

  @override
  State<_FadingScreensaverClock> createState() => _FadingScreensaverClockState();
}

class _FadingScreensaverClockState extends State<_FadingScreensaverClock> {
  Timer? _timer;
  double _opacity = 1.0;
  Alignment _alignment = Alignment.center;
  final Random _random = Random();

  static const List<Alignment> _positions = [
    Alignment.center,
    Alignment(-0.5, -0.5),
    Alignment(0.5, -0.5),
    Alignment(-0.5, 0.5),
    Alignment(0.5, 0.5),
    Alignment(0.0, -0.4),
    Alignment(0.0, 0.4),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _shiftPosition());
  }

  void _shiftPosition() {
    if (!mounted) return;
    setState(() => _opacity = 0.0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _alignment = _positions[_random.nextInt(_positions.length)];
        _opacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: Duration.zero,
      alignment: _alignment,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        opacity: _opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AlternativeLauncherView.buildClock(context, widget.timeFormat, widget.clockStyle),
            const SizedBox(height: 16),
            DateTimeWidget(
              widget.dateFormat,
              textStyle: Theme.of(context).textTheme.headlineLarge!.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 12)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

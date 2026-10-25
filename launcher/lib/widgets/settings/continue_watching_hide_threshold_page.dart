/*
 * FLauncher
 * Copyright (C) 2026 LeanBitLab
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_service.dart';

class ContinueWatchingHideThresholdPage extends StatelessWidget {
  static const String routeName = "continue_watching_hide_threshold_panel";

  const ContinueWatchingHideThresholdPage({super.key});

  static const List<(int, String, String)> hideThresholdPresets = [
    (0, 'Off', 'Show all items regardless of progress • Default'),
    (80, '80%', 'Hide items watched past 80%'),
    (90, '90%', 'Hide items watched past 90%'),
    (95, '95%', 'Hide items watched past 95%'),
  ];

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsService, int>(
      selector: (_, settingsService) => settingsService.continueWatchingHideThreshold,
      builder: (context, currentThreshold, _) {
        final settingsService = context.read<SettingsService>();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Row(
                children: [
                  Text(
                    'Hide Nearly Finished',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: hideThresholdPresets.map((preset) {
                    final threshold = preset.$1;
                    final title = preset.$2;
                    final subtitle = preset.$3;
                    final isSelected = currentThreshold == threshold;

                    return _HideThresholdRadioTile(
                      title: title,
                      subtitle: subtitle,
                      value: threshold,
                      groupValue: currentThreshold,
                      isSelected: isSelected,
                      autofocus: isSelected,
                      onChanged: (value) {
                        if (value != null) {
                          settingsService.setContinueWatchingHideThreshold(value);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HideThresholdRadioTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final bool isSelected;
  final ValueChanged<int?> onChanged;
  final bool autofocus;

  const _HideThresholdRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.isSelected,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  State<_HideThresholdRadioTile> createState() => _HideThresholdRadioTileState();
}

class _HideThresholdRadioTileState extends State<_HideThresholdRadioTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (hasFocus) {
            setState(() {
              _hasFocus = hasFocus;
            });
            if (hasFocus) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          },
          child: InkWell(
            onTap: () {
              widget.onChanged(widget.value);
            },
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _hasFocus ? Colors.white.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: _hasFocus
                    ? Border.all(color: primaryColor, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                                color: widget.isSelected ? Colors.white : Colors.white70,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Radio<int>(
                    value: widget.value,
                    groupValue: widget.groupValue,
                    activeColor: primaryColor,
                    onChanged: widget.onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../kit/kit.dart' as kit;

abstract class SettingsSection {
  String get title;
  Widget get child;
}

mixin SettingsPageHelpers<T extends StatefulWidget> on State<T> {
  static const kSettingCardSpacing = 10.0;
  static const kSettingTilePadding = EdgeInsets.fromLTRB(16, 6, 16, 6);

  TextStyle? settingTitleStyle(ThemeData theme) {
    return theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
  }

  TextStyle? settingBodyStyle(ThemeData theme) {
    return theme.textTheme.bodyMedium;
  }

  TextStyle? settingHintStyle(ThemeData theme) {
    return theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget buildSettingsCard({
    required List<Widget> children,
    required ThemeData theme,
  }) {
    return Column(
      children: children
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: kSettingCardSpacing),
              child: kit.CardX(child: child),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget buildSettingsSectionBlock<S extends SettingsSection>(S section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kit.CenterGreyTitle(section.title),
        const SizedBox(height: 4),
        section.child,
      ],
    );
  }

  Widget buildSettingsTabView<S extends SettingsSection>(List<S> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxColumns = width >= 1440
            ? 3
            : width >= 900
            ? 2
            : 1;
        final columns = sections.isEmpty
            ? 1
            : maxColumns.clamp(1, sections.length);
        const gap = 16.0;
        final distributedSections = List.generate(columns, (_) => <S>[]);

        for (var index = 0; index < sections.length; index++) {
          distributedSections[index % columns].add(sections[index]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < distributedSections.length; i++) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: distributedSections[i]
                        .map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: buildSettingsSectionBlock(section),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                if (i < distributedSections.length - 1)
                  const SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }
}

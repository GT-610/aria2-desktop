import 'package:flutter/material.dart';

import '../provider/debug.dart';
import '../res/ui.dart';
import '../widgets/appbar.dart';
import '../widgets/btn.dart';

class DebugPageArgs {
  final String? title;

  const DebugPageArgs({this.title});
}

class DebugPage extends StatelessWidget {
  final DebugPageArgs? args;

  const DebugPage({super.key, this.args});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(args?.title ?? 'Log', style: const TextStyle(fontSize: 17)),
        actions: [
          const Btn.icon(
            icon: Icon(Icons.copy, size: 23),
            onTap: DebugProvider.copy,
          ),
          Btn.icon(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear logs?'),
                  actions: [
                    Btn.ok(
                      onTap: () {
                        DebugProvider.clear();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete, size: 26),
          ),
        ],
      ),
      body: _buildTerminal(context),
    );
  }

  Widget _buildTerminal(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ValueListenableBuilder<List<Widget>>(
        valueListenable: DebugProvider.widgets,
        builder: (_, widgets, _) {
          if (widgets.isEmpty) return UIs.placeholder;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: widgets.length,
            itemBuilder: (_, index) => widgets[index],
          );
        },
      ),
    );
  }
}

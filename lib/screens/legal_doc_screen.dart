import 'package:flutter/material.dart';

class LegalDocScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalDocScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

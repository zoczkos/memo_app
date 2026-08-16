import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help'), elevation: 1),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: const [
          _HelpSection(
            title: 'Preinstalled deck',
            body:
                'A folder named “English–Polish 500” is included on first launch, '
                'loaded from a bundled English;Polish word list (commas allowed in the English side).',
          ),
          _HelpSection(
            title: 'Import format',
            body:
                'Use a semicolon (;) to separate the front and back of each card. '
                'Commas are allowed inside the text, so they are not used as separators.',
          ),
          _HelpExample(
            label: 'Example (front;back)',
            lines: [
              'to be, or not to be;być albo nie być',
              'Hello, world!;Witaj, świecie!',
              'cat;kot',
            ],
          ),
          _HelpSection(
            title: 'English;Polish files',
            body:
                'Files that start with an English;Polish header (like the bundled deck) '
                'are detected automatically and mapped to the correct sides.',
          ),
          _HelpSection(
            title: 'File tips',
            body:
                'Import from a .csv or .txt file, or paste the same format from the clipboard. '
                'One card per line. Empty lines are ignored. Duplicate cards in the same folder are skipped. '
                'Use Export to download the whole set as a Front;Back CSV file.',
          ),
          _HelpSection(
            title: 'Study mode (SRS)',
            body:
                'Shows cards that are due for review. Tap the card to reveal the answer, '
                'then choose Forgot or Got it. Correct answers are scheduled further into the future.',
          ),
          _HelpSection(
            title: 'Free practice',
            body:
                'Browse cards in fixed 20-word subsets without changing the spaced-repetition '
                'schedule. Subsets follow the practice order shown in Manage words. '
                'Pick a subset from the dropdown (remembered when you return). '
                'Use Front → Back / Back → Front to flip study direction.',
          ),
          _HelpSection(
            title: 'Adding words',
            body:
                'Add words from Manage words, or with the + button while studying or practicing. '
                'In Manage words, use Shuffle practice order to randomize free-practice subsets.',
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String body;

  const _HelpSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpExample extends StatelessWidget {
  final String label;
  final List<String> lines;

  const _HelpExample({required this.label, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

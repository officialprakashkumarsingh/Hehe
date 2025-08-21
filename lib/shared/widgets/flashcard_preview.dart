import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/flashcard_message_model.dart';

class FlashcardPreview extends StatefulWidget {
  final List<FlashcardItem> flashcards;
  final String title;

  const FlashcardPreview({
    super.key,
    required this.flashcards,
    required this.title,
  });

  @override
  State<FlashcardPreview> createState() => _FlashcardPreviewState();
}

class _FlashcardPreviewState extends State<FlashcardPreview>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isExporting = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _nextCard() {
    if (_currentIndex < widget.flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  Future<void> _exportFlashcards() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Show export notification with proper positioning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exporting flashcards...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }

      // Create text content
      final buffer = StringBuffer();
      buffer.writeln('Flashcards: ${widget.title}');
      buffer.writeln('=' * 40);
      buffer.writeln();

      for (int i = 0; i < widget.flashcards.length; i++) {
        final card = widget.flashcards[i];
        buffer.writeln('Card ${i + 1}:');
        buffer.writeln('Q: ${card.question}');
        buffer.writeln('A: ${card.answer}');
        if (card.explanation != null) {
          buffer.writeln('Explanation: ${card.explanation}');
        }
        buffer.writeln('-' * 30);
        buffer.writeln();
      }

      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/flashcards_$timestamp.txt');
      await file.writeAsString(buffer.toString());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Flashcards: ${widget.title}',
      );

      // Clean up after delay
      Future.delayed(const Duration(seconds: 10), () {
        file.deleteSync();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Flashcards exported successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentCard = widget.flashcards[_currentIndex];

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 400,
        minHeight: 300,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header with counter and export button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card ${_currentIndex + 1} of ${widget.flashcards.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportFlashcards,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.download_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Flashcard content
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final isShowingFront = _flipAnimation.value < 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipAnimation.value * 3.14159),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isShowingFront
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(isShowingFront ? 0 : 3.14159),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isShowingFront) ...[
                                  Icon(
                                    Icons.help_outline,
                                    size: 32,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    currentCard.question,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Tap to reveal answer',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 32,
                                    color: theme.colorScheme.onSecondaryContainer
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    currentCard.answer,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (currentCard.explanation != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        currentCard.explanation!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSecondaryContainer
                                              .withOpacity(0.8),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Navigation controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _previousCard : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous card',
                ),
                Text(
                  _showAnswer ? 'Answer' : 'Question',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: _currentIndex < widget.flashcards.length - 1
                      ? _nextCard
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Next card',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
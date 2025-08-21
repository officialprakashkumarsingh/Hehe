import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/quiz_message_model.dart';

class QuizPreview extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String title;

  const QuizPreview({
    super.key,
    required this.questions,
    required this.title,
  });

  @override
  State<QuizPreview> createState() => _QuizPreviewState();
}

class _QuizPreviewState extends State<QuizPreview> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;
  int _correctAnswers = 0;
  final Map<int, int?> _userAnswers = {};
  bool _isExporting = false;
  bool _quizCompleted = false;

  void _selectAnswer(int index) {
    if (!_showResult) {
      setState(() {
        _selectedAnswer = index;
      });
    }
  }

  void _submitAnswer() {
    if (_selectedAnswer != null && !_showResult) {
      setState(() {
        _showResult = true;
        _userAnswers[_currentQuestionIndex] = _selectedAnswer;
        if (_selectedAnswer == widget.questions[_currentQuestionIndex].correctAnswer) {
          _correctAnswers++;
        }
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
        _showResult = _userAnswers.containsKey(_currentQuestionIndex);
      });
    } else if (!_quizCompleted) {
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
        _showResult = _userAnswers.containsKey(_currentQuestionIndex);
      });
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _showResult = false;
      _correctAnswers = 0;
      _userAnswers.clear();
      _quizCompleted = false;
    });
  }

  Future<void> _exportQuiz() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Show export notification with proper positioning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exporting quiz...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }

      // Create text content
      final buffer = StringBuffer();
      buffer.writeln('Quiz: ${widget.title}');
      buffer.writeln('=' * 40);
      buffer.writeln();

      // Add results if quiz is completed
      if (_userAnswers.isNotEmpty) {
        buffer.writeln('Your Score: $_correctAnswers/${widget.questions.length}');
        buffer.writeln('Percentage: ${(_correctAnswers / widget.questions.length * 100).toStringAsFixed(1)}%');
        buffer.writeln();
        buffer.writeln('-' * 40);
        buffer.writeln();
      }

      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];
        buffer.writeln('Question ${i + 1}: ${question.question}');
        buffer.writeln();
        
        for (int j = 0; j < question.options.length; j++) {
          final isCorrect = j == question.correctAnswer;
          final isUserAnswer = _userAnswers[i] == j;
          
          buffer.write('  ${String.fromCharCode(65 + j)}. ${question.options[j]}');
          if (isCorrect) buffer.write(' ✓ (Correct)');
          if (isUserAnswer && _userAnswers.isNotEmpty) {
            buffer.write(isCorrect ? ' - Your answer ✓' : ' - Your answer ✗');
          }
          buffer.writeln();
        }
        
        if (question.explanation != null) {
          buffer.writeln();
          buffer.writeln('Explanation: ${question.explanation}');
        }
        
        buffer.writeln();
        buffer.writeln('-' * 30);
        buffer.writeln();
      }

      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/quiz_$timestamp.txt');
      await file.writeAsString(buffer.toString());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz: ${widget.title}',
      );

      // Clean up after delay
      Future.delayed(const Duration(seconds: 10), () {
        file.deleteSync();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz exported successfully!'),
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
    
    if (_quizCompleted) {
      return _buildResultsView(theme);
    }

    final currentQuestion = widget.questions[_currentQuestionIndex];

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 500,
        minHeight: 400,
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
          // Header with progress and export button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (_currentQuestionIndex + 1) / widget.questions.length,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportQuiz,
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

          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentQuestion.question,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  ...List.generate(currentQuestion.options.length, (index) {
                    final isSelected = _selectedAnswer == index;
                    final isCorrect = index == currentQuestion.correctAnswer;
                    final showCorrect = _showResult && isCorrect;
                    final showWrong = _showResult && isSelected && !isCorrect;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: showCorrect
                            ? Colors.green.withOpacity(0.2)
                            : showWrong
                                ? Colors.red.withOpacity(0.2)
                                : isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: !_showResult ? () => _selectAnswer(index) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: showCorrect
                                        ? Colors.green
                                        : showWrong
                                            ? Colors.red
                                            : isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.outline.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: TextStyle(
                                        color: (showCorrect || showWrong || isSelected)
                                            ? Colors.white
                                            : theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    currentQuestion.options[index],
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                if (showCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green),
                                if (showWrong)
                                  const Icon(Icons.cancel, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Explanation (if showing result)
                  if (_showResult && currentQuestion.explanation != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Explanation',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentQuestion.explanation!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
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
              children: [
                IconButton(
                  onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous question',
                ),
                const Spacer(),
                if (!_showResult)
                  ElevatedButton(
                    onPressed: _selectedAnswer != null ? _submitAnswer : null,
                    child: const Text('Submit Answer'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: Icon(_currentQuestionIndex < widget.questions.length - 1
                        ? Icons.arrow_forward
                        : Icons.assessment),
                    label: Text(_currentQuestionIndex < widget.questions.length - 1
                        ? 'Next Question'
                        : 'View Results'),
                  ),
                const Spacer(),
                Text(
                  'Score: $_correctAnswers/${_userAnswers.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    final percentage = (_correctAnswers / widget.questions.length * 100);
    final isPassed = percentage >= 70;

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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPassed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quiz Results',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Material(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isExporting ? null : _exportQuiz,
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

          // Results content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPassed ? Icons.emoji_events : Icons.timer,
                    size: 64,
                    color: isPassed ? Colors.amber : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_correctAnswers / ${widget.questions.length}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPassed ? 'Great job! 🎉' : 'Keep practicing! 💪',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _quizCompleted = false;
                      _currentQuestionIndex = 0;
                      _selectedAnswer = _userAnswers[0];
                      _showResult = true;
                    });
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Review Answers'),
                ),
                ElevatedButton.icon(
                  onPressed: _resetQuiz,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake Quiz'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
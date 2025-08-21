import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/diagram_service.dart';
import 'diagram_preview.dart';

class MarkdownMessage extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isStreaming;

  const MarkdownMessage({
    super.key,
    required this.content,
    this.isUser = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      // User messages: simple text, no markdown
      return SelectableText(
        content,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          height: 1.4,
        ),
      );
    }

    // Check if content contains Mermaid diagram
    if (_containsMermaidDiagram(content)) {
      return _buildContentWithDiagram(context);
    }

    // AI messages: full markdown support
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context),
      onTapLink: (text, href, title) {
        // Handle link taps if needed
      },
    );
  }

  bool _containsMermaidDiagram(String text) {
    return text.contains('```mermaid') || 
           text.contains('```Mermaid') || 
           text.contains('```MERMAID');
  }

  Widget _buildContentWithDiagram(BuildContext context) {
    // Split content by mermaid blocks
    final parts = <Widget>[];
    final regex = RegExp(r'```mermaid\s*([\s\S]*?)```', caseSensitive: false);
    int lastEnd = 0;
    
    for (final match in regex.allMatches(content)) {
      // Add text before diagram
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start);
        if (textBefore.trim().isNotEmpty) {
          parts.add(
            MarkdownBody(
              data: textBefore,
              selectable: true,
              styleSheet: _buildMarkdownStyleSheet(context),
            ),
          );
        }
      }
      
      // Add diagram
      final mermaidCode = match.group(1)?.trim() ?? '';
      if (mermaidCode.isNotEmpty) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DiagramPreview(
              mermaidCode: mermaidCode,
            ),
          ),
        );
      }
      
      lastEnd = match.end;
    }
    
    // Add remaining text after last diagram
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd);
      if (textAfter.trim().isNotEmpty) {
        parts.add(
          MarkdownBody(
            data: textAfter,
            selectable: true,
            styleSheet: _buildMarkdownStyleSheet(context),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: parts,
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    
    return MarkdownStyleSheet(
      // Text styles
      p: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.5,
      ),
      h1: theme.textTheme.headlineLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      h2: theme.textTheme.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h3: theme.textTheme.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h4: theme.textTheme.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h5: theme.textTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h6: theme.textTheme.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      
      // Code styles
      code: GoogleFonts.jetBrainsMono(
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        color: textColor,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      
      // List styles
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
      ),
      
      // Quote styles
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: textColor.withOpacity(0.8),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      
      // Link styles
      a: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      
      // Table styles
      tableHead: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      tableBody: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
      ),
      
      // Emphasis styles
      strong: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      em: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
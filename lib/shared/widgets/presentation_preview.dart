import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../core/models/presentation_message_model.dart';

class PresentationPreview extends StatefulWidget {
  final List<PresentationSlide> slides;
  final String title;
  
  const PresentationPreview({
    super.key,
    required this.slides,
    required this.title,
  });
  
  @override
  State<PresentationPreview> createState() => _PresentationPreviewState();
}

class _PresentationPreviewState extends State<PresentationPreview> {
  int _currentSlide = 0;
  final PageController _pageController = PageController();
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _exportAsPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Generating presentation PDF...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.notoSansRegular(),
          bold: await PdfGoogleFonts.notoSansBold(),
          icons: await PdfGoogleFonts.notoColorEmoji(),
        ),
      );
      
      // Add slides to PDF
      for (int index = 0; index < widget.slides.length; index++) {
        final slide = widget.slides[index];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            build: (context) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Title with markdown support
                    pw.Text(
                      _cleanTextForPdf(slide.title),
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    
                    // Content
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (slide.content.isNotEmpty)
                            _buildPdfMarkdownContent(slide.content),
                          
                          if (slide.bulletPoints != null) ...[
                            pw.SizedBox(height: 20),
                            ...slide.bulletPoints!.map((point) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 10),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('• ', 
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blue,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      _cleanTextForPdf(point),
                                      style: const pw.TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          
                          // Speaker notes
                          if (slide.notes != null && slide.notes!.isNotEmpty) ...[
                            pw.SizedBox(height: 20),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Speaker Notes:',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.SizedBox(height: 5),
                                  pw.Text(
                                    _cleanTextForPdf(slide.notes!),
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      color: PdfColors.grey800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Footer with slide number
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          widget.title,
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                        ),
                        pw.Text(
                          'Slide ${widget.slides.indexOf(slide) + 1} of ${widget.slides.length}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
      
      // Save PDF
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/presentation_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Share PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Presentation: ${widget.title}',
      );
      
      // Clean up
      await file.delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Presentation exported successfully!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No slides generated',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header with controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.slideshow,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_currentSlide + 1} / ${widget.slides.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  onPressed: _exportAsPdf,
                  tooltip: 'Export as PDF',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          
          // Slide content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentSlide = index;
                });
              },
              itemCount: widget.slides.length,
              itemBuilder: (context, index) {
                final slide = widget.slides[index];
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slide title
                      Text(
                        slide.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Slide content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (slide.content.isNotEmpty)
                                MarkdownBody(
                                  data: slide.content,
                                  selectable: true,
                                ),
                              
                              if (slide.bulletPoints != null && slide.bulletPoints!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ...slide.bulletPoints!.map((point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Navigation controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentSlide > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                ),
                const SizedBox(width: 16),
                // Slide indicators
                Row(
                  children: List.generate(
                    widget.slides.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentSlide
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _currentSlide < widget.slides.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
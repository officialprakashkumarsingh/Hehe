import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/chart_service.dart';

class ChartPreview extends StatefulWidget {
  final String chartConfig;
  final String prompt;

  const ChartPreview({
    super.key,
    required this.chartConfig,
    required this.prompt,
  });

  @override
  State<ChartPreview> createState() => _ChartPreviewState();
}

class _ChartPreviewState extends State<ChartPreview> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
          // Chart display area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  InAppWebView(
                    initialData: InAppWebViewInitialData(
                      data: ChartService.generateChartHtml(
                        widget.chartConfig,
                        isDarkMode,
                      ),
                      mimeType: 'text/html',
                      encoding: 'utf-8',
                    ),
                    initialOptions: InAppWebViewGroupOptions(
                      crossPlatform: InAppWebViewOptions(
                        transparentBackground: true,
                        supportZoom: false,
                        disableHorizontalScroll: true,
                        disableVerticalScroll: false,
                        useShouldOverrideUrlLoading: true,
                      ),
                      android: AndroidInAppWebViewOptions(
                        useHybridComposition: true,
                        forceDark: isDarkMode 
                            ? AndroidForceDark.FORCE_DARK_ON 
                            : AndroidForceDark.FORCE_DARK_OFF,
                      ),
                      ios: IOSInAppWebViewOptions(
                        allowsInlineMediaPlayback: true,
                      ),
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      
                      // Add JavaScript handlers
                      controller.addJavaScriptHandler(
                        handlerName: 'chartReady',
                        callback: (args) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                              _hasError = false;
                            });
                          }
                        },
                      );
                      
                      controller.addJavaScriptHandler(
                        handlerName: 'chartError',
                        callback: (args) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                              _hasError = true;
                              _errorMessage = args.isNotEmpty ? args[0].toString() : 'Unknown error';
                            });
                          }
                        },
                      );
                    },
                    onLoadStop: (controller, url) async {
                      // Give it a moment to render
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted && _isLoading) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    onLoadError: (controller, url, code, message) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _hasError = true;
                          _errorMessage = message;
                        });
                      }
                    },
                  ),
                  
                  // Loading indicator
                  if (_isLoading)
                    Container(
                      color: theme.colorScheme.surface,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  
                  // Error display
                  if (_hasError)
                    Container(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load chart',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Export button
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _hasError || _isExporting) ? null : _exportAsImage,
                icon: _isExporting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(_isExporting ? 'Exporting...' : 'Export Chart'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsImage() async {
    if (_webViewController == null) return;
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      // Show export notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exporting chart...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Take screenshot of the WebView
      final Uint8List? screenshot = await _webViewController!.takeScreenshot();
      
      if (screenshot != null) {
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/chart_$timestamp.png');
        await file.writeAsBytes(screenshot);
        
        // Share the image
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Chart: ${widget.prompt}',
        );
        
        // Clean up temp file after a delay
        Future.delayed(const Duration(seconds: 10), () {
          file.deleteSync();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chart exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to capture chart');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export chart: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/prompt_enhancer_service.dart';
import '../../../shared/widgets/prompt_enhancer.dart';
import 'diagram_generator_dialog.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String, {bool useWebSearch}) onSendMessage;
  final Function(String)? onGenerateImage;
  final Function(String, String)? onVisionAnalysis;
  final VoidCallback? onStopStreaming;
  final VoidCallback? onTemplateRequest;
  final String selectedModel;
  final bool isLoading;
  final bool enabled;

  const ChatInput({
    super.key,
    this.controller,
    required this.onSendMessage,
    this.onGenerateImage,
    this.onVisionAnalysis,
    this.onStopStreaming,
    this.onTemplateRequest,
    this.selectedModel = '',
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;
  bool _shouldDisposeController = false;
  bool _showEnhancerSuggestion = false;
  bool _webSearchEnabled = false;
  bool _imageGenerationMode = false;
  String? _pendingImageData;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _shouldDisposeController = true;
    }
    _controller.addListener(_updateSendButton);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_shouldDisposeController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _updateSendButton() {
    final canSend = _controller.text.trim().isNotEmpty && 
                   widget.enabled && 
                   !widget.isLoading;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _startEnhancerTimer() {
    _typingTimer?.cancel();
    
    if (widget.selectedModel.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _focusNode.hasFocus) {
          final text = _controller.text.trim();
          if (text.isNotEmpty && PromptEnhancerService.shouldSuggestEnhancement(text)) {
            setState(() {
              _showEnhancerSuggestion = true;
            });
          }
        }
      });
    }
  }

  void _onInputTapped() {
    setState(() {
      _showEnhancerSuggestion = false;
    });
    _startEnhancerTimer();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _startEnhancerTimer();
    } else {
      _typingTimer?.cancel();
      setState(() {
        _showEnhancerSuggestion = false;
      });
    }
  }

  void _handleSend() {
    if (!_canSend) return;
    
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _updateSendButton();
    
    // Check if there's pending image data for vision analysis
    if (_pendingImageData != null && widget.onVisionAnalysis != null) {
      widget.onVisionAnalysis!(message, _pendingImageData!);
      _pendingImageData = null; // Clear after use
    } else {
      widget.onSendMessage(message, useWebSearch: _webSearchEnabled);
    }
    
    HapticFeedback.lightImpact();
  }

  void _handleStop() {
    if (widget.onStopStreaming != null) {
      widget.onStopStreaming!();
      HapticFeedback.mediumImpact();
    }
  }

  void _showPromptEnhancer() {
    final originalPrompt = _controller.text.trim();
    if (originalPrompt.isEmpty) return;

    setState(() {
      _showEnhancerSuggestion = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: PromptEnhancer(
          originalPrompt: originalPrompt,
          selectedModel: widget.selectedModel,
          onEnhanced: (enhancedPrompt) {
            _controller.text = enhancedPrompt;
            Navigator.pop(context);
            HapticFeedback.lightImpact();
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input area - completely transparent
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SafeArea(
            child: Row(
              children: [
                // Extensions button
                IconButton(
                  onPressed: _showExtensionsSheet,
                  icon: Icon(
                    Icons.extension_outlined,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                  tooltip: 'Extensions',
                ),
                
                // Text input - no background
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onTap: _onInputTapped,
                    decoration: InputDecoration(
                      hintText: widget.enabled 
                          ? (_pendingImageData != null
                              ? '📸 Ask something about the uploaded image...'
                              : _imageGenerationMode 
                                  ? 'Describe the image you want to generate...' 
                                  : 'Type your message...') 
                          : 'Select a model to start chatting',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Send/Stop button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  child: Material(
                    color: widget.isLoading
                        ? Colors.red
                        : (_canSend 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: widget.isLoading ? _handleStop : (_canSend ? (_imageGenerationMode ? _handleImageGenerationDirect : _handleSend) : null),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        child: Icon(
                          widget.isLoading
                              ? Icons.stop_rounded
                              : (_imageGenerationMode ? Icons.auto_awesome_outlined : Icons.arrow_upward_rounded),
                          color: widget.isLoading
                              ? Colors.white
                              : (_canSend
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
                  ),
      ],
    );
  }

  void _handleImageGeneration() {
    // This method is no longer used as popup is removed
  }

  void _handleImageGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateImage != null) {
      widget.onGenerateImage!(prompt);
      _controller.clear();
      setState(() {
        _imageGenerationMode = false;
      });
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _showExtensionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExtensionsBottomSheet(
        webSearchEnabled: _webSearchEnabled,
        imageGenerationMode: _imageGenerationMode,
        onImageUpload: () async {
          Navigator.pop(context);
          await _handleImageUpload();
        },
        onWebSearchToggle: (enabled) {
          setState(() {
            _webSearchEnabled = enabled;
            if (enabled) _imageGenerationMode = false;
          });
          Navigator.pop(context);
        },
        onImageModeToggle: (enabled) {
          setState(() {
            _imageGenerationMode = enabled;
            if (enabled) _webSearchEnabled = false;
          });
          Navigator.pop(context);
        },
        onEnhancePrompt: () {
          Navigator.pop(context);
          _showPromptEnhancer();
        },
        onDiagramGeneration: () async {
          Navigator.pop(context);
          await _showDiagramGenerator();
        },
      ),
    );
  }

  Future<void> _showDiagramGenerator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const DiagramGeneratorDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      // Insert the diagram code into the message
      final currentText = _controller.text;
      final newText = currentText.isEmpty 
          ? '```mermaid\n$result\n```'
          : '$currentText\n\n```mermaid\n$result\n```';
      
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  Future<void> _handleImageUpload() async {
    try {
      // Show image source selection
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ImageSourceSelector(),
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image != null) {
          // Convert image to base64
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64Image';

          // Show success message and prompt user to type in input
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📸 Image uploaded! Type your question in the input area and send.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );

          // Store the image data temporarily for the next message
          _pendingImageData = dataUrl;
          _focusNode.requestFocus();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _ExtensionsBottomSheet extends StatelessWidget {
  final bool webSearchEnabled;
  final bool imageGenerationMode;
  final VoidCallback onImageUpload;
  final Function(bool) onWebSearchToggle;
  final Function(bool) onImageModeToggle;
  final VoidCallback onEnhancePrompt;
  final VoidCallback onDiagramGeneration;

  const _ExtensionsBottomSheet({
    required this.webSearchEnabled,
    required this.imageGenerationMode,
    required this.onImageUpload,
    required this.onWebSearchToggle,
    required this.onImageModeToggle,
    required this.onEnhancePrompt,
    required this.onDiagramGeneration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Options
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                // Image Upload & Analysis
                _ExtensionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Analyse Image',
                  subtitle: '',
                  iconSize: 24,
                  onTap: onImageUpload,
                ),
                
                const SizedBox(height: 12),
                
                // Enhance Prompt
                _ExtensionTile(
                  icon: Icons.auto_fix_high,
                  title: 'Enhance Prompt',
                  subtitle: 'Improve your prompt with AI for better results',
                  iconSize: 20,
                  onTap: onEnhancePrompt,
                ),
                
                const SizedBox(height: 12),
                
                // Web Search
                _ExtensionTile(
                  icon: Icons.search_outlined,
                  title: 'Web Search',
                  subtitle: 'Include real-time web search in responses',
                  isToggled: webSearchEnabled,
                  iconSize: 20,
                  onTap: () => onWebSearchToggle(!webSearchEnabled),
                ),
                
                const SizedBox(height: 12),
                
                // Image Generation
                _ExtensionTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Image Generation',
                  subtitle: 'Generate images from text descriptions',
                  isToggled: imageGenerationMode,
                  iconSize: 20,
                  onTap: () => onImageModeToggle(!imageGenerationMode),
                ),
                
                const SizedBox(height: 12),
                
                // Diagram Generation
                _ExtensionTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Diagram Generation',
                  subtitle: 'Create flowcharts, sequence diagrams, and more',
                  iconSize: 20,
                  onTap: onDiagramGeneration,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isToggled;
  final double iconSize;
  final VoidCallback onTap;

  const _ExtensionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isToggled = false,
    this.iconSize = 20,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isToggled 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isToggled
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: iconSize,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isToggled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isToggled)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSourceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Camera option
                _ExtensionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Capture image with camera',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                
                const SizedBox(height: 12),
                
                // Gallery option
                _ExtensionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select image from your photos',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
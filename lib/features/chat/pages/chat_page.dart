import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/template_service.dart';
import '../../../core/services/message_mode_service.dart';
import '../../../core/services/model_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/web_search_service.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/vision_service.dart';
import '../../../core/models/image_message_model.dart';
import '../../../core/models/vision_message_model.dart';
import '../../../core/models/diagram_message_model.dart';
import '../../../core/services/diagram_service.dart';
import '../../../shared/widgets/animated_robot.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/template_selector.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  
  bool _isLoading = false;
  bool _showTemplates = false;
  bool _showScrollToBottom = false;
  bool _userIsScrolling = false;
  bool _autoScrollEnabled = true;
  
  // For stopping streams
  Stream<String>? _currentStream;

  @override
  void initState() {
    super.initState();
    ModelService.instance.loadModels();
    ImageService.instance.loadModels();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final isAtBottom = _scrollController.offset >= 
                     _scrollController.position.maxScrollExtent - 100;
    
    // Detect if user is manually scrolling
    if (_scrollController.position.isScrollingNotifier.value) {
      _userIsScrolling = true;
      // Re-enable auto scroll if user scrolls to bottom
      if (isAtBottom) {
        _autoScrollEnabled = true;
        _userIsScrolling = false;
      } else {
        _autoScrollEnabled = false;
      }
    }
    
    if (isAtBottom != !_showScrollToBottom) {
      setState(() {
        _showScrollToBottom = !isAtBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ModelService.instance,
      builder: (context, _) {
        final modelService = ModelService.instance;
        
        return Stack(
          children: [
            Column(
              children: [
                // Chat messages
                Expanded(
                  child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
                ),

                // Templates quick access
                if (_showTemplates)
                  _buildTemplateQuickAccess(),

                            // Input area
            ChatInput(
              controller: _inputController,
              selectedModel: modelService.selectedModel,
              onSendMessage: _handleSendMessage,
              onGenerateImage: _handleImageGeneration,
              onGenerateDiagram: _handleDiagramGeneration,
              onVisionAnalysis: _handleVisionAnalysis,
              onStopStreaming: _stopStreaming,
              onTemplateRequest: () {
                setState(() {
                  _showTemplates = !_showTemplates;
                });
              },
              isLoading: _isLoading,
              enabled: modelService.selectedModel.isNotEmpty && !modelService.isLoading,
            ),
              ],
            ),
        
        // Scroll to bottom button - hide during streaming
        if (_showScrollToBottom && !_isLoading)
          Positioned(
            bottom: 120, // Higher above input area
            right: 16,
            child: AnimatedScale(
              scale: _showScrollToBottom && !_isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.2),
                child: InkWell(
                  onTap: _scrollToBottom,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedRobot(
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything and I\'ll help you out!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Template shortcut button
          Material(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showTemplateSelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Browse Templates',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateQuickAccess() {
    final recentTemplates = TemplateService.instance.templates.take(5).toList();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentTemplates.length + 1, // +1 for "More" button
        itemBuilder: (context, index) {
          if (index == recentTemplates.length) {
            // More button
            return Container(
              margin: const EdgeInsets.only(left: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _showTemplateSelector,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'More',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          
          final template = recentTemplates[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _handleTemplateSelection(template.content),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    template.shortcut,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTemplateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TemplateSelector(
        onTemplateSelected: _handleTemplateSelection,
      ),
    );
  }

  void _handleTemplateSelection(String templateContent) {
    _inputController.text = templateContent;
    setState(() {
      _showTemplates = false;
    });
  }

  void _stopStreaming() {
    setState(() {
      _isLoading = false;
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        final lastMessage = _messages.last;
        _messages[_messages.length - 1] = lastMessage.copyWith(
          isStreaming: false,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MessageBubble(
            message: message,
            modelName: ModelService.instance.selectedModel,
            onCopy: () => _copyMessage(message),
            onRegenerate: message.type == MessageType.assistant
                ? () => _regenerateMessage(index)
                : null,
            onExport: () => _exportMessage(message, index),
          ),
        );
      },
    );
  }

  Future<void> _handleSendMessage(String content, {bool useWebSearch = false}) async {
    final modelService = ModelService.instance;
    
    // Determine which models to use
    List<String> modelsToUse;
    if (modelService.multipleModelsEnabled && modelService.selectedModels.isNotEmpty) {
      modelsToUse = modelService.selectedModels;
    } else {
      modelsToUse = [modelService.selectedModel];
    }
    
    if (content.trim().isEmpty || modelsToUse.isEmpty || modelsToUse.first.isEmpty) return;

    final userMessage = Message.user(content.trim());
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    // Get conversation history
    final history = _messages
        .where((m) => !m.isStreaming && !m.hasError)
        .map((m) => m.toApiFormat())
        .toList();

    // Remove the last user message from history to avoid duplication
    if (history.isNotEmpty && history.last['role'] == 'user') {
      history.removeLast();
    }

    try {
      // Handle web search if enabled
      String enhancedContent = content.trim();
      if (useWebSearch) {
        // Show searching indicator
        final searchingMessage = Message.assistant('🔍 Searching the web...', isStreaming: true);
        setState(() {
          _messages.add(searchingMessage);
        });
        
        // Perform web search
        final searchResults = await WebSearchService.search(query: content.trim());
        final searchData = WebSearchService.formatSearchResults(searchResults);
        final currentDateTime = WebSearchService.getCurrentDateTime();
        
        // Update content with search results and current time
        enhancedContent = '''$currentDateTime

Web Search Results for: "$content"

$searchData

Based on the above current information and search results, please provide a comprehensive response to: "$content"''';
        
        // Remove searching indicator
        setState(() {
          _messages.removeLast();
        });
      }
      
      // Handle multiple models or single model
      for (int i = 0; i < modelsToUse.length; i++) {
        final model = modelsToUse[i];
        
        // Create assistant message for each model
        final assistantMessage = Message.assistant('', isStreaming: true);
        setState(() {
          _messages.add(assistantMessage);
        });
        
        // Start response for this model
        _handleModelResponse(
          enhancedContent,
          model,
          history,
          _messages.length - 1,
          modelsToUse.length,
          i,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(Message.error(
            'Sorry, I encountered an error. Please try again.',
          ));
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleModelResponse(
    String content,
    String model,
    List<Map<String, String>> history,
    int messageIndex,
    int totalModels,
    int modelIndex,
  ) async {
    try {
      final stream = await ApiService.sendMessage(
        message: content,
        model: model,
        conversationHistory: history,
        systemPrompt: MessageModeService.instance.effectiveSystemPrompt,
      );

      String accumulatedContent = '';
      
      // Add model name header for multiple models
      if (totalModels > 1) {
        accumulatedContent = '**${_formatModelName(model)}:**\n\n';
      }
      
      int chunkCount = 0;
      await for (final chunk in stream) {
        if (!mounted) break;
        
        accumulatedContent += chunk;
        chunkCount++;
        
        if (messageIndex < _messages.length) {
          setState(() {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              content: accumulatedContent,
              isStreaming: true,
            );
          });
        }
        
        // Smooth auto-scroll during streaming
        if (chunkCount % 2 == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Only auto-scroll if user hasn't manually scrolled away
            if (_autoScrollEnabled && _scrollController.hasClients && !_userIsScrolling) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              final currentScroll = _scrollController.offset;
              
              // Smooth scroll to bottom if we're close (within 200 pixels)
              if (maxScroll - currentScroll < 200) {
                _scrollController.animateTo(
                  maxScroll,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.linear,
                );
              }
            }
          });
        }
      }

      // Mark streaming as complete
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            content: accumulatedContent,
            isStreaming: false,
          );
          
          // Set loading to false when last model completes
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = Message.error(
            'Error from ${_formatModelName(model)}: Please try again.',
          );
          
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    }
  }

  String _formatModelName(String model) {
    return model
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _regenerateMessage(int messageIndex) async {
    if (messageIndex <= 0 || messageIndex >= _messages.length) return;

    // Find the user message before this assistant message
    final userMessage = _messages[messageIndex - 1];
    if (userMessage.type != MessageType.user) return;

    // Remove the current assistant message
    setState(() {
      _messages.removeAt(messageIndex);
    });

    // Regenerate the response
    await _handleSendMessage(userMessage.content);
  }

  void _copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 100,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportMessage(Message message, int index) async {
    // Find the corresponding user message for AI responses
    String userMessage = '';
    String aiResponse = message.content;
    
    if (message.type == MessageType.assistant && index > 0) {
      final previousMessage = _messages[index - 1];
      if (previousMessage.type == MessageType.user) {
        userMessage = previousMessage.content;
      }
    } else if (message.type == MessageType.user) {
      userMessage = message.content;
      // Find the next AI response
      if (index + 1 < _messages.length) {
        final nextMessage = _messages[index + 1];
        if (nextMessage.type == MessageType.assistant) {
          aiResponse = nextMessage.content;
        }
      }
    }
    
    // Handle different export types based on message type
    if (message is ImageMessage) {
      // Export image message
      await ExportService.exportGeneratedImage(
        context: context,
        imageUrl: message.imageUrl,
        prompt: message.prompt,
        model: message.model,
      );
    } else {
      // Export text message
      await ExportService.exportMessageAsImage(
        context: context,
        userMessage: userMessage,
        aiResponse: aiResponse,
        modelName: ModelService.instance.selectedModel,
      );
    }
  }

  Future<void> _handleVisionAnalysis(String prompt, String imageData) async {
    if (prompt.trim().isEmpty) return;
    
    final selectedModel = ModelService.instance.selectedModel;
    if (selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a model first'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // For vision analysis, always get the best available vision model dynamically
    final bestVisionModel = await VisionService.getBestVisionModel();
    if (bestVisionModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No vision models available'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Add user message with image info
    final userMessage = VisionMessage.user(
      prompt: prompt,
      imageData: imageData,
      model: bestVisionModel,
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Add AI response placeholder
      final aiMessage = Message.assistant('');
      setState(() {
        _messages.add(aiMessage);
      });

      final messageIndex = _messages.length - 1;

      // Get vision analysis stream
      final stream = await VisionService.analyzeImage(
        prompt: prompt,
        imageData: imageData,
        model: bestVisionModel,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        if (mounted) {
          fullResponse += chunk;
          setState(() {
            _messages[messageIndex] = Message.assistant(fullResponse);
          });
          _scrollToBottom();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_messages.isNotEmpty && _messages.last.type == MessageType.assistant) {
            _messages[_messages.length - 1] = Message.assistant(
              'Sorry, I encountered an error while analyzing the image. Please try again.',
            );
          }
        });
      }
    }
  }

  Future<void> _handleImageGeneration(String prompt) async {
    final imageService = ImageService.instance;
    
    // Determine which image models to use
    List<String> modelsToUse;
    if (imageService.multipleModelsEnabled && imageService.selectedModels.isNotEmpty) {
      modelsToUse = imageService.selectedModels;
    } else {
      modelsToUse = [imageService.selectedModel];
    }
    
    if (prompt.trim().isEmpty || modelsToUse.isEmpty || modelsToUse.first.isEmpty) return;

    // Add user message
    final userMessage = Message.user('Generate image: $prompt');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Handle multiple image models or single model
      for (int i = 0; i < modelsToUse.length; i++) {
        final model = modelsToUse[i];
        
        // Create image message for each model
        final imageMessage = ImageMessage.generating(prompt, model);
        setState(() {
          _messages.add(imageMessage);
        });
        
        // Start image generation for this model
        _handleImageModelResponse(
          prompt,
          model,
          _messages.length - 1,
          modelsToUse.length,
          i,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(Message.error(
            'Sorry, I encountered an error generating the image.',
          ));
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDiagramGeneration(String prompt) async {
    if (prompt.trim().isEmpty) return;
    
    final userMessage = Message.user('Create a diagram: $prompt');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      // Reset auto-scroll for new message
      _autoScrollEnabled = true;
      _userIsScrolling = false;
    });
    
    _scrollToBottom();
    
    try {
      // Generate diagram using AI
      final diagramPrompt = '''Create a Mermaid diagram for: $prompt
      
Requirements:
1. Generate ONLY valid Mermaid code
2. Start directly with the diagram type (graph, flowchart, sequenceDiagram, etc.)
3. Do NOT include markdown code blocks or any explanations
4. Make it clear and well-structured
5. Use appropriate labels and connections

Example formats:
- Flowchart: graph TD or flowchart TD
- Sequence: sequenceDiagram
- Gantt: gantt
- Pie: pie title
- Class: classDiagram

Generate the Mermaid code now:''';
      
      final stream = await ApiService.sendMessage(
        message: diagramPrompt,
        model: ModelService.instance.selectedModel,
      );
      
      String mermaidCode = '';
      await for (final chunk in stream) {
        mermaidCode += chunk;
      }
      
      // Extract and clean the Mermaid code
      mermaidCode = DiagramService.extractMermaidCode(mermaidCode);
      
      // Fix common issues
      if (mermaidCode.isNotEmpty) {
        mermaidCode = DiagramService.fixCommonIssues(mermaidCode);
      }
      
      // Add diagram message
      final diagramMessage = DiagramMessage.assistant(
        prompt: prompt,
        mermaidCode: mermaidCode,
      );
      
      setState(() {
        _messages.add(diagramMessage);
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message.error(
          'Sorry, I encountered an error generating the diagram. Please try again.',
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _handleImageModelResponse(
    String prompt,
    String model,
    int messageIndex,
    int totalModels,
    int modelIndex,
  ) async {
    try {
      final imageUrl = await ImageService.generateImage(
        prompt: prompt,
        model: model,
      );

      if (mounted && messageIndex < _messages.length) {
        if (imageUrl != null) {
          // Success - update with completed image
          setState(() {
            _messages[messageIndex] = ImageMessage.completed(prompt, model, imageUrl);
            
            // Set loading to false when last model completes
            if (modelIndex == totalModels - 1) {
              _isLoading = false;
            }
          });
        } else {
          // Failed - show error
          setState(() {
            _messages[messageIndex] = ImageMessage.error(
              prompt, 
              model, 
              'Failed to generate image'
            );
            
            if (modelIndex == totalModels - 1) {
              _isLoading = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = ImageMessage.error(
            prompt,
            model,
            'Error: $e',
          );
          
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    }
  }

}
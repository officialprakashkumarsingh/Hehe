import 'message_model.dart';

class DiagramMessage extends Message {
  final String prompt;
  final String mermaidCode;
  
  DiagramMessage({
    required String id,
    required this.prompt,
    required this.mermaidCode,
    required DateTime timestamp,
    bool isStreaming = false,
    bool hasError = false,
  }) : super(
    id: id,
    content: mermaidCode,
    type: MessageType.assistant,
    timestamp: timestamp,
    isStreaming: isStreaming,
    hasError: hasError,
  );
  
  DiagramMessage.user({
    required this.prompt,
    this.mermaidCode = '',
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: prompt,
    type: MessageType.user,
    timestamp: DateTime.now(),
  );
  
  DiagramMessage.assistant({
    required this.prompt,
    required this.mermaidCode,
  }) : super(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: mermaidCode,
    type: MessageType.assistant,
    timestamp: DateTime.now(),
  );
  
  DiagramMessage copyWith({
    String? prompt,
    String? mermaidCode,
    bool? isStreaming,
    bool? hasError,
  }) {
    return DiagramMessage(
      id: id,
      prompt: prompt ?? this.prompt,
      mermaidCode: mermaidCode ?? this.mermaidCode,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
    );
  }
}
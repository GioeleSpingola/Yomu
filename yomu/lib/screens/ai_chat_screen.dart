import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../yomu_colors.dart';
import '../Lingue/app_localizations.dart';

class AiChatScreen extends StatefulWidget {
  final String? currentContext;
  const AiChatScreen({super.key, this.currentContext});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isInit = false;

  // ⚠️ RIMETTI QUI LA TUA CHIAVE DI GROQ ⚠️
  final String _groqApiKey = 'INSERISCI_LA_CHIAVE_QUI';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      _loadChatHistory(); // Carica i vecchi messaggi all'avvio assicurandosi di avere il context per le lingue!
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Memoria Locale (Il trucco magico) ────────────────────────────────────
  Future<void> _loadChatHistory() async {
    final loc = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final String? savedChat = prefs.getString('ai_chat_history');
    
    if (savedChat != null) {
      // Se c'è una chat salvata, la decodifica dal formato JSON
      final List<dynamic> decoded = json.decode(savedChat);
      setState(() {
        _messages = decoded.map((e) => {
          'role': e['role'].toString(),
          'content': e['content'].toString(),
        }).toList();
      });
      _scrollToBottom();
    } else {
      // Se è la prima volta in assoluto, mette il messaggio di benvenuto
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': loc.translate('chat_welcome')
        });
      });
      _saveChatHistory();
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Trasforma tutta la lista di messaggi in una stringa e la salva nel telefono
    await prefs.setString('ai_chat_history', json.encode(_messages));
  }

  void _clearChat() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        title: Text(loc.translate('chat_clear_title'), style: TextStyle(color: YomuColors.onSurface, fontWeight: FontWeight.bold)),
        content: Text(loc.translate('chat_clear_desc'), style: TextStyle(color: YomuColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text(loc.translate('common_cancel'), style: TextStyle(color: YomuColors.onSurfaceVariant))
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: YomuColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('ai_chat_history'); // Cancella la memoria dal telefono
              
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': loc.translate('chat_memory_cleared')
                });
              });
              _saveChatHistory();
            },
            child: Text(loc.translate('common_clear'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Logica API ───────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final loc = AppLocalizations.of(context)!;
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    
    _saveChatHistory(); // Salva appena l'utente invia il messaggio
    _msgController.clear();
    _scrollToBottom();

    try {
      String systemPrompt = 'Sei Yomu AI, un assistente virtuale integrato in una fantastica app di manga. Rispondi sempre in italiano. Sii conciso, amichevole e appassionato. Usa le tue conoscenze per consigliare ottimi manga all\'utente in base alle sue richieste. Non usare formattazioni troppo complesse.';
      if (widget.currentContext != null) {
        systemPrompt += ' L\'utente sta attualmente visualizzando il manga ${widget.currentContext}. Usa questa informazione per contestualizzare i tuoi consigli o rispondere alle sue domande.';
      }

      final List<Map<String, String>> apiMessages = [
        {
          'role': 'system',
          'content': systemPrompt
        }
      ];
      apiMessages.addAll(_messages); // Passiamo la cronologia intera all'AI

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'llama-3.3-70b-versatile', 
          'messages': apiMessages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiReply = data['choices'][0]['message']['content'];
        
        setState(() {
          _messages.add({'role': 'assistant', 'content': aiReply});
          _isLoading = false;
        });
        _saveChatHistory(); // Salva la risposta dell'AI
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '${loc.translate('chat_server_error')} (Error ${response.statusCode})'});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': loc.translate('chat_connection_error')});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  Widget _buildMessageBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final content = msg['content'] ?? '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? YomuColors.primary.withOpacity(0.15)
              : YomuColors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? YomuColors.primary.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: SelectableText(
          content,
          style: TextStyle(
            color: isUser ? YomuColors.onSurface : YomuColors.onSurfaceVariant,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: YomuColors.surface.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: YomuColors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: YomuColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Yomu AI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: YomuColors.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: YomuColors.onSurfaceVariant),
            tooltip: loc.translate('chat_tooltip_clear'),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Area Messaggi ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // ── Barra di caricamento e Input ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: YomuColors.surface,
              border: Border(
                top: BorderSide(color: YomuColors.outlineVariant.withOpacity(0.2)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: YomuColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: YomuColors.outlineVariant.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: YomuColors.onSurface, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: loc.translate('chat_hint'),
                          hintStyle: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isLoading ? YomuColors.surfaceContainerHigh : YomuColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                color: YomuColors.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: YomuColors.onPrimary,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
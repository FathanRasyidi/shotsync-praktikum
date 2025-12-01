import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/profile_avatar.dart';

/// Controller untuk AI Chat Page - ngatur semua logic chat dengan AI
class AIChatController extends GetxController {
  var messages = <ChatMessage>[]
      .obs; // List semua pesan (user dan AI), pake .obs biar reactive
  var isLoading = false.obs; // Status loading pas AI lagi mikir
  final TextEditingController messageController =
      TextEditingController(); // Controller buat input text
  var currentUserId = ''.obs; // ID user yang lagi login
  var currentUserName = ''.obs; // Nama user yang lagi login

  // Ambil API Key dari file .env (API key Gemini disimpen disini biar aman)
  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Endpoint API Google Gemini - model gemini-2.0-flash (model terbaru dan cepet)
  final String apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    // Pas pertama kali dibuka, langsung tambahin welcome message dari AI
    messages.add(
      ChatMessage(
        text: 'Halo!\nIngin membuat ide apa hari ini?',
        isUser: false, // Ini dari AI, bukan dari user
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Load data user dari SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUserId.value = prefs.getString('user_id') ?? '';
      currentUserName.value = prefs.getString('user_name') ?? 'User';
    } catch (e) {
      currentUserId.value = '';
      currentUserName.value = 'User';
    }
  }

  @override
  void onClose() {
    messageController.dispose(); // Bersihin controller biar ga memory leak
    super.onClose();
  }

  /// Kirim pertanyaan ke AI dan dapetin jawabannya
  /// Ini yang handle semua komunikasi dengan Google Gemini API
  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty)
      return; // Kalo kosong, jangan kirim

    final userMessage = messageController.text.trim(); // Ambil text dari input
    messageController.clear(); // Kosongin input box

    // Tambahin pesan user ke list (langsung muncul di UI)
    messages.add(
      ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
    );

    // Tampilkan loading indicator "AI is thinking..."
    isLoading.value = true;

    try {
      // Cek dulu API key ada atau ngga
      if (apiKey.isEmpty) {
        messages.add(
          ChatMessage(
            text:
                'AI service is not configured. Please add GEMINI_API_KEY to .env file.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        isLoading.value = false;
        return;
      }

      // Bikin request body sesuai format API Gemini
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                // Prompt: kasih tau AI siapa dia dan apa tugasnya
                'text':
                    'You are a helpful AI assistant specialized in film production. You help with scene planning, shot lists, equipment recommendations, scheduling, and creative filmmaking advice. Please answer this question: $userMessage',
              },
            ],
          },
        ],
        // Config buat ngatur gimana AI jawab
        'generationConfig': {
          'temperature': 0.7, // Kreativitas (0.0 = strict, 1.0 = creative)
          'topK': 40, // Limit pilihan kata
          'topP': 0.95, // Probabilitas sampling
          'maxOutputTokens': 2048, // Max panjang jawaban (token = kata)
        },
        // Safety settings biar AI ga ngasih jawaban yang berbahaya/toxic
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
          },
        ],
      };

      print('Sending request to Gemini API...');

      // Kirim POST request ke Google Gemini API
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json', // JSON request
          'X-goog-api-key': apiKey, // API key di header (bukan query param)
        },
        body: jsonEncode(requestBody), // Convert Map jadi JSON string
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Kalo response OK (200)
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // Parse JSON response

        // Cek apakah response punya jawaban yang valid
        // Structure: data['candidates'][0]['content']['parts'][0]['text']
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          // Ambil text jawaban dari AI
          final aiText =
              data['candidates'][0]['content']['parts'][0]['text'] as String;

          // Tambahin jawaban AI ke list (otomatis muncul di UI)
          messages.add(
            ChatMessage(text: aiText, isUser: false, timestamp: DateTime.now()),
          );
        } else {
          // Kalo response ga valid (ga ada candidates)
          messages.add(
            ChatMessage(
              text:
                  'Sorry, I couldn\'t generate a response. Please try rephrasing your question.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        // Kalo error (400, 404, 500, dll) - tampilkan detail error
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';

        print('API Error: $errorMessage');

        messages.add(
          ChatMessage(
            text:
                'Sorry, I encountered an error: $errorMessage (${response.statusCode})',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // Kalo ada error network atau parsing (ga bisa connect, timeout, dll)
      print('Exception in AI chat: $e');
      messages.add(
        ChatMessage(
          text:
              'Sorry, I couldn\'t connect to the AI service. Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      isLoading.value = false; // Matiin loading indicator
    }
  }
}

/// Model buat ChatMessage AI - lebih simple dari project chat
/// Ga perlu read_by tracking karena cuma solo chat dengan AI
class ChatMessage {
  final String text; // Isi pesan
  final bool isUser; // true = dari user, false = dari AI
  final DateTime timestamp; // Kapan pesannya dibuat

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// AI Chat Page
class AIChatPage extends StatelessWidget {
  const AIChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AIChatController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F1828),

      body: Column(
        children: [
          // Messages List - Area tampilan chat
          Expanded(
            child: Obx(() {
              // Kalo belum ada pesan (harusnya ga mungkin karena ada welcome message)
              if (controller.messages.isEmpty) {
                return const Center(
                  child: Text(
                    'Start a conversation',
                    style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 16),
                  ),
                );
              }

              // Tampilkan semua pesan dalam list
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  final message = controller.messages[index];
                  return _buildMessageBubble(
                    message,
                  ); // Build bubble per message
                },
              );
            }),
          ),

          // Input Field - Area buat ngetik pertanyaan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF152033),
              border: Border(
                top: BorderSide(color: Color(0xFF1F2937), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Text field buat ngetik pertanyaan
                  Expanded(
                    child: TextField(
                      controller: controller.messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...', // Placeholder
                        hintStyle: const TextStyle(color: Color(0xFF8B8B8B)),
                        filled: true,
                        fillColor: const Color(0xFF0F1828),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null, // Bisa multiline
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) =>
                          controller.sendMessage(), // Enter = kirim
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Send dengan gradient biru atau loading indicator
                  Obx(
                    () => Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF00D9FF)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: controller.isLoading.value
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed:
                                  controller.sendMessage, // Klik = kirim ke AI
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

  // Build message bubble - tampilan chat bubble
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        // Pesan user di kanan, pesan AI di kiri
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar AI (kalo bukan pesan user)
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF2196F3)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF152033),
                borderRadius: BorderRadius.circular(16),
                border: message.isUser
                    ? null
                    : Border.all(color: const Color(0xFF1F2937), width: 1),
              ),
              child: message.isUser
                  ? Text(
                      // Pesan user: plain text biasa
                      message.text,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  : MarkdownBody(
                      // Pesan AI: pake MarkdownBody biar support formatting
                      // **bold**, *italic*, `code`, # heading, - bullet, dll
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, fontSize: 14),
                        strong: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        em: const TextStyle(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          color: const Color(0xFF00D9FF),
                          backgroundColor: const Color(0xFF0F1828),
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF0F1828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquote: const TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontStyle: FontStyle.italic,
                        ),
                        h1: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: const TextStyle(color: Color(0xFF00D9FF)),
                      ),
                    ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Obx(() {
              final controller = Get.find<AIChatController>();
              return ProfileAvatar(
                userId: controller.currentUserId.value,
                userName: controller.currentUserName.value,
                radius: 16,
                backgroundColor: const Color(0xFF2196F3),
              );
            }),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class TerraChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> field;
  final Map<String, dynamic> crop;
  final double soilMoist;
  final double soilTemp;

  const TerraChatScreen({
    super.key,
    required this.user,
    required this.field,
    required this.crop,
    required this.soilMoist,
    required this.soilTemp,
  });

  @override
  State<TerraChatScreen> createState() => _TerraChatScreenState();
}

class _TerraChatScreenState extends State<TerraChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(
      ChatMessage(
        text: 'Merhaba ${widget.user['name']}! Ben Tarla Gözcüsü\'nün yapay zeka asistanı **Terra**. 🌾\n\n'
            'Şu an seçili olan **${widget.field['name']}** tarlanızdaki **${widget.crop['name']}** mahsulünüz ile ilgili sulama, gübreleme veya yaprak anomalileri hakkında bana her türlü soruyu sorabilirsiniz. Size nasıl yardımcı olabilirim?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    // Fetch weather details
    final weather = await ApiService.instance.getCurrentWeather(
      widget.field['latitude'] ?? 38.4622,
      widget.field['longitude'] ?? 27.0923,
    );

    // Prepare full JSON payload to maintain memory/context (UX design rules)
    final inputJson = {
      "current_time": DateTime.now().toIso8601String(),
      "user_info": {
        "name": widget.user['name'],
        "location": "${widget.field['city']} / ${widget.field['district']}"
      },
      "field_info": {
        "field_name": widget.field['name'],
        "crop_name": widget.crop['name'],
        "growth_stage": widget.crop['growth_stage'] ?? "Fide Dönemi"
      },
      "crop_db_info": {
        "optimum_temp_range": widget.crop['optimum_temp_range'],
        "optimum_moisture_range_pct": widget.crop['optimum_moisture_range_pct'],
        "suggested_npk": widget.crop['suggested_npk'],
        "water_need": widget.crop['water_need']
      },
      "farmer_history": [
        {
          "action": "soru-cevap",
          "date": DateTime.now().toIso8601String(),
          "details": "Çiftçi sorusu: $text"
        }
      ],
      "sensor_records": {
        "soil_moisture_pct": widget.soilMoist,
        "soil_temp_c": widget.soilTemp
      },
      "weather_forecast": [
        {
          "date": DateTime.now().toIso8601String().split('T')[0],
          "temp_c": weather != null ? weather['temperature_c'] : 27.0,
          "humidity_pct": weather != null ? weather['humidity_pct'] : 60,
          "precipitation_mm": 0.0,
          "condition": weather != null ? weather['weather_description'] : "Açık"
        }
      ],
      "cnn_disease_result": {
        "detected": false,
        "disease_name": null,
        "confidence_pct": 0
      }
    };

    final result = await ApiService.instance.getAIRecommendation(inputJson);

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          text: result ?? 'Üzgünüm, şu an bağlantıda bir sorun yaşıyorum. Lütfen daha sonra tekrar deneyin.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF4A7C59),
              child: Icon(Icons.psychology, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? const Color(0xFF4A7C59) : const Color(0xFFE4E0D8).withOpacity(0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(msg.isUser ? 12 : 0),
                  bottomRight: Radius.circular(msg.isUser ? 0 : 12),
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.nunitoSans(
                  color: msg.isUser ? Colors.white : const Color(0xFF2E3230),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF705C30),
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
          ),
        ),

        // Typing indicator
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A7C59))),
                ),
                const SizedBox(width: 8),
                Text('Terra yazıyor...', style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFFF0ECE4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Sorunuzu buraya yazın...',
                    hintStyle: GoogleFonts.nunitoSans(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF4A7C59)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

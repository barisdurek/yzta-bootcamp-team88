import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
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

class _TerraChatScreenState extends State<TerraChatScreen> with AutomaticKeepAliveClientMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  List<Map<String, dynamic>> _userFields = [];
  Map<int, Map<String, dynamic>> _fieldCrops = {};
  Map<String, dynamic>? _selectedField;
  Map<String, dynamic>? _selectedCrop;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedField = widget.field;
    _selectedCrop = widget.crop;

    final fieldName = _selectedField?['name'] ?? _selectedField?['field_name'] ?? 'Tarlanız';
    final cropName = _selectedCrop?['name'] ?? 'Domates';

    // Welcome message
    _messages.add(
      ChatMessage(
        text: 'Merhaba ${widget.user['name']}! Ben Tarla Gözcüsü\'nün yapay zeka asistanı **Terra**. 🌾\n\n'
            'Şu an seçili olan **$fieldName** tarlanızdaki **$cropName** mahsulünüz ile ilgili sulama, gübreleme veya yaprak anomalileri hakkında bana her türlü soruyu sorabilirsiniz. Yukarıdaki menüden dilediğiniz tarlayı seçip sorularınızı sorabilirsiniz!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    _loadUserFields();
  }

  Future<void> _loadUserFields() async {
    final userId = (widget.user['id'] ?? widget.user['user_id'] ?? 1) as int;
    final fields = await DatabaseHelper.instance.getFieldsForUser(userId);
    final Map<int, Map<String, dynamic>> crops = {};
    for (var f in fields) {
      final fid = f['id'] as int?;
      if (fid != null) {
        final activeCrop = await DatabaseHelper.instance.getActiveCropForField(fid);
        if (activeCrop != null) {
          crops[fid] = activeCrop;
        }
      }
    }

    if (mounted) {
      setState(() {
        _userFields = fields;
        _fieldCrops = crops;
        if (_selectedField == null && fields.isNotEmpty) {
          _selectedField = fields.first;
          _selectedCrop = crops[fields.first['id'] as int];
        }
      });
    }
  }

  void _onFieldChanged(Map<String, dynamic>? newField) {
    if (newField == null) return;
    final fid = newField['id'] as int?;
    final newCrop = fid != null ? _fieldCrops[fid] : null;

    setState(() {
      _selectedField = newField;
      _selectedCrop = newCrop ?? widget.crop;
    });

    final fname = newField['name'] ?? newField['field_name'] ?? 'Tarla';
    final cname = _selectedCrop?['name'] ?? 'Mahsul';

    _messages.add(
      ChatMessage(
        text: '🌾 Aktif analiz tarlası **$fname** ($cname) olarak değiştirildi. Bu tarla hakkında merak ettiğiniz tüm soruları sorabilirsiniz.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    _scrollToBottom();
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

    final activeField = _selectedField ?? widget.field;
    final activeCrop = _selectedCrop ?? widget.crop;

    // Fetch weather details for selected field
    final weather = await ApiService.instance.getCurrentWeather(
      activeField['latitude'] ?? 38.4622,
      activeField['longitude'] ?? 27.0923,
    );

    final inputJson = {
      "current_time": DateTime.now().toIso8601String(),
      "user_info": {
        "name": widget.user['name'],
        "location": "${activeField['city']} / ${activeField['district']}"
      },
      "field_info": {
        "field_name": activeField['name'] ?? activeField['field_name'],
        "crop_name": activeCrop['name'] ?? 'Domates',
        "growth_stage": activeCrop['growth_stage'] ?? "Fide Dönemi"
      },
      "crop_db_info": {
        "optimum_temp_range": activeCrop['optimum_temp_range'] ?? '20-30 C',
        "optimum_moisture_range_pct": activeCrop['optimum_moisture_range_pct'] ?? '50-70 %',
        "suggested_npk": activeCrop['suggested_npk'] ?? '15-15-15',
        "water_need": activeCrop['water_need'] ?? 'Orta'
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

    if (mounted) {
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
  }

  Widget _buildFormattedText(String rawText, Color textColor) {
    final lines = rawText.split('\n');
    final List<Widget> widgets = [];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      String cleanLine = line;
      bool isBullet = false;
      if (cleanLine.trim().startsWith('* ') || cleanLine.trim().startsWith('- ') || cleanLine.trim().startsWith('• ')) {
        isBullet = true;
        cleanLine = cleanLine.trim().substring(2);
      }

      final spans = <InlineSpan>[];
      final parts = cleanLine.split('**');

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;

        final formattedPart = part.replaceAll('*', '');

        if (i % 2 == 1) {
          spans.add(TextSpan(
            text: formattedPart,
            style: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 14,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: formattedPart,
            style: GoogleFonts.nunitoSans(
              color: textColor,
              fontSize: 14,
            ),
          ));
        }
      }

      if (isBullet) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 2.0, bottom: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: spans),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: RichText(
              text: TextSpan(children: spans),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final textColor = msg.isUser ? Colors.white : const Color(0xFF2E3230);
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
              child: _buildFormattedText(msg.text, textColor),
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
    super.build(context);
    final fieldsList = _userFields.isNotEmpty ? _userFields : [widget.field];
    final activeFid = _selectedField?['id'] ?? widget.field['id'];

    return Column(
      children: [
        // Header Field Selector Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4A7C59).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF4A7C59), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: activeFid as int?,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A7C59)),
                    items: fieldsList.map((f) {
                      final fid = f['id'] as int;
                      final crop = _fieldCrops[fid];
                      final cname = crop?['name'] ?? 'Mahsul';
                      final fname = f['name'] ?? f['field_name'] ?? 'Tarla';

                      return DropdownMenuItem<int>(
                        value: fid,
                        child: Text(
                          '$fname ($cname)',
                          style: GoogleFonts.literata(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3230),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = fieldsList.firstWhere((f) => f['id'] == val, orElse: () => fieldsList.first);
                        _onFieldChanged(found);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chat list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                Text(
                  'Terra yazıyor...',
                  style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4A7C59), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

        // Input Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF0ECE4),
            border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Sorunuzu buraya yazın...',
                    hintStyle: GoogleFonts.nunitoSans(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C59),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send, size: 20),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

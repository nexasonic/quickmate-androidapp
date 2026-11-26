import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _supportMsgController = TextEditingController();
  bool _isSending = false;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I post a Live Work card?',
      'answer': 'Go to "My Cards" tab on the bottom bar, tap the "+ Create Live Work Card" button at the top banner, fill in your service title, category, price, and description, and tap Submit!'
    },
    {
      'question': 'How does real-time chat work?',
      'answer': 'When viewing any Live Work card detail page, tap the "Chat Now" button to directly message the card owner or service provider in real-time.'
    },
    {
      'question': 'How is location and distance calculated?',
      'answer': 'Distance is calculated using the Haversine formula based on your location and the service provider card location, displayed in kilometers or meters.'
    },
    {
      'question': 'How do I save cards to my favorites?',
      'answer': 'Tap the heart icon on any card or the "Save to Favorites" button on the card details page. You can view all saved cards anytime under Profile > Saved Cards.'
    },
    {
      'question': 'Is my personal contact information secure?',
      'answer': 'Yes, QuickMate uses encrypted HTTPS API communication and secure authentication tokens to protect user data and privacy.'
    },
  ];

  @override
  void dispose() {
    _supportMsgController.dispose();
    super.dispose();
  }

  void _sendSupportMessage() {
    final text = _supportMsgController.text.trim();
    if (text.isEmpty) {
      AppDialogs.showToastModal(
        context,
        message: 'Please enter your query or message.',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        iconBgColor: const Color(0xFFFEF3C7),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _supportMsgController.clear();
      });
      AppDialogs.showToastModal(
        context,
        message: 'Support query submitted! Our team will get back to you shortly.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        },
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQs Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionPanelList.radio(
                elevation: 0,
                children: _faqs.map((faq) {
                  return ExpansionPanelRadio(
                    value: faq['question']!,
                    headerBuilder: (context, isExpanded) {
                      return ListTile(
                        title: Text(
                          faq['question']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      );
                    },
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faq['answer']!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Support Section
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Have a question or issue? Write to us below:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportMsgController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe your issue or feedback...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendSupportMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: _isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Submit Query',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

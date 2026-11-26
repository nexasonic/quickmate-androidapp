import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _supportMsgController = TextEditingController();
  bool _isSending = false;

  List<Map<String, String>> _getFaqs(BuildContext context) => [
    {
      'question': context.tr('faq_q1'),
      'answer': context.tr('faq_a1'),
    },
    {
      'question': context.tr('faq_q2'),
      'answer': context.tr('faq_a2'),
    },
    {
      'question': context.tr('faq_q3'),
      'answer': context.tr('faq_a3'),
    },
    {
      'question': context.tr('faq_q4'),
      'answer': context.tr('faq_a4'),
    },
    {
      'question': context.tr('faq_q5'),
      'answer': context.tr('faq_a5'),
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
        message: context.tr('enter_query_msg'),
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
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
        message: context.tr('support_query_submitted'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('help_support'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              Text(
                context.tr('faq'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryDark,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: AppTheme.surface(context),
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionPanelList.radio(
                    elevation: 0,
                    expandedHeaderPadding: EdgeInsets.zero,
                    children: _getFaqs(context).map((faq) {
                      return ExpansionPanelRadio(
                        value: faq['question']!,
                        headerBuilder: (context, isExpanded) {
                          return ListTile(
                            title: Text(
                              faq['question']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          );
                        },
                        body: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Contact Support Section
              Text(
                context.tr('contact_support'),
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
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('have_question_prompt'),
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _supportMsgController,
                      maxLines: 4,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: context.tr('describe_issue_hint'),
                        hintStyle: TextStyle(color: AppTheme.textSecondary(context)),
                        filled: true,
                        fillColor: AppTheme.inputFill(context),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppTheme.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryDark, width: 1.5),
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
                            : Text(
                                context.tr('submit'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

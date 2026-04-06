import 'package:flutter/material.dart';
import 'analysis_result_screen.dart';
import 'history_screen.dart';
import 'preferences_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  static const Color _backgroundColor = Color(0xFFEAF4EE);
  static const Color _primaryGreen = Color(0xFF00A63E);
  static const Color _softGreen = Color(0xFFD8F2E1);
  static const Color _textMuted = Color(0xFF5F6A78);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / 390).clamp(0.88, 1.0);
    double s(double value) => value * scale;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: s(22), vertical: s(26)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Safety Scanner',
                          style: TextStyle(
                            fontSize: s(22),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Color(0xFF0D1833),
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: s(8)),
                        Text(
                          '안전한 식품 선택을 위한 성분 분석',
                          style: TextStyle(
                            fontSize: s(14),
                            color: _textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PreferencesScreen()),
                      );
                    },
                    icon: Icon(Icons.settings_outlined, size: s(22)),
                    color: const Color(0xFF2B3443),
                    tooltip: '설정',
                  ),
                ],
              ),
              SizedBox(height: s(24)),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(s(18)),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(s(20), s(20), s(20), s(20)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(s(18)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '분석 기록 확인하기',
                              style: TextStyle(
                                fontSize: s(17),
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: s(6)),
                            Text(
                              '총 분석 횟수',
                              style: TextStyle(
                                fontSize: s(11.5),
                                color: _textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: s(4)),
                            Text(
                              '0회',
                              style: TextStyle(
                                fontSize: s(22),
                                height: 1.0,
                                color: Color(0xFF09162E),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: s(54),
                        height: s(54),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _softGreen,
                        ),
                        child: Icon(
                          Icons.history,
                          color: _primaryGreen,
                          size: s(28),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: s(32)),
              SizedBox(
                width: double.infinity,
                height: s(56),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalysisResultScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s(16)),
                    ),
                    textStyle: TextStyle(
                      fontSize: s(16),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  icon: Icon(Icons.crop_free, size: s(20)),
                  label: const Text('성분표 분석하기'),
                ),
              ),
              SizedBox(height: s(25)),
              SizedBox(
                width: double.infinity,
                height: s(56),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2234),
                    side: BorderSide(color: const Color(0xFFD6DCE3), width: s(1.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s(16)),
                    ),
                    textStyle: TextStyle(
                      fontSize: s(16),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  icon: Icon(Icons.settings_outlined, size: s(20)),
                  label: const Text('기피 성분 설정'),
                ),
              ),
              SizedBox(height: s(32)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(s(18), s(18), s(18), s(20)),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EC),
                  borderRadius: BorderRadius.circular(s(18)),
                  border: Border.all(color: const Color(0xFFD4E8DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이렇게 사용하세요',
                      style: TextStyle(
                        fontSize: s(18),
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F1E3B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: s(10)),
                    Text(
                      '1.  기피 성분을 미리 설정하세요. (알레르기, 비건 등)',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF48566A),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '2.  제품의 성분표를 촬영하거나 업로드하세요',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF48566A),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '3.  경고 성분을 확인하고 안전하게 선택하세요',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF48566A),
                        height: 1.5,
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

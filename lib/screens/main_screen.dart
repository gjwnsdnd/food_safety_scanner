import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'camera_gallery_screen.dart';
import 'history_screen.dart';
import 'preferences_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ApiService _apiService = ApiService();
  final String _userId = 'default';
  List<String> _selectedIngredients = [];
  bool _isLoadingPreferences = true;

  static const Color _backgroundColor = Color(0xFFEAF4EE);
  static const Color _primaryGreen = Color(0xFF00A63E);
  static const Color _softGreen = Color(0xFFD8F2E1);
  static const Color _textMuted = Color(0xFF5F6A78);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final data = await _apiService.getPreferences(_userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedIngredients =
            List<String>.from(data['avoided_ingredients'] ?? []);
        _isLoadingPreferences = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / 390).clamp(0.88, 1.0);
    double s(double value) => value * scale;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(s(22), s(26), s(22), s(18)),
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
                ],
              ),
              SizedBox(height: s(48)),
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
                    ).then((_) => _loadPreferences());
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
                  label: const Text('1. 기피 성분 설정'),
                ),
              ),
              SizedBox(height: s(16)),
              SizedBox(
                width: double.infinity,
                height: s(56),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CameraGalleryScreen()),
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
                  label: const Text('2. 성분표 분석하기'),
                ),
              ),
              SizedBox(height: s(16)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(s(18), s(16), s(18), s(16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(s(16)),
                  border: Border.all(color: const Color(0xFFD6DCE3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기피 성분 설정 상태',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: s(6)),
                    Text(
                      _isLoadingPreferences
                          ? '불러오는 중...'
                          : '현재 ${_selectedIngredients.length}개 성분 선택됨',
                      style: TextStyle(
                        fontSize: s(13),
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!_isLoadingPreferences && _selectedIngredients.isNotEmpty) ...[
                      SizedBox(height: s(10)),
                      Wrap(
                        spacing: s(6),
                        runSpacing: s(6),
                        children: _selectedIngredients
                            .map(
                              (ingredient) => Chip(
                                label: Text(
                                  ingredient,
                                  style: TextStyle(
                                    fontSize: s(12),
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                backgroundColor: const Color(0xFFF2F5F8),
                                side: const BorderSide(color: Color(0xFFDCE3EA)),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: s(16)),
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
                              '3. 분석 기록 확인하기',
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
                      '1. 기피 성분을 미리 설정하세요. (알레르기, 비건 등)',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF48566A),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '2. 성분표 분석하기로 성분표를 촬영 또는 업로드하세요.',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF48566A),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '3. 저장한 분석기록을 확인하세요.',
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

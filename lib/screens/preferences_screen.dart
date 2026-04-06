import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/preferences_model.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final ApiService _apiService = ApiService();
  final String _userId = 'default';

  // 17개 성분 데이터 (가나다순)
  static const List<String> _allIngredients = [
    '계란',
    '고카페인',
    '과라나',
    '구연산',
    '대두',
    '밀',
    '우유',
    '참깨',
    '토마토',
    '파프리카',
    '해산물',
    '혼합곡물',
    '효모',
    '키위',
    '헤이즐넛',
    '합성첨가물',
  ];

  static const Map<String, List<String>> _categoryIngredients = {
    '알레르기': ['계란', '고카페인', '과라나', '구연산', '대두', '밀', '우유', '참깨', '해산물'],
    '비건': ['계란', '고카페인', '우유'],
    '임산부': ['과라나', '고카페인', '구연산', '효모'],
    '영유아': ['계란', '고카페인', '과라나'],
  };

  late TextEditingController _searchController;
  String _selectedCategory = '전체';
  Set<String> _selectedIngredients = {};
  List<PreferencesGroup> _savedGroups = [];
  String _activeGroupName = '';
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _filteredIngredients = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterIngredients);
    _filteredIngredients = List.from(_allIngredients);
    _loadPreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() => _isLoading = true);
      final data = await _apiService.getPreferences(_userId);

      if (mounted) {
        setState(() {
          _savedGroups = (data['groups'] as List?)
              ?.map((g) => PreferencesGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기피 성분 조회 실패: $e')),
        );
      }
    }
  }

  void _filterIngredients() {
    final query = _searchController.text.toLowerCase();
    final categoryItems =
        _selectedCategory == '전체' ? _allIngredients : _categoryIngredients[_selectedCategory] ?? [];

    setState(() {
      if (query.isEmpty) {
        _filteredIngredients = List.from(categoryItems);
      } else {
        _filteredIngredients = categoryItems.where((item) => item.contains(query)).toList();
      }
    });
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
        _activeGroupName = '';
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _searchController.clear();
    });
    _filterIngredients();
  }

  void _applyGroup(PreferencesGroup group) {
    setState(() {
      _selectedIngredients = Set.from(group.ingredients);
      _activeGroupName = group.groupName;
    });
  }

  void _promptSaveGroup() {
    TextEditingController groupNameController =
        TextEditingController(text: '기피성분');

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('그룹 저장'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(hintText: '그룹명 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveGroup(groupNameController.text);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGroup(String groupName) async {
    if (groupName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹명을 입력하세요.')),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      // 일단 로컬에 저장 (실제 API는 구현 시점에 수정)
      final existing =
          _savedGroups.indexWhere((g) => g.groupName == groupName);
      final newGroup = PreferencesGroup(
        groupName: groupName,
        ingredients: List.from(_selectedIngredients),
      );

      setState(() {
        if (existing >= 0) {
          _savedGroups[existing] = newGroup;
        } else {
          _savedGroups.add(newGroup);
        }
        _activeGroupName = groupName;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('그룹 "$groupName"이(가) 저장되었습니다.')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('그룹 저장 실패: $e')),
      );
    }
  }

  void _deleteGroup(String groupName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text('그룹 "$groupName"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _savedGroups.removeWhere((g) => g.groupName == groupName);
                if (_activeGroupName == groupName) {
                  _activeGroupName = '';
                  _selectedIngredients.clear();
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('그룹 "$groupName"이(가) 삭제되었습니다.')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePreferences() async {
    try {
      setState(() => _isSaving = true);
      await _apiService.savePreferences(
        _userId,
        List.from(_selectedIngredients),
      );

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기피 성분이 저장되었습니다.')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / 390).clamp(0.88, 1.0);
    double s(double value) => value * scale;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4EE),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: EdgeInsets.all(s(16)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: const Color(0xFF0F172A),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '기피 성분 설정',
                          style: TextStyle(
                            fontSize: s(22),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${_selectedIngredients.length}개 선택됨',
                          style: TextStyle(
                            fontSize: s(14),
                            color: const Color(0xFF5F6A78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: s(40),
                    child: ElevatedButton.icon(
                      onPressed: _selectedIngredients.isEmpty
                          ? null
                          : _promptSaveGroup,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        '그룹 저장',
                        style: TextStyle(fontSize: s(12)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A63E),
                        disabledBackgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(horizontal: s(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 검색창
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(8)),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '성분 검색...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(s(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: s(16),
                    vertical: s(12),
                  ),
                ),
              ),
            ),
            // 저장된 그룹 섹션
            if (_savedGroups.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(s(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '저장된 그룹',
                      style: TextStyle(
                        fontSize: s(14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: s(8)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _savedGroups.map((group) {
                          final isActive = _activeGroupName == group.groupName;
                          return Padding(
                            padding: EdgeInsets.only(right: s(8)),
                            child: InkWell(
                              onTap: () => _applyGroup(group),
                              borderRadius: BorderRadius.circular(s(20)),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: s(12),
                                  vertical: s(8),
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF00A63E)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(s(20)),
                                  border: Border.all(
                                    color: const Color(0xFF00A63E),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      group.groupName,
                                      style: TextStyle(
                                        fontSize: s(12),
                                        color: isActive
                                            ? Colors.white
                                            : const Color(0xFF00A63E),
                                      ),
                                    ),
                                    SizedBox(width: s(8)),
                                    GestureDetector(
                                      onTap: () =>
                                          _deleteGroup(group.groupName),
                                      child: Icon(
                                        Icons.close,
                                        size: s(14),
                                        color: isActive
                                            ? Colors.white
                                            : const Color(0xFF00A63E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            // 카테고리 탭
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(8)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['전체', '알레르기', '비건', '임산부', '영유아']
                      .map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: EdgeInsets.only(right: s(8)),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => _selectCategory(category),
                        selectedColor: const Color(0xFF00A63E),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.black87,
                          fontSize: s(13),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // 성분 리스트
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredIngredients.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없습니다.',
                            style: TextStyle(
                              fontSize: s(14),
                              color: const Color(0xFF5F6A78),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: s(16)),
                          itemCount: _filteredIngredients.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final ingredient = _filteredIngredients[index];
                            final isSelected =
                                _selectedIngredients.contains(ingredient);

                            return CheckboxListTile(
                              title: Text(
                                ingredient,
                                style: TextStyle(
                                  fontSize: s(14),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (_) =>
                                  _toggleIngredient(ingredient),
                              activeColor: const Color(0xFF00A63E),
                            );
                          },
                        ),
            ),
            // 저장 버튼
            Padding(
              padding: EdgeInsets.all(s(16)),
              child: SizedBox(
                width: double.infinity,
                height: s(50),
                child: ElevatedButton(
                  onPressed: _selectedIngredients.isEmpty || _isSaving
                      ? null
                      : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A63E),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: s(20),
                          width: s(20),
                          child: const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '저장',
                          style: TextStyle(
                            fontSize: s(16),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

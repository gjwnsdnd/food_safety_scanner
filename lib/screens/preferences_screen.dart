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

  // MongoDB에 저장된 17개 성분 데이터 (가나다순)
  static const List<String> _allIngredients = [
    '계란',
    '과라나',
    '꿀',
    '대두',
    '땅콩',
    '밀',
    '새우',
    '아라비아검',
    '아황산나트륨',
    '안식향산',
    '알코올(에탄올)',
    '우유',
    '적색제40호',
    '젤라틴',
    '카르민',
    '카페인',
    '황색제 4호',
    'L-글루탐산나트륨',
  ];

  static const Map<String, List<String>> _categoryIngredients = {
    '알레르기': ['계란', '대두', '땅콩', '밀', '새우', '우유'],
    '비건': ['젤라틴', '카르민'],
    '임산부': ['과라나', '카페인', '안식향산', '알코올(에탄올)'],
    '영유아': ['꿀', '아황산나트륨', '적색제40호', '황색제 4호', 'L-글루탐산나트륨'],
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
          _selectedIngredients = Set<String>.from(
            List<String>.from(data['avoided_ingredients'] ?? []),
          );
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
    final TextEditingController groupNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('그룹 저장'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(
            hintText: '그룹의 이름을 입력하세요',
            hintStyle: TextStyle(color: Color(0xFF9AA3AF)),
          ),
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

    // 새 그룹 생성
    final existing = _savedGroups.indexWhere((g) => g.groupName == groupName);
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
    });

    // ✅ 백엔드에 groups 저장!
    await _apiService.savePreferences(
      _userId,
      List.from(_selectedIngredients),
      _savedGroups.map((g) => g.toJson()).toList(),
    );

    setState(() => _isSaving = false);

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
      final response = await _apiService.savePreferences(
        _userId,
        List.from(_selectedIngredients),
        _savedGroups.map((g) => g.toJson()).toList(),
      );

      if (mounted) {
        setState(() {
          _savedGroups = (response['groups'] as List?)
                  ?.map((g) => PreferencesGroup.fromJson(g as Map<String, dynamic>))
                  .toList() ??
              _savedGroups;
          _selectedIngredients = Set<String>.from(
            List<String>.from(response['avoided_ingredients'] ?? _selectedIngredients.toList()),
          );
          _isSaving = false;
        });
      }

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
    final selectedIngredientList = _allIngredients
        .where(_selectedIngredients.contains)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(s(20), s(12), s(20), s(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: const Color(0xFF1E293B),
                          splashRadius: 22,
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
                                  color: const Color(0xFF1E293B),
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: s(4)),
                              Text(
                                '${_selectedIngredients.length}개 선택됨',
                                style: TextStyle(
                                  fontSize: s(12.5),
                                  color: const Color(0xFF7C8798),
                                  fontWeight: FontWeight.w500,
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
                              elevation: 0,
                              backgroundColor: const Color(0xFF0AA64E),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFE6E8EE),
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: s(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: s(14)),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(s(18)),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '성분 검색...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          prefixIconColor: const Color(0xFF8A94A6),
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: const Color(0xFF9AA3AF),
                            fontSize: s(13),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: s(16),
                            vertical: s(14),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: s(14),
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (selectedIngredientList.isNotEmpty) ...[
                      SizedBox(height: s(18)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(s(16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(s(18)),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.checklist_rounded,
                                  size: s(18),
                                  color: const Color(0xFF7C8798),
                                ),
                                SizedBox(width: s(6)),
                                Text(
                                  '현재 선택 성분',
                                  style: TextStyle(
                                    fontSize: s(13),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: s(12)),
                            Wrap(
                              spacing: s(8),
                              runSpacing: s(8),
                              children: selectedIngredientList.map((ingredient) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: s(12),
                                    vertical: s(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF8EF),
                                    borderRadius: BorderRadius.circular(s(999)),
                                    border: Border.all(
                                      color: const Color(0xFFC6F0D6),
                                    ),
                                  ),
                                  child: Text(
                                    ingredient,
                                    style: TextStyle(
                                      fontSize: s(12),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0E7A3A),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_savedGroups.isNotEmpty) ...[
                      SizedBox(height: s(18)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(s(16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(s(18)),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.groups_rounded,
                                  size: s(18),
                                  color: const Color(0xFF7C8798),
                                ),
                                SizedBox(width: s(6)),
                                Text(
                                  '저장된 그룹',
                                  style: TextStyle(
                                    fontSize: s(13),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: s(12)),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _savedGroups.map((group) {
                                  final isActive =
                                      _activeGroupName == group.groupName;
                                  return Padding(
                                    padding: EdgeInsets.only(right: s(8)),
                                    child: InkWell(
                                      onTap: () => _applyGroup(group),
                                      borderRadius:
                                          BorderRadius.circular(s(999)),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: s(14),
                                          vertical: s(10),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFFEAF8EF)
                                              : const Color(0xFFF7F8FB),
                                          borderRadius:
                                              BorderRadius.circular(s(999)),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF0AA64E)
                                                : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              group.groupName,
                                              style: TextStyle(
                                                fontSize: s(12),
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? const Color(0xFF0AA64E)
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                            SizedBox(width: s(8)),
                                            GestureDetector(
                                              onTap: () =>
                                                  _deleteGroup(group.groupName),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: s(14),
                                                color: isActive
                                                    ? const Color(0xFF0AA64E)
                                                    : const Color(0xFF94A3B8),
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
                    ],
                    SizedBox(height: s(18)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(s(10)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F7),
                        borderRadius: BorderRadius.circular(s(999)),
                      ),
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
                                backgroundColor: Colors.white,
                                selectedColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(s(999)),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF0AA64E)
                                        : Colors.transparent,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF0AA64E)
                                      : const Color(0xFF64748B),
                                  fontSize: s(12.5),
                                  fontWeight: FontWeight.w600,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.symmetric(
                                  horizontal: s(8),
                                  vertical: s(6),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: s(14)),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(s(18)),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: s(340),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _filteredIngredients.isEmpty
                              ? SizedBox(
                                  height: s(340),
                                  child: Center(
                                    child: Text(
                                      '검색 결과가 없습니다.',
                                      style: TextStyle(
                                        fontSize: s(14),
                                        color: const Color(0xFF7C8798),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredIngredients.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                  itemBuilder: (context, index) {
                                    final ingredient = _filteredIngredients[index];
                                    final isSelected =
                                        _selectedIngredients.contains(ingredient);

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _toggleIngredient(ingredient),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: s(16),
                                            vertical: s(14),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  ingredient,
                                                  style: TextStyle(
                                                    fontSize: s(14),
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF111827),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: s(22),
                                                height: s(22),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF0AA64E)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          s(6)),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? const Color(0xFF0AA64E)
                                                        : const Color(0xFFD1D5DB),
                                                    width: 1.4,
                                                  ),
                                                ),
                                                child: isSelected
                                                    ? Icon(
                                                        Icons.check,
                                                        size: s(14),
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(s(20), 0, s(20), s(18)),
              child: SizedBox(
                width: double.infinity,
                height: s(54),
                child: ElevatedButton(
                  onPressed: _selectedIngredients.isEmpty || _isSaving
                      ? null
                      : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF0AA64E),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s(18)),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: s(20),
                          width: s(20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '설정 저장하기',
                          style: TextStyle(
                            fontSize: s(16),
                            fontWeight: FontWeight.w700,
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

import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── 상수 ─────────────────────────────────────────────────────────────────────

const _defaultUserId = 'default_user';

// ─── 데이터 ───────────────────────────────────────────────────────────────────

const _allIngredients = [
  '계란',
  '고카페인',
  '과라나',
  '구연산',
  '대두',
  '밀',
  '우유',
  '참깨',
  '키위',
  '토마토',
  '파프리카',
  '합성첨가물',
  '해산물',
  '헤이즐넛',
  '혼합곡물',
  '효모',
];

const _categoryIngredients = {
  '알레르기': ['계란', '고카페인', '과라나', '구연산', '대두', '밀', '우유', '참깨', '해산물'],
  '비건': ['계란', '고카페인', '우유'],
  '임산부': ['고카페인', '과라나', '구연산', '효모'],
  '영유아': ['계란', '고카페인', '과라나'],
};

const _tabLabels = ['전체', '알레르기', '비건', '임산부', '영유아'];

// ─── 모델 ─────────────────────────────────────────────────────────────────────

class _IngredientGroup {
  final String name;
  final List<String> ingredients;

  const _IngredientGroup({required this.name, required this.ingredients});
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  final Set<String> _selected = {};
  final List<_IngredientGroup> _groups = [];
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _loadPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    try {
      final data = await _apiService.getPreferences(_defaultUserId);
      final saved = List<String>.from(
        (data['avoided_ingredients'] as List?)?.cast<String>() ?? [],
      );
      final groupsJson = (data['groups'] as List?) ?? [];
      setState(() {
        _selected
          ..clear()
          ..addAll(saved);
        _groups
          ..clear()
          ..addAll(groupsJson.map((g) => _IngredientGroup(
                name: g['name'] as String,
                ingredients: List<String>.from(
                  (g['ingredients'] as List?)?.cast<String>() ?? [],
                ),
              )));
      });
    } catch (_) {
      // 서버 미연동 시 빈 상태로 시작
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.savePreferences(
        userId: _defaultUserId,
        avoidedIngredients: _selected.toList(),
        groups: _groups
            .map((g) => {'name': g.name, 'ingredients': g.ingredients})
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기피 성분이 저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 그룹 저장 다이얼로그 ──────────────────────────────────────────────────────

  Future<void> _showSaveGroupDialog() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 성분을 선택해 주세요.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그룹 이름 입력'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예: 기피성분',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A63E)),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      setState(() {
        _groups.add(_IngredientGroup(
          name: name,
          ingredients: _selected.toList(),
        ));
      });
    }
    nameController.dispose();
  }

  // ── 그룹 삭제 ────────────────────────────────────────────────────────────────

  void _deleteGroup(int index) {
    setState(() => _groups.removeAt(index));
  }

  // ── 그룹 클릭 → 성분 체크 ───────────────────────────────────────────────────

  void _applyGroup(_IngredientGroup group) {
    setState(() {
      _selected
        ..clear()
        ..addAll(group.ingredients);
    });
  }

  // ── 현재 탭의 성분 목록 (검색 필터 적용) ────────────────────────────────────

  List<String> _filteredIngredients(int tabIndex) {
    final base = tabIndex == 0
        ? _allIngredients
        : (_categoryIngredients[_tabLabels[tabIndex]] ?? []);

    if (_searchQuery.isEmpty) return base;
    return base
        .where((i) => i.contains(_searchQuery))
        .toList();
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 8),
          if (_groups.isNotEmpty) _buildGroupChips(),
          const Divider(height: 1),
          _buildTabBar(),
          const Divider(height: 1),
          Expanded(child: _buildTabBarView()),
          _buildSaveButton(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF7F8FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기피 성분 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${_selected.length}개 선택됨',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: OutlinedButton.icon(
            onPressed: _showSaveGroupDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF111827),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('그룹 저장'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Color(0xFF94A3B8), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '성분 검색...',
                  hintStyle: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _searchController.clear(),
                color: const Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '저장된 그룹',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(_groups.length, (i) {
              final group = _groups[i];
              return InputChip(
                label: Text(
                  '${group.name} (${group.ingredients.length})',
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _applyGroup(group),
                onDeleted: () => _deleteGroup(i),
                deleteIcon: const Icon(Icons.close, size: 16),
                backgroundColor: const Color(0xFFE6F4EC),
                side: const BorderSide(color: Color(0xFF00A63E), width: 0.8),
                labelStyle: const TextStyle(color: Color(0xFF00A63E)),
                deleteIconColor: const Color(0xFF00A63E),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: const Color(0xFF00A63E),
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: const Color(0xFF00A63E),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: List.generate(
        _tabLabels.length,
        (i) => _buildIngredientList(i),
      ),
    );
  }

  Widget _buildIngredientList(int tabIndex) {
    return AnimatedBuilder(
      animation: _searchController,
      builder: (_, __) {
        final items = _filteredIngredients(tabIndex);
        if (items.isEmpty) {
          return const Center(
            child: Text(
              '검색 결과가 없습니다.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final ingredient = items[index];
            final isChecked = _selected.contains(ingredient);
            return CheckboxListTile(
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(ingredient);
                  } else {
                    _selected.remove(ingredient);
                  }
                });
              },
              title: Text(
                ingredient,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isChecked ? FontWeight.w700 : FontWeight.w500,
                  color: isChecked
                      ? const Color(0xFF00A63E)
                      : const Color(0xFF0F172A),
                ),
              ),
              activeColor: const Color(0xFF00A63E),
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.trailing,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isSaving ? null : _savePreferences,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A63E),
              disabledBackgroundColor: const Color(0xFF00A63E).withOpacity(0.6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

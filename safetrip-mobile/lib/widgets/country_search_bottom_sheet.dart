import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/app_tokens.dart';

/// 한글 초성 목록 (19자)
const List<String> _chosung = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
  'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 한글 유니코드 범위
const int _hangulStart = 0xAC00;
const int _hangulEnd = 0xD7A3;

/// 첫 글자의 초성을 추출한다.
/// 한글이 아닌 경우 '#'을 반환한다.
String _extractChosung(String text) {
  if (text.isEmpty) return '#';
  final int code = text.codeUnitAt(0);
  if (code < _hangulStart || code > _hangulEnd) return '#';
  final int chosungIndex = (code - _hangulStart) ~/ (21 * 28);
  return _chosung[chosungIndex];
}

/// 국가 검색 바텀시트.
///
/// [countries]에 `country_code`, `country_name_ko`, `country_name` 필드를 가진
/// 맵 리스트를 전달하면, 검색 + 초성 그룹핑된 국가 목록을 표시한다.
/// 국가를 선택하면 해당 맵을 반환한다.
class CountrySearchBottomSheet extends StatefulWidget {

  const CountrySearchBottomSheet({
    super.key,
    required this.countries,
    this.selectedCountryCode,
  });
  /// API에서 가져온 국가 목록.
  final List<Map<String, dynamic>> countries;

  /// 현재 선택된 국가 코드 (선택 표시용).
  final String? selectedCountryCode;

  /// 바텀시트를 열고, 선택된 국가 맵을 반환한다.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> countries,
    String? selectedCountryCode,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountrySearchBottomSheet(
        countries: countries,
        selectedCountryCode: selectedCountryCode,
      ),
    );
  }

  @override
  State<CountrySearchBottomSheet> createState() =>
      _CountrySearchBottomSheetState();
}

class _CountrySearchBottomSheetState extends State<CountrySearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = _sortedCountries(widget.countries);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 한국어 이름 기준 가나다순 정렬.
  List<Map<String, dynamic>> _sortedCountries(
    List<Map<String, dynamic>> list,
  ) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final nameA = (a['country_name_ko'] as String?) ?? '';
      final nameB = (b['country_name_ko'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filtered = _sortedCountries(widget.countries);
      });
      return;
    }
    setState(() {
      _filtered = _sortedCountries(
        widget.countries.where((c) {
          final nameKo =
              ((c['country_name_ko'] as String?) ?? '').toLowerCase();
          final nameEn =
              ((c['country_name'] as String?) ?? '').toLowerCase();
          final code =
              ((c['country_code'] as String?) ?? '').toLowerCase();
          return nameKo.contains(query) ||
              nameEn.contains(query) ||
              code.contains(query);
        }).toList(),
      );
    });
  }

  /// 필터된 목록을 초성 그룹으로 나눈다.
  /// 반환 형태: [{'header': 'ㄱ'}, country, country, {'header': 'ㄴ'}, ...]
  List<dynamic> _buildGroupedList() {
    if (_filtered.isEmpty) return [];

    final List<dynamic> result = [];
    String? lastGroup;

    for (final country in _filtered) {
      final nameKo = (country['country_name_ko'] as String?) ?? '';
      final group = _extractChosung(nameKo);
      if (group != lastGroup) {
        lastGroup = group;
        result.add({'_header': group});
      }
      result.add(country);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    final navBarBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = keyboardBottom > 0 ? keyboardBottom : navBarBottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            _buildSearchField(),
            const Divider(height: 1, color: AppTokens.line03),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Drag handle
  // ---------------------------------------------------------------------------

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spacing10),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTokens.bgBasic05,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header: 제목 + 닫기 버튼
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacing16,
        vertical: AppTokens.spacing12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '국가 선택',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize18,
                fontWeight: AppTokens.fontWeightSemibold,
                color: AppTokens.text05,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              size: 24,
              color: AppTokens.text03,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search field
  // ---------------------------------------------------------------------------

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacing16,
      ).copyWith(bottom: AppTokens.spacing12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTokens.bgBasic04,
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            color: AppTokens.text05,
          ),
          decoration: InputDecoration(
            hintText: '국가명 또는 국가코드 검색',
            hintStyle: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              color: AppTokens.text02,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppTokens.text03,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppTokens.spacing12,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body: 그룹핑된 국가 목록 or 빈 상태
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    final grouped = _buildGroupedList();

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spacing40),
          child: Text(
            '검색 결과가 없습니다',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              color: AppTokens.text03,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.spacing20),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final item = grouped[index];
        if (item is Map && item.containsKey('_header')) {
          return _buildSectionHeader(item['_header'] as String);
        }
        return _buildCountryItem(item as Map<String, dynamic>);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section header (초성 그룹)
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacing16,
        vertical: AppTokens.spacing8,
      ),
      color: AppTokens.bgBasic03,
      child: Text(
        label,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize12,
          fontWeight: AppTokens.fontWeightSemibold,
          color: AppTokens.text03,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Country item
  // ---------------------------------------------------------------------------

  Widget _buildCountryItem(Map<String, dynamic> country) {
    final String code = (country['country_code'] as String?) ?? '';
    final String nameKo = (country['country_name_ko'] as String?) ?? '';
    final bool isSelected =
        widget.selectedCountryCode != null &&
        code.toLowerCase() == widget.selectedCountryCode!.toLowerCase();

    return InkWell(
      onTap: () => Navigator.of(context).pop(country),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacing16,
          vertical: AppTokens.spacing12,
        ),
        child: Row(
          children: [
            // 국기
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 28,
                height: 20,
                child: CountryFlag.fromCountryCode(
                  code.toLowerCase(),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spacing12),
            // 국가명
            Expanded(
              child: Text(
                nameKo,
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: isSelected
                      ? AppTokens.fontWeightSemibold
                      : AppTokens.fontWeightRegular,
                  color: isSelected ? AppTokens.primaryTeal : AppTokens.text05,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            // 선택 체크
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C896),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.check,
                  size: 14,
                  color: AppTokens.bgBasic01,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

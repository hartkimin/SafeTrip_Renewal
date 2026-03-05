import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/travel_guide_service.dart';

class SearchModal extends StatefulWidget {

  const SearchModal({
    super.key,
    required this.countryCode,
    required this.onResultTap,
  });
  final String countryCode;
  final Function(String sectionId) onResultTap;

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final TravelGuideService _guideService = TravelGuideService();
  List<GuideSearchResult> _searchResults = [];
  bool _isSearching = false;
  String _currentQuery = '';

  final List<String> _recommendedQueries = [
    '여권 분실',
    '대마',
    '소매치기',
    '뎅기열',
    '전자담배',
    '마약',
    '교통사고',
    '응급실',
    '대사관',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      final results = await _guideService.searchGuides(
        query: query,
        countryCode: widget.countryCode,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[SearchModal] 검색 실패: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _onRecommendedQueryTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  String _getSectionTitle(String sectionId) {
    final titles = {
      'country_info': '기본 정보',
      'emergency_contacts': '긴급 연락처',
      'travel_alert': '여행 경보',
      'safety_incidents': '위험 & 사건사고',
      'entry_exit': '입국 & 세관',
      'cultural_safety': '법률 & 문화',
      'transportation': '교통 안전',
      'health_medical': '보건 & 의료',
      'additional_safety': '여행자 안전',
    };
    return titles[sectionId] ?? sectionId;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTokens.basic07, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '안전 정보 검색',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTokens.basic05),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTokens.basic05),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.trim().isNotEmpty) {
                        _performSearch(value);
                      } else {
                        setState(() {
                          _searchResults = [];
                        });
                      }
                    },
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
          // 콘텐츠
          Expanded(
            child: _currentQuery.isEmpty
                ? _buildRecommendedQueries()
                : _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: AppTokens.basic06),
                                SizedBox(height: 16),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: TextStyle(fontSize: 16, color: AppTokens.basic08),
                                ),
                              ],
                            ),
                          )
                        : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedQueries() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추천 검색어',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recommendedQueries.map((query) {
              return InkWell(
                onTap: () => _onRecommendedQueryTap(query),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTokens.bgBasic04,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTokens.basic05),
                  ),
                  child: Text(
                    query,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(GuideSearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 첫 번째 매칭된 섹션으로 이동
          if (result.matchedSections.isNotEmpty) {
            final sectionId = result.matchedSections.first
                .replaceAll('_', '')
                .replaceAll('countryinfo', 'basic')
                .replaceAll('emergencycontacts', 'emergency')
                .replaceAll('travelalert', 'risk')
                .replaceAll('safetyincidents', 'risk')
                .replaceAll('entryexit', 'entry')
                .replaceAll('culturalsafety', 'legal')
                .replaceAll('transportation', 'transport')
                .replaceAll('healthmedical', 'health')
                .replaceAll('additionalsafety', 'safety');
            
            widget.onResultTap(sectionId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    result.countryNameKo ?? result.countryCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (result.matchedSections.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getSectionTitle(result.matchedSections.first),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (result.snippet.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  result.snippet,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (result.matchedSections.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: result.matchedSections.skip(1).take(3).map((section) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.bgBasic04,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSectionTitle(section),
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


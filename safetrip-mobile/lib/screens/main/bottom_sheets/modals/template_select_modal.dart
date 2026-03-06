import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/api_service.dart';

/// 템플릿 카테고리 데이터
class _TemplateCategory {
  const _TemplateCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// 템플릿 데이터
class _TemplateItem {
  const _TemplateItem({
    required this.templateId,
    required this.title,
    required this.description,
    required this.itemCount,
  });

  final String templateId;
  final String title;
  final String description;
  final int itemCount;
}

/// 템플릿 상세 아이템 데이터
class _TemplateDetail {
  const _TemplateDetail({
    required this.title,
    required this.scheduleType,
    this.locationName,
    this.duration,
  });

  final String title;
  final String scheduleType;
  final String? locationName;
  final String? duration;
}

/// 템플릿 선택 모달
/// 1단계: 카테고리 그리드 -> 2단계: 템플릿 목록 -> 3단계: 미리보기 -> 적용
class TemplateSelectModal extends StatefulWidget {
  const TemplateSelectModal({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  State<TemplateSelectModal> createState() => _TemplateSelectModalState();
}

class _TemplateSelectModalState extends State<TemplateSelectModal> {
  final ApiService _apiService = ApiService();

  // 기본 카테고리 목록
  static const List<_TemplateCategory> _categories = [
    _TemplateCategory(
        id: 'japan', label: '\uC77C\uBCF8', icon: Icons.temple_buddhist), // 일본
    _TemplateCategory(
        id: 'europe', label: '\uC720\uB7FD', icon: Icons.account_balance), // 유럽
    _TemplateCategory(
        id: 'southeast_asia',
        label: '\uB3D9\uB0A8\uC544',
        icon: Icons.beach_access), // 동남아
    _TemplateCategory(
        id: 'usa', label: '\uBBF8\uAD6D', icon: Icons.location_city), // 미국
    _TemplateCategory(
        id: 'korea',
        label: '\uAD6D\uB0B4 \uC5EC\uD589',
        icon: Icons.landscape), // 국내 여행
    _TemplateCategory(
        id: 'oceania',
        label: '\uC624\uC138\uC544\uB2C8\uC544',
        icon: Icons.surfing), // 오세아니아
    _TemplateCategory(
        id: 'china',
        label: '\uC911\uAD6D/\uB300\uB9CC',
        icon: Icons.festival), // 중국/대만
    _TemplateCategory(
        id: 'other',
        label: '\uAE30\uD0C0',
        icon: Icons.public), // 기타
  ];

  // 현재 상태
  int _step = 0; // 0: 카테고리, 1: 템플릿 목록, 2: 미리보기
  String? _selectedCategoryLabel;
  _TemplateItem? _selectedTemplate;

  List<_TemplateItem> _templates = [];
  List<_TemplateDetail> _templateDetails = [];
  bool _isLoading = false;
  bool _isApplying = false;
  String? _error;

  Future<void> _fetchTemplates(String categoryId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.dio.get(
        '/api/v1/templates',
        queryParameters: {'category': categoryId},
      );
      if (result.data?['success'] == true && mounted) {
        final data = result.data['data'];
        final list = data is Map
            ? (data['templates'] ?? []) as List
            : (data is List ? data : []);

        setState(() {
          _templates = list.map((t) {
            final map = t as Map<String, dynamic>;
            return _TemplateItem(
              templateId: map['template_id']?.toString() ?? '',
              title: map['title'] as String? ?? '',
              description: map['description'] as String? ?? '',
              itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              '\uD15C\uD50C\uB9BF \uBAA9\uB85D\uC744 \uBD88\uB7EC\uC62C \uC218 \uC5C6\uC2B5\uB2C8\uB2E4'; // 템플릿 목록을 불러올 수 없습니다
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTemplateDetail(String templateId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.dio.get(
        '/api/v1/templates/$templateId',
      );
      if (result.data?['success'] == true && mounted) {
        final data = result.data['data'];
        final items = data is Map
            ? (data['items'] ?? data['schedules'] ?? []) as List
            : (data is List ? data : []);

        setState(() {
          _templateDetails = items.map((item) {
            final map = item as Map<String, dynamic>;
            return _TemplateDetail(
              title: map['title'] as String? ?? '',
              scheduleType:
                  map['schedule_type'] as String? ?? 'other',
              locationName: map['location_name'] as String?,
              duration: map['duration'] as String?,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              '\uD15C\uD50C\uB9BF \uC0C1\uC138 \uC815\uBCF4\uB97C \uBD88\uB7EC\uC62C \uC218 \uC5C6\uC2B5\uB2C8\uB2E4'; // 템플릿 상세 정보를 불러올 수 없습니다
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyTemplate() async {
    if (_selectedTemplate == null || _isApplying) return;

    setState(() => _isApplying = true);

    try {
      final result = await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/schedules/from-template',
        data: {'template_id': _selectedTemplate!.templateId},
      );
      if (result.data?['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${_selectedTemplate!.title}" \uD15C\uD50C\uB9BF\uC774 \uC801\uC6A9\uB418\uC5C8\uC2B5\uB2C8\uB2E4', // 템플릿이 적용되었습니다
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\uD15C\uD50C\uB9BF \uC801\uC6A9\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4'), // 템플릿 적용에 실패했습니다
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _selectCategory(_TemplateCategory category) {
    setState(() {
      _selectedCategoryLabel = category.label;
      _step = 1;
    });
    _fetchTemplates(category.id);
  }

  void _selectTemplate(_TemplateItem template) {
    setState(() {
      _selectedTemplate = template;
      _step = 2;
    });
    _fetchTemplateDetail(template.templateId);
  }

  void _goBack() {
    setState(() {
      if (_step == 2) {
        _step = 1;
        _selectedTemplate = null;
        _templateDetails = [];
      } else if (_step == 1) {
        _step = 0;
        _selectedCategoryLabel = null;
        _templates = [];
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.bottomSheetRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: AppSpacing.bottomSheetHandleWidth,
              height: AppSpacing.bottomSheetHandleHeight,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(
                    AppSpacing.bottomSheetHandleHeight / 2),
              ),
            ),
          ),
          // 헤더
          _buildHeader(),
          // 콘텐츠
          Flexible(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (_step) {
      case 0:
        title = '\uD15C\uD50C\uB9BF \uC120\uD0DD'; // 템플릿 선택
        break;
      case 1:
        title = _selectedCategoryLabel ?? '\uD15C\uD50C\uB9BF'; // 템플릿
        break;
      case 2:
        title = _selectedTemplate?.title ?? '\uBBF8\uB9AC\uBCF4\uAE30'; // 미리보기
        break;
      default:
        title = '\uD15C\uD50C\uB9BF'; // 템플릿
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (_step > 0)
            GestureDetector(
              onTap: _goBack,
              child: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const Icon(
            Icons.dashboard_customize_outlined,
            size: 20,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('\uB3CC\uC544\uAC00\uAE30'), // 돌아가기
              ),
            ],
          ),
        ),
      );
    }

    switch (_step) {
      case 0:
        return _buildCategoryGrid();
      case 1:
        return _buildTemplateList();
      case 2:
        return _buildTemplatePreview();
      default:
        return const SizedBox.shrink();
    }
  }

  /// 1단계: 카테고리 그리드
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.85,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return GestureDetector(
            onTap: () => _selectCategory(cat),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radius12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cat.icon,
                    size: 28,
                    color: AppColors.primaryTeal,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    cat.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 2단계: 템플릿 목록
  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            '\uC774 \uCE74\uD14C\uACE0\uB9AC\uC5D0 \uD15C\uD50C\uB9BF\uC774 \uC5C6\uC2B5\uB2C8\uB2E4', // 이 카테고리에 템플릿이 없습니다
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: _templates.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final template = _templates[index];
        return GestureDetector(
          onTap: () => _selectTemplate(template),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.circular(AppSpacing.radius12),
              border:
                  Border.all(color: AppColors.outlineVariant, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (template.description.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            template.description,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '${template.itemCount}\uAC1C \uC77C\uC815', // N개 일정
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 3단계: 템플릿 미리보기 + 적용 버튼
  Widget _buildTemplatePreview() {
    return Column(
      children: [
        Expanded(
          child: _templateDetails.isEmpty
              ? Center(
                  child: Text(
                    '\uD15C\uD50C\uB9BF \uD56D\uBAA9\uC774 \uC5C6\uC2B5\uB2C8\uB2E4', // 템플릿 항목이 없습니다
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: _templateDetails.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final detail = _templateDetails[index];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.title,
                                  style:
                                      AppTypography.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (detail.locationName != null)
                                  Text(
                                    detail.locationName!,
                                    style:
                                        AppTypography.bodySmall.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (detail.duration != null)
                            Text(
                              detail.duration!,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // 적용 버튼
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isApplying ? null : _applyTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radius12),
                ),
              ),
              child: _isApplying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '\uC801\uC6A9', // 적용
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../constants/app_tokens.dart';
import 'add_schedule_direct_modal.dart';

class AddScheduleModal extends StatefulWidget {
  const AddScheduleModal({super.key});

  @override
  State<AddScheduleModal> createState() => _AddScheduleModalState();
}

class _AddScheduleModalState extends State<AddScheduleModal> {
  String? _selectedOption; // 선택된 옵션

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic01,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border(
                  bottom: BorderSide(width: 1, color: AppTokens.line03),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 뒤로가기 버튼
                  InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 4, right: 12, top: 12, bottom: 12),
                      child: const Icon(
                        FontAwesomeIcons.angleLeft,
                        color: AppTokens.text05,
                        size: 24,
                      ),
                    ),
                  ),
                  // 제목
                  Expanded(
                    child: Text(
                      '일정 추가하기',
                      textAlign: TextAlign.center,
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize16,
                        fontWeight: AppTokens.fontWeightRegular,
                        color: AppTokens.text05,
                        letterSpacing: AppTokens.letterSpacingNeg15,
                        height: 1.36,
                      ),
                    ),
                  ),
                  // 오른쪽 공간 (대칭을 위해)
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            // 메인 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 28,
                  left: 24,
                  right: 24,
                  bottom: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 질문 텍스트
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '어떤 방법으로 ',
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize20,
                              fontWeight: AppTokens.fontWeightRegular,
                              color: AppTokens.text05,
                              letterSpacing: AppTokens.letterSpacingNeg2,
                              height: 1.40,
                            ),
                          ),
                          TextSpan(
                            text: '일정',
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize20,
                              fontWeight: AppTokens.fontWeightRegular,
                              color: AppTokens.text06,
                              letterSpacing: AppTokens.letterSpacingNeg2,
                              height: 1.40,
                            ),
                          ),
                          TextSpan(
                            text: '을 추가할까요?',
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize20,
                              fontWeight: AppTokens.fontWeightRegular,
                              color: AppTokens.text05,
                              letterSpacing: AppTokens.letterSpacingNeg2,
                              height: 1.40,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 옵션 카드들
                    _buildOptionCard(
                      id: 'direct',
                      title: '직접 추가',
                      description: '날짜·시간·알림·유형을 직접 입력해요',
                      icon: FontAwesomeIcons.pencil,
                      isSelected: _selectedOption == 'direct',
                      onTap: () {
                        setState(() {
                          _selectedOption = 'direct';
                        });
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const AddScheduleDirectModal(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 13),
                    _buildOptionCard(
                      id: 'text',
                      title: '텍스트 자동 변환',
                      description: '붙여넣기만 해도 일정 자동 정리돼요',
                      icon: FontAwesomeIcons.clipboard,
                      isSelected: _selectedOption == 'text',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('텍스트 자동 변환 기능은 추후에 제공됩니다'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 13),
                    _buildOptionCard(
                      id: 'ai',
                      title: 'AI 일정 자동 생성',
                      description: 'AI와 대화하며 여행 일정을 만들어요',
                      icon: FontAwesomeIcons.wandMagicSparkles,
                      isSelected: _selectedOption == 'ai',
                      hasPopularBadge: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI 일정 자동 생성 기능은 추후에 제공됩니다'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    bool isSelected = false,
    bool hasPopularBadge = false,
    required VoidCallback onTap,
  }) {
    // 선택 상태에 따른 색상 결정
    final backgroundColor = isSelected
        ? AppTokens.bgTeal02
        : AppTokens.bgBasic01;
    final borderColor = isSelected ? AppTokens.line06 : AppTokens.line03;
    final iconBackgroundColor = isSelected
        ? AppTokens.bgTeal04
        : AppTokens.bgTeal03;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 72,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTokens.primaryTeal, size: 24),
            ),
            const SizedBox(width: 8),
            // 텍스트 영역
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 제목 (인기 배지 포함)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize14,
                            fontWeight: AppTokens.fontWeightMedium,
                            color: AppTokens.text05,
                            letterSpacing: AppTokens.letterSpacingNeg03,
                            height: 1.20,
                          ),
                        ),
                      ),
                      if (hasPopularBadge) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTokens.bgTeal04,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '인기',
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize12,
                              fontWeight: AppTokens.fontWeightRegular,
                              color: AppTokens.text05,
                              letterSpacing: AppTokens.letterSpacingNeg03,
                              height: 1.20,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  // 설명
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text03,
                      letterSpacing: AppTokens.letterSpacingNeg03,
                      height: 1.20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

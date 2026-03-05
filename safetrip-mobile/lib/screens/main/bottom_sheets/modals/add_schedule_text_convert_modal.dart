import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../constants/app_tokens.dart';

class AddScheduleTextConvertModal extends StatefulWidget {
  const AddScheduleTextConvertModal({super.key});

  @override
  State<AddScheduleTextConvertModal> createState() =>
      _AddScheduleTextConvertModalState();
}

class _AddScheduleTextConvertModalState
    extends State<AddScheduleTextConvertModal> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBasic01,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border(
                  bottom: BorderSide(
                    width: 1,
                    color: AppTokens.line03,
                  ),
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
                      '텍스트 자동 변환',
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
                  const SizedBox(
                    width: 48,
                    height: 48,
                  ),
                ],
              ),
            ),
            // 메인 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 31),
                    // 꼭! 확인해주세요 섹션
                    Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: Icon(
                            FontAwesomeIcons.circleInfo,
                            size: 22,
                            color: AppTokens.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '꼭! 확인해주세요. ',
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize16,
                            fontWeight: AppTokens.fontWeightRegular,
                            color: AppTokens.text05,
                            letterSpacing: AppTokens.letterSpacingNeg15,
                            height: 1.36,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 안내 정보 박스
                    _buildInfoBox(),
                    const SizedBox(height: 16),
                    // 텍스트 붙여넣기 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '텍스트 붙여넣기',
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize14,
                            fontWeight: AppTokens.fontWeightRegular,
                            color: AppTokens.text05,
                            letterSpacing: AppTokens.letterSpacingNeg1,
                            height: 1.40,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // 등록된 장소 불러오기
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FontAwesomeIcons.locationDot,
                                size: 16,
                                color: AppTokens.text06,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '등록된 장소 불러오기',
                                style: AppTokens.textStyle(
                                  fontSize: AppTokens.fontSize14,
                                  fontWeight: AppTokens.fontWeightRegular,
                                  color: AppTokens.text06,
                                  letterSpacing: AppTokens.letterSpacingNeg1,
                                  height: 1.40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 텍스트 입력 필드
                    _buildTextInputField(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // 하단 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border(
                  top: BorderSide(
                    width: 1,
                    color: AppTokens.line02,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 미리보기 버튼
                  Container(
                    width: 96,
                    height: 54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTokens.bgBasic01,
                      border: Border.all(
                        width: 1,
                        color: AppTokens.line02,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 1,
                          offset: Offset(0, 0),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Color(0x02000000),
                          blurRadius: 2,
                          offset: Offset(0, 2),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Color(0x02000000),
                          blurRadius: 4,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // 미리보기 기능
                      },
                      child: Center(
                        child: Text(
                          '미리보기',
                          textAlign: TextAlign.center,
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize16,
                            fontWeight: AppTokens.fontWeightSemibold,
                            color: AppTokens.text05,
                            letterSpacing: AppTokens.letterSpacingNeg15,
                            height: 1.36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 텍스트 자동 변환 버튼
                  Expanded(
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.primaryTeal,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2813BAC8),
                            blurRadius: 12,
                            offset: Offset(-1, 5),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () {
                          // 텍스트 자동 변환 기능
                          Navigator.of(context).pop();
                        },
                        child: Center(
                          child: Text(
                            '텍스트 자동 변환',
                            textAlign: TextAlign.center,
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize16,
                              fontWeight: AppTokens.fontWeightSemibold,
                              color: AppTokens.text01,
                              letterSpacing: AppTokens.letterSpacingNeg15,
                              height: 1.36,
                            ),
                          ),
                        ),
                      ),
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

  // 안내 정보 박스
  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic03,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppTokens.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '1',
                    textAlign: TextAlign.center,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      fontWeight: AppTokens.fontWeightSemibold,
                      color: AppTokens.text01,
                      letterSpacing: AppTokens.letterSpacingNeg03,
                      height: 1.40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '카톡·메모를 붙여넣으면 일정이 자동으로 정리돼요',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize14,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text05,
                    letterSpacing: AppTokens.letterSpacingNeg1,
                    height: 1.40,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppTokens.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '2',
                    textAlign: TextAlign.center,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      fontWeight: AppTokens.fontWeightSemibold,
                      color: AppTokens.text01,
                      letterSpacing: AppTokens.letterSpacingNeg03,
                      height: 1.40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '장소명 앞에 ',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: AppTokens.text05,
                          letterSpacing: AppTokens.letterSpacingNeg1,
                          height: 1.40,
                        ),
                      ),
                      TextSpan(
                        text: '@',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightSemibold,
                          color: AppTokens.text06,
                          letterSpacing: AppTokens.letterSpacingNeg1,
                          height: 1.40,
                        ),
                      ),
                      TextSpan(
                        text: '를 붙이면 더 정확하게 인식돼요',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: AppTokens.text05,
                          letterSpacing: AppTokens.letterSpacingNeg1,
                          height: 1.40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 텍스트 입력 필드
  Widget _buildTextInputField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        border: Border.all(
          width: 1.5,
          color: AppTokens.line03,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        minLines: 10,
        decoration: InputDecoration(
          hintText:
              '카톡이나 메모를 그대로 붙여넣어 보세요\n\n자동으로 정리된 예시)\n2025년 1월 15일\n오전 10시 센소지 관람 @센소지',
          hintStyle: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightRegular,
            color: AppTokens.text02,
            letterSpacing: AppTokens.letterSpacingNeg1,
            height: 1.40,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize14,
          fontWeight: AppTokens.fontWeightRegular,
          color: AppTokens.text05,
          letterSpacing: AppTokens.letterSpacingNeg1,
          height: 1.40,
        ),
        inputFormatters: const [
          // 붙여넣기 지원
        ],
      ),
    );
  }
}






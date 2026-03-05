import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';

/// 출석체크 모달
class AttendanceModal extends StatefulWidget {

  const AttendanceModal({
    super.key,
    required this.members,
    this.groupId,
  });
  final List<Map<String, dynamic>> members;
  final String? groupId;

  @override
  State<AttendanceModal> createState() => _AttendanceModalState();
}

class _AttendanceModalState extends State<AttendanceModal> {
  bool _isStarted = false;
  final Map<String, bool> _attendanceStatus = {}; // user_id -> 출석 여부

  @override
  void initState() {
    super.initState();
    // 초기 상태: 모든 멤버 미확인
    for (final member in widget.members) {
      final userId = member['user_id'] as String?;
      if (userId != null) {
        _attendanceStatus[userId] = false;
      }
    }
  }

  void _startAttendance() {
    setState(() {
      _isStarted = true;
    });
  }

  void _markAsAttended(String userId) {
    setState(() {
      _attendanceStatus[userId] = true;
    });
  }

  void _endAttendance() {
    setState(() {
      _isStarted = false;
      _attendanceStatus.clear();
      for (final member in widget.members) {
        final userId = member['user_id'] as String?;
        if (userId != null) {
          _attendanceStatus[userId] = false;
        }
      }
    });
    Navigator.pop(context);
  }

  int get _totalCount => widget.members.length;
  int get _attendedCount => _attendanceStatus.values.where((v) => v).length;
  double get _progress => _totalCount > 0 ? _attendedCount / _totalCount : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radius20),
          topRight: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(AppTokens.spacing16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTokens.line03),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '출석체크',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize20,
                    fontWeight: AppTokens.fontWeightBold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTokens.text05,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // 대시보드
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isStarted) ...[
                    // 시작 전
                    _buildStartSection(),
                  ] else ...[
                    // 진행 중
                    _buildProgressSection(),
                    const SizedBox(height: AppTokens.spacing24),
                    _buildMemberList(),
                  ],
                ],
              ),
            ),
          ),
          
          // 하단 버튼
          if (_isStarted)
            Container(
              padding: EdgeInsets.only(
                left: AppTokens.spacing16,
                right: AppTokens.spacing16,
                top: AppTokens.spacing16,
                bottom: AppTokens.spacing16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTokens.line03),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _endAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.semanticError,
                    padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radius12),
                    ),
                  ),
                  child: Text(
                    '출석체크 종료',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightSemibold,
                      color: AppTokens.text01,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 시작 섹션
  Widget _buildStartSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppTokens.spacing32),
          Text(
            '전체 인원',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              color: AppTokens.text04,
            ),
          ),
          const SizedBox(height: AppTokens.spacing8),
          Text(
            '$_totalCount명',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize36,
              fontWeight: AppTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppTokens.spacing48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.text06,
                padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius12),
                ),
              ),
              child: Text(
                '시작하기',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize16,
                  fontWeight: AppTokens.fontWeightSemibold,
                  color: AppTokens.text01,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 진행률 섹션
  Widget _buildProgressSection() {
    return Column(
      children: [
        // 진행률 원형 차트
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 배경 원
              const SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.bgBasic03),
                ),
              ),
              // 진행 원
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.semanticSuccess),
                ),
              ),
              // 중앙 텍스트
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize24,
                      fontWeight: AppTokens.fontWeightBold,
                      color: AppTokens.text05,
                    ),
                  ),
                  Text(
                    '$_attendedCount / $_totalCount',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      color: AppTokens.text04,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTokens.spacing16),
        
        // 현황 텍스트
        Text(
          '$_attendedCount명 확인완료 / $_totalCount명 전체',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            color: AppTokens.text05,
          ),
        ),
      ],
    );
  }

  // 멤버 리스트
  Widget _buildMemberList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '멤버 목록',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize16,
            fontWeight: AppTokens.fontWeightSemibold,
          ),
        ),
        const SizedBox(height: AppTokens.spacing12),
        ...widget.members.map((member) {
          final userId = member['user_id'] as String?;
          final userName = member['display_name'] as String? ?? 
                          member['user_name'] as String? ?? 'Unknown';
          final isAttended = userId != null ? _attendanceStatus[userId] ?? false : false;
          
          return _buildMemberItem(
            userId: userId ?? '',
            userName: userName,
            isAttended: isAttended,
          );
        }),
      ],
    );
  }

  // 멤버 아이템
  Widget _buildMemberItem({
    required String userId,
    required String userName,
    required bool isAttended,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spacing12),
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: BoxDecoration(
        color: isAttended ? AppTokens.bgTeal01 : AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
          color: isAttended ? AppTokens.text06 : AppTokens.basic03,
        ),
      ),
      child: Row(
        children: [
          // 체크 아이콘
          if (isAttended)
            const Icon(
              Icons.check_circle,
              color: AppTokens.semanticSuccess,
              size: 24,
            )
          else
            const Icon(
              Icons.radio_button_unchecked,
              color: AppTokens.text03,
              size: 24,
            ),
          
          const SizedBox(width: AppTokens.spacing12),
          
          // 이름
          Expanded(
            child: Text(
              userName,
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize14,
                fontWeight: isAttended 
                    ? AppTokens.fontWeightMedium 
                    : AppTokens.fontWeightRegular,
                color: isAttended ? AppTokens.text05 : AppTokens.text04,
              ),
            ),
          ),
          
          // 확인 처리 버튼
          if (!isAttended)
            TextButton(
              onPressed: () => _markAsAttended(userId),
              child: Text(
                '확인 처리',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize12,
                  color: AppTokens.text06,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


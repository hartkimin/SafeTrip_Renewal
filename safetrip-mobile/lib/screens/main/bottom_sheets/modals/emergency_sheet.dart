import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../models/mofa_country_info.dart';
import '../../../../services/mofa_service.dart';

class EmergencySheet extends StatefulWidget {

  const EmergencySheet({
    super.key,
    required this.countryCode,
  });
  final String countryCode;

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  late final MofaService _mofaService;
  MofaContactInfo? _contactInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _mofaService = MofaService();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final contacts = await _mofaService.getContactInfo(widget.countryCode);
      if (mounted) {
        setState(() {
          _contactInfo = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[EmergencySheet] 데이터 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;

    // 공백 및 특수문자 제거
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전화를 걸 수 없습니다: $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Text(
                '긴급 연락처',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 로딩 또는 콘텐츠
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_contactInfo == null)
            const Center(child: Text('연락처 정보를 불러올 수 없습니다.'))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 영사 콜센터 (가장 크게 강조)
                    _buildPrimaryEmergencyButton(
                      label: '영사콜센터 (24시간)',
                      phone: '+82-2-3210-0404',
                      icon: Icons.phone_in_talk,
                    ),
                    const SizedBox(height: 24),

                    // 재외공관 긴급 연락처
                    if (_contactInfo!.embassies.isNotEmpty) ...[
                      const Text(
                        '재외공관 긴급 연락처',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ..._contactInfo!.embassies.map((embassy) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (embassy.embassyNm != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  embassy.embassyNm!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            // 긴급 전화
                            if (embassy.emergencyTelNo != null &&
                                embassy.emergencyTelNo!.isNotEmpty)
                              _buildEmergencyButton(
                                label: '긴급 전화',
                                phone: embassy.emergencyTelNo!,
                                icon: Icons.phone_in_talk,
                                color: AppTokens.semanticError,
                              ),
                            // 대표 전화
                            if (embassy.telNo != null &&
                                embassy.telNo!.isNotEmpty)
                              _buildEmergencyButton(
                                label: '대표 전화',
                                phone: embassy.telNo!,
                                icon: Icons.phone,
                                color: Colors.grey[700]!,
                              ),
                            // 주소
                            if (embassy.embassyAddr != null &&
                                embassy.embassyAddr!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey[500]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        embassy.embassyAddr!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTokens.basic08,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                      const SizedBox(height: 24),
                    ],

                    // 안내 문구
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTokens.bgBasic03,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.grey[500]),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '해외에서 영사콜센터 연결:\n현지 국제전화코드 + 822-3210-0404',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTokens.basic08,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryEmergencyButton({
    required String label,
    required String phone,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: InkWell(
        onTap: () => _makePhoneCall(phone),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppTokens.semanticError),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTokens.semanticError,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTokens.semanticError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required String label,
    required String phone,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _makePhoneCall(phone),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.bgBasic01,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppTokens.basic08),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../utils/app_cache.dart';
import '../../../../services/api_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../models/geofence.dart';
import '../../../../models/schedule.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class AddScheduleDirectModal extends StatefulWidget { // 수정 모드일 때 기존 일정 데이터

  const AddScheduleDirectModal({
    super.key,
    this.schedule,
  });
  final Schedule? schedule;

  @override
  State<AddScheduleDirectModal> createState() => _AddScheduleDirectModalState();
}

class _AddScheduleDirectModalState extends State<AddScheduleDirectModal> {
  // 폼 상태
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController(); // 장소명
  final TextEditingController _locationController = TextEditingController(); // 주소 검색

  String? _selectedScheduleType; // 선택된 일정 유형
  bool _notificationEnabled = true; // 알림 설정 활성화
  bool _locationNotificationEnabled = true; // 장소 알림 설정 활성화
  bool _arrivalNotification = true; // 도착 알림
  bool _departureNotification = true; // 이탈 알림

  // 시작일시/종료일시 선택
  DateTime _selectedStartDateTime = DateTime.now();
  DateTime _selectedEndDateTime = DateTime.now().add(const Duration(hours: 1));

  // 장소 좌표
  double? _locationLatitude;
  double? _locationLongitude;

  // 지오펜스 관련 상태
  bool _geofenceEnabled = false; // 지오펜스 등록 체크박스 상태
  int _geofenceRadius = 200; // 지오펜스 반경 (50-1000m)
  bool _isGeofenceFromExisting = false; // 기존 지오펜스에서 선택했는지 여부
  String? _selectedGeofenceId; // 선택된 기존 지오펜스 ID

  // 검색 관련 상태
  List<Map<String, dynamic>> _searchLocationResults = []; // 추천 장소 검색 결과
  List<GeofenceData> _searchGeofenceResults = []; // 추천 지오펜스 검색 결과
  bool _isSearchResultsExpanded = false; // 검색 결과 드롭다운 확장 여부

  // 지도 관련 상태
  MapController? _mapController;

  // 타임존
  String? _selectedTimezone;
  List<Map<String, dynamic>> _availableTimezones = [];
  bool _isLoadingTimezones = false;
  bool _isTimezoneExpanded = false;

  // 로딩 상태
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  // 일정 유형 목록 (7 types — 원칙 문서 기준)
  final List<Map<String, dynamic>> _scheduleTypes = [
    {'id': 'move', 'label': '이동', 'icon': FontAwesomeIcons.plane},
    {'id': 'stay', 'label': '숙박', 'icon': FontAwesomeIcons.hotel},
    {'id': 'meal', 'label': '식사', 'icon': FontAwesomeIcons.utensils},
    {'id': 'sightseeing', 'label': '관광', 'icon': FontAwesomeIcons.locationDot},
    {'id': 'shopping', 'label': '쇼핑', 'icon': FontAwesomeIcons.bagShopping},
    {'id': 'meeting', 'label': '모임', 'icon': FontAwesomeIcons.userGroup},
    {'id': 'other', 'label': '기타', 'icon': FontAwesomeIcons.thumbtack},
  ];

  @override
  void initState() {
    super.initState();
    _loadTimezones();
    if (widget.schedule != null) {
      // 수정 모드: 기존 일정 데이터 로드
      _loadScheduleData(widget.schedule!);
    } else {
      // 생성 모드: 현재 위치 로드
      _loadCurrentLocation();
    }
  }

  // 기존 일정 데이터 로드
  void _loadScheduleData(Schedule schedule) {
    _titleController.text = schedule.title;
    if (schedule.description != null) {
      _memoController.text = schedule.description!;
    }
    _selectedScheduleType = schedule.scheduleType;
    _selectedStartDateTime = schedule.startTime;
    if (schedule.endTime != null) {
      _selectedEndDateTime = schedule.endTime!;
    }
    if (schedule.locationName != null) {
      _placeNameController.text = schedule.locationName!;
    }
    if (schedule.locationAddress != null) {
      _locationController.text = schedule.locationAddress!;
    }
    if (schedule.locationCoords != null) {
      _locationLatitude = schedule.locationCoords!['latitude'];
      _locationLongitude = schedule.locationCoords!['longitude'];
    }
    _notificationEnabled = schedule.reminderEnabled;
    // 지오펜스 정보 로드
    if (schedule.geofenceId != null && schedule.groupId != null) {
      _loadGeofenceInfo(schedule.groupId!, schedule.geofenceId!);
    }
  }

  // 지오펜스 정보 로드 (PostgreSQL에서 직접 조회)
  Future<void> _loadGeofenceInfo(String groupId, String geofenceId) async {
    try {
      final geofenceData = await _apiService.getGeofenceById(
        geofenceId: geofenceId,
        groupId: groupId,
      );

      if (geofenceData != null && mounted) {
        setState(() {
          _geofenceEnabled = true;
          _locationNotificationEnabled = true;
          
          // 이름 설정 (장소명 필드에만 설정)
          final geofenceName = geofenceData['name'] as String?;
          if (geofenceName != null && geofenceName.isNotEmpty) {
            _placeNameController.text = geofenceName;
          }
          
          // 좌표 파싱
          final centerLatitude = geofenceData['center_latitude'];
          final centerLongitude = geofenceData['center_longitude'];
          if (centerLatitude != null && centerLongitude != null) {
            _locationLatitude = centerLatitude is num 
                ? centerLatitude.toDouble() 
                : double.tryParse(centerLatitude.toString());
            _locationLongitude = centerLongitude is num 
                ? centerLongitude.toDouble() 
                : double.tryParse(centerLongitude.toString());
          }
          
          // 반경 파싱
          final radiusMeters = geofenceData['radius_meters'];
          if (radiusMeters != null) {
            _geofenceRadius = radiusMeters is int 
                ? radiusMeters 
                : radiusMeters is num 
                    ? radiusMeters.toInt() 
                    : int.tryParse(radiusMeters.toString()) ?? 200;
          }
          
          _arrivalNotification = geofenceData['trigger_on_enter'] as bool? ?? true;
          _departureNotification = geofenceData['trigger_on_exit'] as bool? ?? true;
          _isGeofenceFromExisting = true;
          _selectedGeofenceId = geofenceId;
        });
        // 지도 카메라 업데이트
        if (_mapController != null && _locationLatitude != null && _locationLongitude != null) {
          _updateMapCamera();
        }
      }
    } catch (e) {
      debugPrint('[일정] 지오펜스 정보 로드 실패: $e');
    }
  }

  // 현재 위치 로드
  Future<void> _loadCurrentLocation() async {
    try {
      final locationService = LocationService();
      final location = await locationService.getCurrentPosition();
      if (location != null && mounted) {
        setState(() {
          _locationLatitude = location.coords.latitude;
          _locationLongitude = location.coords.longitude;
        });
        // 지도 컨트롤러가 생성되면 카메라 이동
        if (_mapController != null) {
          _updateMapCamera();
        }
      }
    } catch (e) {
      debugPrint('[일정] 현재 위치 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _placeNameController.dispose();
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // 타임존 목록 로드
  Future<void> _loadTimezones() async {
    setState(() {
      _isLoadingTimezones = true;
    });

    try {
      final groupId = await AppCache.groupId;
      if (groupId == null) {
        setState(() {
          _isLoadingTimezones = false;
        });
        return;
      }

      // 서버에서 이미 한국이 첫 번째로 정렬되어 있음
      final timezones = await _apiService.getTimezonesByGroupId(groupId);

      setState(() {
        _availableTimezones = timezones;
        // 첫 번째가 한국이므로 바로 선택
        if (timezones.isNotEmpty && _selectedTimezone == null) {
          _selectedTimezone = timezones.first['timezone'] as String;
        }
        _isLoadingTimezones = false;
      });
    } catch (e) {
      debugPrint('[일정] 타임존 로드 실패: $e');
      setState(() {
        _isLoadingTimezones = false;
      });
    }
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
                      widget.schedule != null ? '일정 수정' : '일정 직접 추가',
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
              child: GestureDetector(
                onTap: () {
                  // 다른 곳을 탭하면 포커스 제거 및 키보드 숨김
                  FocusScope.of(context).unfocus();
                  // 확장 박스 닫기
                  if (_isTimezoneExpanded) {
                    setState(() {
                      _isTimezoneExpanded = false;
                    });
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 29),
                      // 상세 일정 섹션
                      Text(
                        '상세 일정',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: const Color(0xFF354152),
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 일정 제목 입력 필드
                      _buildTitleInput(),
                      const SizedBox(height: 15),
                      // 국가 선택
                      _buildTimezoneSelector(),
                      const SizedBox(height: 15),
                      // 시작일시 선택
                      _buildDateTimeSelector(
                        label: '시작일시 *',
                        selectedDateTime: _selectedStartDateTime,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _selectedStartDateTime = dateTime;
                            // 종료일시가 시작일시보다 이전이면 종료일시를 시작일시 + 1시간으로 설정
                            if (_selectedEndDateTime.isBefore(dateTime) ||
                                _selectedEndDateTime.isAtSameMomentAs(
                                  dateTime,
                                )) {
                              _selectedEndDateTime = dateTime.add(
                                const Duration(hours: 1),
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      // 종료일시 선택
                      _buildDateTimeSelector(
                        label: '종료일시 *',
                        selectedDateTime: _selectedEndDateTime,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            // 종료일시가 시작일시보다 이전이면 시작일시로 설정
                            if (dateTime.isBefore(_selectedStartDateTime)) {
                              _selectedEndDateTime = _selectedStartDateTime.add(
                                const Duration(hours: 1),
                              );
                            } else {
                              _selectedEndDateTime = dateTime;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // 유형 섹션
                      Text(
                        '유형',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: const Color(0xFF354152),
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildScheduleTypeGrid(),
                      const SizedBox(height: 24),
                      // 장소 섹션
                      _buildLocationSection(),
                      const SizedBox(height: 24),
                      // 메모 섹션
                      _buildMemoInput(),
                      const SizedBox(height: 24),
                      // 일정 등록 버튼
                      _buildRegisterButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 일정 제목 입력 필드
  Widget _buildTitleInput() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        border: Border.all(width: 1, color: AppTokens.line03),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.only(left: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '일정 제목',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text04,
                    letterSpacing: AppTokens.letterSpacingNeg03,
                    height: 1.40,
                  ),
                ),
                TextSpan(
                  text: ' *',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text07,
                    letterSpacing: AppTokens.letterSpacingNeg03,
                    height: 1.40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: '예: 경복궁 방문',
              hintStyle: AppTokens.textStyle(
                fontSize: AppTokens.fontSize16,
                fontWeight: AppTokens.fontWeightRegular,
                color: AppTokens.text02,
                letterSpacing: AppTokens.letterSpacingNeg15,
                height: 1.36,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
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
    );
  }

  // 날짜/시간 포맷팅 헬퍼
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 시작일시/종료일시 선택
  Widget _buildDateTimeSelector({
    required String label,
    required DateTime selectedDateTime,
    required ValueChanged<DateTime> onDateTimeSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        // 날짜 선택
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDateTime,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (pickedDate == null) return;

        // 시간 선택
        if (!mounted) return;
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
        );
        if (pickedTime == null) return;

        // 날짜와 시간 결합
        final DateTime combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        onDateTimeSelected(combinedDateTime);
      },
      child: Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppTokens.bgBasic01,
          border: Border.all(width: 1, color: AppTokens.line03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text04,
                      letterSpacing: AppTokens.letterSpacingNeg03,
                      height: 1.40,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(selectedDateTime),
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize16,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text05,
                      letterSpacing: -0.5,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(FontAwesomeIcons.clock, size: 20, color: AppTokens.text05),
          ],
        ),
      ),
    );
  }

  // 타임존 선택
  Widget _buildTimezoneSelector() {
    final selectedTimezoneData = _selectedTimezone != null
        ? _availableTimezones.firstWhere(
            (tz) => tz['timezone'] == _selectedTimezone,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final selectedCountryName =
        (selectedTimezoneData['country_name_ko'] as String?) ??
        (selectedTimezoneData['country_name_en'] as String?) ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택 필드
        GestureDetector(
          onTap: () {
            if (!_isLoadingTimezones) {
              setState(() {
                _isTimezoneExpanded = !_isTimezoneExpanded;
              });
            }
          },
          child: Container(
            width: double.infinity,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppTokens.bgBasic01,
              border: Border.all(width: 1, color: AppTokens.line03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '국가',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize12,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: AppTokens.text04,
                          letterSpacing: AppTokens.letterSpacingNeg03,
                          height: 1.40,
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize12,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: AppTokens.text07,
                          letterSpacing: AppTokens.letterSpacingNeg03,
                          height: 1.40,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLoadingTimezones
                            ? '로딩 중...'
                            : (_selectedTimezone != null &&
                                      selectedCountryName.isNotEmpty
                                  ? selectedCountryName
                                  : '국가 선택'),
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize16,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: _selectedTimezone != null
                              ? AppTokens.text05
                              : AppTokens.text02,
                          letterSpacing: -0.5,
                          height: 1.36,
                        ),
                      ),
                    ),
                    Icon(
                      _isTimezoneExpanded
                          ? FontAwesomeIcons.chevronUp
                          : FontAwesomeIcons.chevronDown,
                      size: 20,
                      color: AppTokens.text05,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 확장 목록
        if (_isTimezoneExpanded && !_isLoadingTimezones)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppTokens.bgBasic01,
              border: Border.all(width: 1, color: AppTokens.line03),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _availableTimezones.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, thickness: 1, color: AppTokens.line03),
              itemBuilder: (context, index) {
                final tz = _availableTimezones[index];
                final timezone = tz['timezone'] as String;
                final countryName =
                    (tz['country_name_ko'] as String?) ??
                    (tz['country_name_en'] as String?) ??
                    '';
                final isSelected = _selectedTimezone == timezone;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTimezone = timezone;
                      _isTimezoneExpanded = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            countryName.isNotEmpty ? countryName : timezone,
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize16,
                              fontWeight: AppTokens.fontWeightRegular,
                              color: AppTokens.text05,
                              letterSpacing: -0.5,
                              height: 1.36,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 20,
                            height: 20,
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
              },
            ),
          ),
      ],
    );
  }

  // 일정 유형 그리드
  Widget _buildScheduleTypeGrid() {
    return SizedBox(
      width: double.infinity,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.9,
        ),
        itemCount: _scheduleTypes.length,
        itemBuilder: (context, index) {
          final type = _scheduleTypes[index];
          final isSelected = _selectedScheduleType == type['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedScheduleType = type['id'];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppTokens.bgTeal02 : AppTokens.bgBasic01,
                border: Border.all(
                  width: 1,
                  color: isSelected ? AppTokens.line06 : AppTokens.line03,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type['icon'] as IconData,
                    size: 24,
                    color: isSelected
                        ? AppTokens.primaryTeal
                        : AppTokens.text04,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type['label'] as String,
                    textAlign: TextAlign.center,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: isSelected ? AppTokens.text06 : AppTokens.text04,
                      letterSpacing: AppTokens.letterSpacingNeg1,
                      height: 1.40,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 장소 섹션
  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic02,
        border: Border.all(width: 1, color: AppTokens.line03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 체크박스 + 라벨
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _geofenceEnabled = !_geofenceEnabled;
                    if (!_geofenceEnabled) {
                      // 체크박스 해제 시 수정 불가 상태 초기화
                      _isGeofenceFromExisting = false;
                      _selectedGeofenceId = null;
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _geofenceEnabled
                        ? AppTokens.bgTeal01
                        : Colors.transparent,
                    border: Border.all(
                      width: 2,
                      color: _geofenceEnabled
                          ? AppTokens.primaryTeal
                          : AppTokens.line03,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _geofenceEnabled
                        ? [
                            const BoxShadow(
                              color: Color(0x2813BAC8),
                              blurRadius: 12,
                              offset: Offset(-1, 5),
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: _geofenceEnabled
                      ? const Icon(
                          FontAwesomeIcons.check,
                          size: 16,
                          color: AppTokens.primaryTeal,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '장소 (선택)',
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
          // 체크박스가 체크되어 있을 때만 지도 및 지오펜스 관련 UI 표시
          if (_geofenceEnabled) ...[
            const SizedBox(height: 8),
            // 장소명 입력 필드
            Container(
              width: double.infinity,
              height: 64,
              padding: const EdgeInsets.only(left: 18),
              decoration: BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border.all(width: 1, color: AppTokens.line03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '장소명',
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize12,
                            fontWeight: AppTokens.fontWeightRegular,
                            color: AppTokens.text04,
                            letterSpacing: AppTokens.letterSpacingNeg03,
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _placeNameController,
                    decoration: InputDecoration(
                      hintText: '예: 광화문',
                      hintStyle: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize16,
                        fontWeight: AppTokens.fontWeightRegular,
                        color: AppTokens.text03,
                        height: 1.36,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize16,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text05,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 주소 검색 입력 필드
            Container(
              width: double.infinity,
              height: 48,
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border.all(width: 1, color: AppTokens.line03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.magnifyingGlass, size: 20, color: AppTokens.text03),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: '주소 검색',
                        hintStyle: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightRegular,
                          color: AppTokens.text03,
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
                      onChanged: (value) {
                        // 검색은 항상 가능 (기존 지오펜스 선택해도 검색 가능)
                        _performSearch(value);
                      },
                      onSubmitted: (value) async {
                        if (value.isNotEmpty) {
                          await _searchLocation(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 검색 결과 드롭다운
            if (_isSearchResultsExpanded &&
                (_searchLocationResults.isNotEmpty ||
                    _searchGeofenceResults.isNotEmpty))
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: AppTokens.bgBasic01,
                  border: Border.all(width: 1, color: AppTokens.line03),
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // 추천 장소 섹션
                    if (_searchLocationResults.isNotEmpty) ...[
                      _buildSearchSectionHeader('추천 장소'),
                      ..._searchLocationResults.asMap().entries.map(
                        (entry) =>
                            _buildLocationResultItem(entry.value, entry.key),
                      ),
                    ],
                    // 구분선
                    if (_searchLocationResults.isNotEmpty &&
                        _searchGeofenceResults.isNotEmpty)
                      const Divider(height: 1, thickness: 1, color: AppTokens.line03),
                    // 추천 지오펜스 섹션
                    if (_searchGeofenceResults.isNotEmpty) ...[
                      _buildSearchSectionHeader('추천 지오펜스'),
                      ..._searchGeofenceResults.asMap().entries.map(
                        (entry) =>
                            _buildGeofenceResultItem(entry.value, entry.key),
                      ),
                    ],
                  ],
                ),
              ),
            // 지도
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                color: AppTokens.bgBasic01,
                border: Border.all(width: 1, color: AppTokens.line03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController ??= MapController(),
                  options: MapOptions(
                    initialCenter:
                        _locationLatitude != null && _locationLongitude != null
                        ? LatLng(_locationLatitude!, _locationLongitude!)
                        : const LatLng(37.5665, 126.9780), // 서울 기본 위치
                    initialZoom:
                        _locationLatitude != null && _locationLongitude != null
                        ? 15.0
                        : 10.0,
                    onTap: (tapPosition, point) {
                      // 지도 탭 시 위치 업데이트 (기존 지오펜스 선택 유지 - 지오펜스 수정)
                      setState(() {
                        _locationLatitude = point.latitude;
                        _locationLongitude = point.longitude;
                        // 검색 필드도 업데이트 (선택 사항)
                        if (_locationController.text.isEmpty) {
                          _locationController.text =
                              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
                        }
                      });
                      _updateMapCamera();
                      _updateGeofenceCircle();
                    },
                    onMapReady: () {
                      if (_locationLatitude != null &&
                          _locationLongitude != null) {
                        _updateMapCamera();
                      } else {
                        // 위치가 없으면 현재 위치 로드
                        _loadCurrentLocation();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.urock.safe.trip',
                      maxZoom: 19,
                    ),
                    if (_buildGeofenceCircles().isNotEmpty)
                      CircleLayer(
                        circles: _buildGeofenceCircles(),
                      ),
                  ],
                ),
              ),
            ),
            // 이탈 감지 범위 및 알림 설정
            const SizedBox(height: 8),
            _buildDetectionRadiusSection(),
          ],
        ],
      ),
    );
  }

  // 체크박스 위젯
  Widget _buildCheckbox({
    required String label,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? AppTokens.bgTeal01 : Colors.transparent,
              border: Border.all(
                width: 2,
                color: value ? AppTokens.primaryTeal : AppTokens.line03,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: value
                  ? [
                      const BoxShadow(
                        color: Color(0x2813BAC8),
                        blurRadius: 12,
                        offset: Offset(-1, 5),
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: value
                ? const Icon(FontAwesomeIcons.check, size: 16, color: AppTokens.primaryTeal)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
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
    );
  }

  // 메모 입력 필드
  Widget _buildMemoInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        border: Border.all(width: 1.5, color: AppTokens.line03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메모',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              fontWeight: AppTokens.fontWeightRegular,
              color: AppTokens.text04,
              letterSpacing: AppTokens.letterSpacingNeg03,
              height: 1.40,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '메모 입력',
              hintStyle: AppTokens.textStyle(
                fontSize: AppTokens.fontSize16,
                fontWeight: AppTokens.fontWeightRegular,
                color: AppTokens.text02,
                letterSpacing: AppTokens.letterSpacingNeg15,
                height: 1.36,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
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
    );
  }

  // 실시간 검색 수행
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchLocationResults = [];
        _searchGeofenceResults = [];
        _isSearchResultsExpanded = false;
      });
      return;
    }

    setState(() {
      _isSearchResultsExpanded = true;
    });

    // 1. 추천 장소 검색 (geocoding)
    await _searchLocation(query);

    // 2. 추천 지오펜스 검색 (기존 등록된 지오펜스)
    await _searchGeofences(query);
  }

  // 장소 검색 및 좌표 수집
  Future<void> _searchLocation(String query) async {
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        setState(() {
          _searchLocationResults = [
            {
              'name': query,
              'latitude': locations.first.latitude,
              'longitude': locations.first.longitude,
            },
          ];
        });
      } else {
        setState(() {
          _searchLocationResults = [];
        });
      }
    } catch (e) {
      debugPrint('[일정] 장소 검색 실패: $e');
      setState(() {
        _searchLocationResults = [];
      });
    }
  }

  // 기존 지오펜스 검색 (PostgreSQL에서 직접 조회)
  Future<void> _searchGeofences(String query) async {
    try {
      final groupId = await AppCache.groupId;
      if (groupId == null) {
        setState(() {
          _searchGeofenceResults = [];
        });
        return;
      }

      // PostgreSQL에서 지오펜스 목록 가져오기
      final geofencesList = await _apiService.getGeofences(groupId: groupId);

      // GeofenceData로 변환 및 필터링
      final filtered = geofencesList
          .where((g) {
            final name = g['name'] as String? ?? '';
            return name.toLowerCase().contains(query.toLowerCase());
          })
          .where((g) => g['is_active'] == true) // 활성화된 것만
          .where((g) => g['shape_type'] == 'circle') // 원형만
          .where((g) => 
            g['center_latitude'] != null && 
            g['center_longitude'] != null
          ) // 좌표 있는 것만
          .map((g) {
            // Map을 GeofenceData로 변환
            return GeofenceData(
              geofenceId: g['geofence_id'] as String,
              tripId: g['trip_id'] as String?,
              groupId: g['group_id'] as String?,
              name: g['name'] as String,
              description: g['description'] as String?,
              type: g['type'] as String? ?? 'safe',
              shapeType: g['shape_type'] as String? ?? 'circle',
              centerLatitude: g['center_latitude'] is num
                  ? (g['center_latitude'] as num).toDouble()
                  : g['center_latitude'] != null
                      ? double.tryParse(g['center_latitude'].toString())
                      : null,
              centerLongitude: g['center_longitude'] is num
                  ? (g['center_longitude'] as num).toDouble()
                  : g['center_longitude'] != null
                      ? double.tryParse(g['center_longitude'].toString())
                      : null,
              radiusMeters: g['radius_meters'] is int
                  ? g['radius_meters'] as int
                  : g['radius_meters'] is num
                      ? (g['radius_meters'] as num).toInt()
                      : g['radius_meters'] != null
                          ? int.tryParse(g['radius_meters'].toString())
                          : null,
              isAlwaysActive: g['is_always_active'] as bool? ?? true,
              triggerOnEnter: g['trigger_on_enter'] as bool? ?? true,
              triggerOnExit: g['trigger_on_exit'] as bool? ?? true,
              isActive: g['is_active'] as bool? ?? true,
            );
          })
          .toList();

      setState(() {
        _searchGeofenceResults = filtered;
      });
    } catch (e) {
      debugPrint('[일정] 지오펜스 검색 실패: $e');
      setState(() {
        _searchGeofenceResults = [];
      });
    }
  }

  // 검색 결과 섹션 헤더
  Widget _buildSearchSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic02,
        border: Border(bottom: BorderSide(width: 1, color: AppTokens.line03)),
      ),
      child: Text(
        title,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize12,
          fontWeight: AppTokens.fontWeightSemibold,
          color: AppTokens.text04,
          letterSpacing: AppTokens.letterSpacingNeg03,
          height: 1.40,
        ),
      ),
    );
  }

  // 추천 장소 결과 아이템
  Widget _buildLocationResultItem(Map<String, dynamic> result, int index) {
    return InkWell(
      onTap: () {
        _applyLocationResult(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: index < _searchLocationResults.length - 1 ? 1 : 0,
              color: AppTokens.line03,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(FontAwesomeIcons.mapPin, size: 20, color: AppTokens.text05),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result['name'] as String? ?? '',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize16,
                  fontWeight: AppTokens.fontWeightRegular,
                  color: AppTokens.text05,
                  letterSpacing: AppTokens.letterSpacingNeg1,
                  height: 1.36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 추천 지오펜스 결과 아이템
  Widget _buildGeofenceResultItem(GeofenceData geofence, int index) {
    return InkWell(
      onTap: () {
        _applyGeofenceResult(geofence);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: index < _searchGeofenceResults.length - 1 ? 1 : 0,
              color: AppTokens.line03,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(FontAwesomeIcons.locationDot, size: 20, color: AppTokens.primaryTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    geofence.name,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize16,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text05,
                      letterSpacing: AppTokens.letterSpacingNeg1,
                      height: 1.36,
                    ),
                  ),
                  if (geofence.radiusMeters != null)
                    Text(
                      '${geofence.radiusMeters}m',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        fontWeight: AppTokens.fontWeightRegular,
                        color: AppTokens.text04,
                        letterSpacing: AppTokens.letterSpacingNeg03,
                        height: 1.40,
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

  // 추천 장소 선택 시 폼 적용
  void _applyLocationResult(Map<String, dynamic> result) {
    setState(() {
      _locationController.text = result['name'] as String? ?? '';
      _locationLatitude = result['latitude'] as double?;
      _locationLongitude = result['longitude'] as double?;
      // 다른 장소를 선택하면 기존 지오펜스 선택 해제
      _isGeofenceFromExisting = false;
      _selectedGeofenceId = null;
      _isSearchResultsExpanded = false;
    });

    if (_locationLatitude != null && _locationLongitude != null) {
      _updateMapCamera();
      _updateGeofenceCircle();
    }
  }

  // 추천 지오펜스 선택 시 폼 적용
  void _applyGeofenceResult(GeofenceData geofence) {
    setState(() {
      // 장소명 필드에 지오펜스 이름 설정
      _placeNameController.text = geofence.name;
      // 주소 검색 필드는 비우거나 지오펜스 이름 유지 (선택)
      _locationController.text = geofence.name;
      _locationLatitude = geofence.centerLatitude;
      _locationLongitude = geofence.centerLongitude;
      if (geofence.radiusMeters != null) {
        _geofenceRadius = geofence.radiusMeters!;
      }
      _geofenceEnabled = true; // 자동 체크
      _isGeofenceFromExisting = true; // 기존 지오펜스 선택 (수정 가능)
      _selectedGeofenceId = geofence.geofenceId;
      // 기존 지오펜스의 알림 설정으로 변경
      _locationNotificationEnabled = true;
      _arrivalNotification = geofence.triggerOnEnter;
      _departureNotification = geofence.triggerOnExit;
      _isSearchResultsExpanded = false;
    });

    if (_locationLatitude != null && _locationLongitude != null) {
      _updateMapCamera();
      _updateGeofenceCircle();
    }
  }

  // 지도 카메라 업데이트
  void _updateMapCamera() {
    if (_mapController != null &&
        _locationLatitude != null &&
        _locationLongitude != null) {
      _mapController!.move(
        LatLng(_locationLatitude!, _locationLongitude!),
        15.0,
      );
    }
  }

  // 지오펜스 Circle 업데이트
  void _updateGeofenceCircle() {
    setState(() {
      // Circle은 buildGeofenceCircles()에서 자동으로 업데이트됨
    });
  }

  // 지오펜스 Circle 생성
  List<CircleMarker> _buildGeofenceCircles() {
    if (_locationLatitude == null ||
        _locationLongitude == null ||
        !_geofenceEnabled) {
      return [];
    }

    // 메인 맵과 동일한 디자인 적용
    return [
      CircleMarker(
        point: LatLng(_locationLatitude!, _locationLongitude!),
        radius: _geofenceRadius.toDouble(),
        color: AppTokens.primaryTeal.withValues(alpha: 0.15),
        borderColor: AppTokens.primaryTeal,
        borderStrokeWidth: 1,
        useRadiusInMeter: true,
      ),
    ];
  }

  // 반경 슬라이더
  // 이탈 감지 범위 및 알림 설정 섹션
  Widget _buildDetectionRadiusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic03,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          width: 1,
          color: AppTokens.line03,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 및 설명
          Text(
            '감지 범위',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightRegular,
              color: AppTokens.text05,
              height: 1.40,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '설정한 범위에 들어오거나 벗어나면 알림을 보내요.',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightRegular,
              color: AppTokens.text03,
              height: 1.40,
            ),
          ),
          const SizedBox(height: 24),
          // 슬라이더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 24,
                ),
              ),
              child: Slider(
                value: _geofenceRadius.toDouble(),
                min: 50,
                max: 1000,
                divisions: 95, // (1000-50)/10 = 95
                activeColor: AppTokens.primaryTeal,
                inactiveColor: AppTokens.bgBasic05,
                onChanged: (double value) {
                  setState(() {
                    _geofenceRadius = value.round();
                  });
                  _updateGeofenceCircle();
                },
              ),
            ),
          ),
          // 범위 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '50m',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text03,
                    height: 1.40,
                  ),
                ),
                Text(
                  '500m',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text03,
                    height: 1.40,
                  ),
                ),
                Text(
                  '1000m',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text03,
                    height: 1.40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 현재 값 표시 필드
          Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTokens.bgBasic01,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: 1,
                color: AppTokens.line03,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_geofenceRadius',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize18,
                    fontWeight: AppTokens.fontWeightRegular,
                    color: AppTokens.text06,
                    height: 1.40,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'm',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize14,
                    fontWeight: AppTokens.fontWeightLight,
                    color: AppTokens.text03,
                    height: 1.40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 알림 설정
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.bell,
                    size: 16,
                    color: AppTokens.text05,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '알림 설정',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text05,
                      height: 1.40,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _locationNotificationEnabled,
                onChanged: (value) {
                  setState(() {
                    _locationNotificationEnabled = value;
                  });
                },
                activeThumbColor: AppTokens.primaryTeal,
              ),
            ],
          ),
          // 알림 상세 설정
          if (_locationNotificationEnabled) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTokens.bgBasic01,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  width: 1,
                  color: AppTokens.line03,
                ),
              ),
              child: Column(
                children: [
                  _buildCheckbox(
                    label: '도착 알림 받기',
                    value: _arrivalNotification,
                    onChanged: (value) {
                      setState(() {
                        _arrivalNotification = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCheckbox(
                    label: '이탈 알림 받기',
                    value: _departureNotification,
                    onChanged: (value) {
                      setState(() {
                        _departureNotification = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 일정 등록 버튼
  Widget _buildRegisterButton() {
    return InkWell(
      onTap: _isLoading
          ? null
          : () {
              // 포커스 제거 및 키보드 숨김
              FocusScope.of(context).unfocus();
              _handleRegisterSchedule();
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: _isLoading ? AppTokens.text03 : AppTokens.primaryTeal,
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
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTokens.bgBasic01),
                  ),
                )
              : Text(
                  widget.schedule != null ? '일정 수정' : '일정 등록',
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
    );
  }

  // 일정 등록 처리
  Future<void> _handleRegisterSchedule() async {
    // 입력값 검증
    if (_titleController.text.trim().isEmpty) {
      _showError('일정 제목을 입력해주세요.');
      return;
    }

    if (_selectedTimezone == null) {
      _showError('국가를 선택해주세요.');
      return;
    }

    if (_selectedScheduleType == null) {
      _showError('일정 유형을 선택해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // group_id, user_id 가져오기
      final groupId = await AppCache.groupId;
      final userId = await AppCache.userId;

      if (groupId == null || userId == null) {
        _showError('그룹 정보를 찾을 수 없습니다.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // §5.4 오프라인 감지 — 네트워크 없으면 로컬 드래프트로 저장
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity == ConnectivityResult.none;

      // 타임존 사용 (선택된 타임존 또는 기본값)
      final timezone = _selectedTimezone ?? 'UTC';

      // UTC로 변환 (간단한 처리, 실제로는 timezone 패키지 사용 권장)
      final startTimeUTC = _selectedStartDateTime.toUtc();
      final endTimeUTC = _selectedEndDateTime.toUtc();

      // 장소 좌표 수집 (장소명이 있지만 좌표가 없는 경우)
      if (_locationController.text.isNotEmpty &&
          (_locationLatitude == null || _locationLongitude == null) &&
          !isOffline) {
        await _searchLocation(_locationController.text);
      }

      if (isOffline) {
        // §5.4 오프라인 모드: 일정을 로컬 SQLite 드래프트에 저장
        final action = widget.schedule != null ? 'update' : 'create';
        final payload = jsonEncode({
          if (widget.schedule != null)
            'schedule_id': widget.schedule!.scheduleId,
          'group_id': groupId,
          'user_id': userId,
          'title': _titleController.text.trim(),
          'description': _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          'schedule_type': _selectedScheduleType,
          'start_time': startTimeUTC.toIso8601String(),
          'end_time': endTimeUTC.toIso8601String(),
          'schedule_date': DateFormat('yyyy-MM-dd').format(_selectedStartDateTime),
          'location_name': _placeNameController.text.trim().isEmpty
              ? null
              : _placeNameController.text.trim(),
          'location_address': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'location_coords':
              (_locationLatitude != null && _locationLongitude != null)
                  ? {'latitude': _locationLatitude!, 'longitude': _locationLongitude!}
                  : null,
          'reminder_enabled': _notificationEnabled,
          'timezone': timezone,
        });

        await OfflineSyncService().pushScheduleDraft(
          scheduleId: widget.schedule?.scheduleId,
          tripId: groupId,
          action: action,
          payload: payload,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('오프라인 — 연결 복구 시 일정이 자동 동기화됩니다'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 그룹의 country_code 조회
      final countries = await _apiService.getCountryCodesByGroupId(groupId);
      if (countries.isEmpty) {
        _showError('여행 국가 정보를 찾을 수 없습니다.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (widget.schedule != null) {
        // 수정 모드
        final scheduleData = await _apiService.updateSchedule(
          scheduleId: widget.schedule!.scheduleId,
          groupId: groupId,
          userId: userId,
          title: _titleController.text.trim(),
          description: _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          scheduleType: _selectedScheduleType,
          startTime: startTimeUTC.toIso8601String(),
          endTime: endTimeUTC.toIso8601String(),
          scheduleDate: DateFormat('yyyy-MM-dd').format(_selectedStartDateTime),
          locationName: _placeNameController.text.trim().isEmpty
              ? null
              : _placeNameController.text.trim(),
          locationAddress: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          locationCoords:
              (_locationLatitude != null && _locationLongitude != null)
                  ? {'latitude': _locationLatitude!, 'longitude': _locationLongitude!}
                  : null,
          reminderEnabled: _notificationEnabled,
          reminderTime: _notificationEnabled ? 60 : null,
          // 일정 수정 시 지오펜스가 활성화되어 있으면 항상 정보 전달
          geofenceEnabled: _geofenceEnabled ? true : null,
          geofenceTriggerOnEnter: _geofenceEnabled ? _arrivalNotification : null,
          geofenceTriggerOnExit: _geofenceEnabled ? _departureNotification : null,
          geofenceRadiusMeters: _geofenceEnabled ? _geofenceRadius : null,
          timezone: timezone,
        );

        if (scheduleData == null) {
          _showError('일정 수정에 실패했습니다.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // 기존 지오펜스가 있으면 업데이트
        // 일정에 연결된 지오펜스가 있거나 선택된 지오펜스가 있으면 업데이트
        final geofenceIdToUpdate = _selectedGeofenceId ?? widget.schedule?.geofenceId;
        if (_geofenceEnabled && geofenceIdToUpdate != null) {
          try {
            await _apiService.updateGeofence(
              geofenceId: geofenceIdToUpdate,
              groupId: groupId,
              name: _placeNameController.text.trim().isEmpty
                  ? null
                  : _placeNameController.text.trim(),
              centerLatitude: _locationLatitude,
              centerLongitude: _locationLongitude,
              radiusMeters: _geofenceRadius,
              triggerOnEnter: _arrivalNotification,
              triggerOnExit: _departureNotification,
            );
          } catch (e) {
            debugPrint('[일정] 지오펜스 업데이트 실패: $e');
            // 지오펜스 업데이트 실패해도 일정은 저장됨
          }
        }

        // 성공
        if (mounted) {
          Navigator.of(context).pop(true); // true를 반환하여 목록 새로고침 신호
        }
      } else {
        // 생성 모드
        final scheduleData = await _apiService.createSchedule(
          groupId: groupId,
          userId: userId,
          title: _titleController.text.trim(),
          description: _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          scheduleType: _selectedScheduleType!,
          startTime: startTimeUTC.toIso8601String(),
          endTime: endTimeUTC.toIso8601String(),
          scheduleDate: DateFormat('yyyy-MM-dd').format(_selectedStartDateTime),
          locationName: _placeNameController.text.trim().isEmpty
              ? null
              : _placeNameController.text.trim(),
          locationAddress: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          locationCoords:
              (_locationLatitude != null && _locationLongitude != null)
                  ? {'latitude': _locationLatitude!, 'longitude': _locationLongitude!}
                  : null,
          reminderEnabled: _notificationEnabled,
          reminderTime: _notificationEnabled ? 60 : null,
          // 기존 지오펜스를 선택한 경우 새로 생성하지 않음
          geofenceEnabled:
              (_geofenceEnabled && _locationNotificationEnabled) &&
                      !_isGeofenceFromExisting
                  ? true
                  : false,
          geofenceTriggerOnEnter: _arrivalNotification,
          geofenceTriggerOnExit: _departureNotification,
          geofenceRadiusMeters:
              (_geofenceEnabled && _locationNotificationEnabled) &&
                      !_isGeofenceFromExisting
                  ? _geofenceRadius
                  : null,
          timezone: timezone,
        );

        if (scheduleData == null) {
          _showError('일정 생성에 실패했습니다.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final scheduleId = scheduleData['schedule_id'] as String?;
        if (scheduleId == null) {
          _showError('일정 생성에 실패했습니다.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // 기존 지오펜스가 있으면 업데이트
        if (_geofenceEnabled &&
            _locationNotificationEnabled &&
            _selectedGeofenceId != null &&
            _locationLatitude != null &&
            _locationLongitude != null) {
          try {
            await _apiService.updateGeofence(
              geofenceId: _selectedGeofenceId!,
              groupId: groupId,
              name: _placeNameController.text.trim().isEmpty
                  ? null
                  : _placeNameController.text.trim(),
              centerLatitude: _locationLatitude,
              centerLongitude: _locationLongitude,
              radiusMeters: _geofenceRadius,
              triggerOnEnter: _arrivalNotification,
              triggerOnExit: _departureNotification,
            );
            // 지오펜스 업데이트 후 일정에 연결
            await _apiService.updateScheduleGeofenceId(
              scheduleId: scheduleId,
              geofenceId: _selectedGeofenceId,
            );
          } catch (e) {
            debugPrint('[일정] 지오펜스 업데이트 실패: $e');
            // 지오펜스 업데이트 실패해도 일정은 저장됨
          }
        }

        // 성공
        if (mounted) {
          Navigator.of(context).pop(true); // true를 반환하여 목록 새로고침 신호
        }
      }
    } catch (e) {
      debugPrint('[일정] 일정 등록 실패: $e');
      _showError('일정 등록 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 에러 메시지 표시
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTokens.semanticError),
    );
  }
}

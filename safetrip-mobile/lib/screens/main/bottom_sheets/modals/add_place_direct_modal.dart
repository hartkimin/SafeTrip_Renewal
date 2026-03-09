import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/location_service.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/app_cache.dart';
import '../../../../models/geofence.dart';

class AddPlaceDirectModal extends StatefulWidget { // 수정 모드일 때 기존 지오펜스 데이터

  const AddPlaceDirectModal({super.key, this.geofence});
  final GeofenceData? geofence;

  @override
  State<AddPlaceDirectModal> createState() => _AddPlaceDirectModalState();
}

class _AddPlaceDirectModalState extends State<AddPlaceDirectModal> {
  final TextEditingController _placeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _selectedRiskLevel = 'safe'; // 선택된 위험도 (safe, caution, danger)
  int _detectionRadius = 200; // 감지 범위 (50-1000m)
  bool _notificationEnabled = true; // 알림 설정 활성화
  bool _arrivalNotification = true; // 도착 알림
  bool _departureNotification = true; // 이탈 알림

  // 검색 관련 상태
  List<Map<String, dynamic>> _searchLocationResults = []; // 추천 장소 검색 결과
  bool _isSearchResultsExpanded = false; // 검색 결과 드롭다운 확장 여부
  bool _isSearching = false; // 검색 중 여부

  // 지도 관련 상태
  MapController? _mapController;
  double? _locationLatitude;
  double? _locationLongitude;

  // 로딩 상태
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.geofence != null) {
      // 수정 모드: 기존 지오펜스 데이터 로드
      _loadGeofenceData(widget.geofence!);
    } else {
      // 생성 모드: 현재 위치 로드
      _loadCurrentLocation();
    }
  }

  // 기존 지오펜스 데이터 로드
  void _loadGeofenceData(GeofenceData geofence) {
    _placeNameController.text = geofence.name;
    if (geofence.description != null) {
      _addressController.text = geofence.description!;
    }
    _selectedRiskLevel = geofence.type;
    if (geofence.radiusMeters != null) {
      _detectionRadius = geofence.radiusMeters!;
    }
    _arrivalNotification = geofence.triggerOnEnter;
    _departureNotification = geofence.triggerOnExit;
    _notificationEnabled = geofence.triggerOnEnter || geofence.triggerOnExit;
    
    if (geofence.centerLatitude != null && geofence.centerLongitude != null) {
      setState(() {
        _locationLatitude = geofence.centerLatitude;
        _locationLongitude = geofence.centerLongitude;
      });
      // 지도 카메라 업데이트는 지도가 생성된 후에 수행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null) {
          _updateMapCamera();
        }
      });
    } else {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _placeNameController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
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
        if (_mapController != null) {
          _updateMapCamera();
        }
      }
    } catch (e) {
      debugPrint('[장소] 현재 위치 로드 실패: $e');
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

  // 지오펜스 원 그리기
  List<CircleMarker> _buildGeofenceCircles() {
    if (_locationLatitude == null || _locationLongitude == null) {
      return [];
    }

    // 메인 맵과 동일한 위험도별 색상 적용
    Color fillColor;
    Color strokeColor;

    switch (_selectedRiskLevel) {
      case 'safe':
        fillColor = AppTokens.semanticSuccess.withValues(alpha: 0.15);
        strokeColor = AppTokens.semanticSuccess;
        break;
      case 'caution':
        fillColor = AppTokens.semanticWarning.withValues(alpha: 0.15);
        strokeColor = AppTokens.semanticWarning;
        break;
      case 'danger':
        fillColor = AppTokens.semanticError.withValues(alpha: 0.15);
        strokeColor = AppTokens.semanticError;
        break;
      default:
        fillColor = Colors.blue.withValues(alpha: 0.15);
        strokeColor = Colors.blue;
    }

    return [
      CircleMarker(
        point: LatLng(_locationLatitude!, _locationLongitude!),
        radius: _detectionRadius.toDouble(),
        color: fillColor,
        borderColor: strokeColor,
        borderStrokeWidth: 1,
        useRadiusInMeter: true,
      ),
    ];
  }

  // 검색 수행
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchLocationResults = [];
        _isSearchResultsExpanded = false;
      });
      return;
    }

    setState(() {
      _isSearchResultsExpanded = true;
    });

    await _searchLocation(query);
  }

  // 주소 검색 (Nominatim API - 다중 결과)
  Future<void> _searchLocation(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchLocationResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
          'accept-language': 'ko,en',
          'addressdetails': '1',
        },
        options: Options(headers: {'User-Agent': 'SafeTrip/1.0'}),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is String
            ? json.decode(response.data as String)
            : response.data as List<dynamic>;
        if (mounted) {
          setState(() {
            _searchLocationResults = data.map((item) => {
              'display_name': item['display_name'] as String,
              'latitude': double.tryParse(item['lat'] as String) ?? 0.0,
              'longitude': double.tryParse(item['lon'] as String) ?? 0.0,
              'short_name': _buildShortName(item),
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('[장소] Nominatim 검색 실패: $e');
      if (mounted) {
        setState(() => _searchLocationResults = []);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // 짧은 이름 생성 (address.road + address.suburb/city/state 조합)
  String _buildShortName(dynamic item) {
    final addr = item['address'];
    if (addr == null) return item['display_name'] as String;
    final parts = <String>[];
    if (addr['road'] != null) parts.add(addr['road'] as String);
    if (addr['suburb'] != null) {
      parts.add(addr['suburb'] as String);
    } else if (addr['city'] != null) {
      parts.add(addr['city'] as String);
    } else if (addr['state'] != null) {
      parts.add(addr['state'] as String);
    }
    return parts.isNotEmpty ? parts.join(', ') : item['display_name'] as String;
  }

  // 역지오코딩 (좌표 → 주소)
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'accept-language': 'ko,en',
        },
        options: Options(headers: {'User-Agent': 'SafeTrip/1.0'}),
      );
      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data as String)
            : response.data;
        final address = data['display_name'] as String?;
        if (address != null && mounted) {
          setState(() {
            _addressController.text = address;
            _searchLocationResults = [];
            _isSearchResultsExpanded = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[장소] 역지오코딩 실패: $e');
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
    final shortName = result['short_name'] as String? ?? result['display_name'] as String? ?? '';
    final displayName = result['display_name'] as String? ?? '';
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortName,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize16,
                      fontWeight: AppTokens.fontWeightSemibold,
                      color: AppTokens.text05,
                      letterSpacing: AppTokens.letterSpacingNeg1,
                      height: 1.36,
                    ),
                  ),
                  if (displayName.isNotEmpty && displayName != shortName) ...[
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        fontWeight: AppTokens.fontWeightRegular,
                        color: AppTokens.text03,
                        letterSpacing: AppTokens.letterSpacingNeg03,
                        height: 1.40,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
      _addressController.text = result['display_name'] as String? ?? result['short_name'] as String? ?? '';
      _locationLatitude = result['latitude'] as double?;
      _locationLongitude = result['longitude'] as double?;
      _searchLocationResults = [];
      _isSearchResultsExpanded = false;
    });
    _updateMapCamera();
  }

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
                      widget.geofence != null ? '장소 수정' : '장소 직접 추가',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 장소명 입력 필드
                    _buildPlaceNameField(),
                    const SizedBox(height: 16),
                    // 주소 검색 필드
                    _buildAddressField(),
                    const SizedBox(height: 8),
                    // 지도
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
                            initialCenter: _locationLatitude != null &&
                                    _locationLongitude != null
                                ? LatLng(_locationLatitude!, _locationLongitude!)
                                : const LatLng(37.5665, 126.9780), // 서울 기본 위치
                            initialZoom: _locationLatitude != null &&
                                    _locationLongitude != null
                                ? 15.0
                                : 10.0,
                            onTap: (tapPosition, point) async {
                              setState(() {
                                _locationLatitude = point.latitude;
                                _locationLongitude = point.longitude;
                              });
                              _updateMapCamera();
                              await _reverseGeocode(point.latitude, point.longitude);
                            },
                            onMapReady: () {
                              if (widget.geofence != null &&
                                  _locationLatitude != null &&
                                  _locationLongitude != null) {
                                // 수정 모드: 기존 위치로 카메라 이동
                                _updateMapCamera();
                              } else if (_locationLatitude != null &&
                                  _locationLongitude != null) {
                                _updateMapCamera();
                              } else {
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
                              keepBuffer: 3,
                            ),
                            if (_buildGeofenceCircles().isNotEmpty)
                              CircleLayer(
                                circles: _buildGeofenceCircles(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 위험도 설정
                    _buildRiskLevelSection(),
                    const SizedBox(height: 24),
                    // 감지 범위 및 알림 설정
                    _buildDetectionRadiusSection(),
                    const SizedBox(height: 32),
                    // 장소 등록 버튼
                    _buildRegisterButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 장소명 입력 필드
  Widget _buildPlaceNameField() {
    return Container(
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
    );
  }

  // 주소 검색 필드
  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  controller: _addressController,
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
        // 검색 중 로딩 인디케이터
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTokens.bgBasic01,
              border: Border.all(width: 1, color: AppTokens.line03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primaryTeal),
                ),
              ),
            ),
          ),
        // 검색 결과 드롭다운
        if (!_isSearching && _isSearchResultsExpanded && _searchLocationResults.isNotEmpty)
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
                _buildSearchSectionHeader('추천 장소'),
                ..._searchLocationResults.asMap().entries.map(
                  (entry) => _buildLocationResultItem(entry.value, entry.key),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 위험도 설정 섹션
  Widget _buildRiskLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '위험도 설정',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightRegular,
            color: AppTokens.text05,
            height: 1.40,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '이 장소를 얼마나 위험하게 감지할지 선택하세요',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightRegular,
            color: AppTokens.text03,
            height: 1.40,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRiskLevelCard(
                'safe',
                '안전지역',
                '진입/이탈시\n본인 알림',
                FontAwesomeIcons.circleCheck,
                _selectedRiskLevel == 'safe',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRiskLevelCard(
                'caution',
                '주의 지역',
                '진입/이탈 시\n보호자/관리자 알림',
                FontAwesomeIcons.triangleExclamation,
                _selectedRiskLevel == 'caution',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskLevelCard(
    String id,
    String title,
    String description,
    IconData icon,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRiskLevel = id;
        });
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTokens.bgTeal03
              : AppTokens.bgBasic01,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 1,
            color: isSelected
                ? AppTokens.primaryTeal
                : AppTokens.line03,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? AppTokens.text06
                  : AppTokens.text05,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize14,
                fontWeight: AppTokens.fontWeightRegular,
                color: isSelected
                    ? AppTokens.text06
                    : AppTokens.text05,
                height: 1.40,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                description,
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize12,
                  fontWeight: AppTokens.fontWeightRegular,
                  color: AppTokens.text03,
                  height: 1.40,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 감지 범위 섹션
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
          Text(
            '감지 범위',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightRegular,
              color: AppTokens.text05,
              height: 1.40,
            ),
          ),
          const SizedBox(height: 4),
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
                value: _detectionRadius.toDouble(),
                min: 50,
                max: 1000,
                divisions: 95, // (1000-50)/10 = 95
                activeColor: AppTokens.primaryTeal,
                inactiveColor: AppTokens.bgBasic05,
                onChanged: (double value) {
                  setState(() {
                    _detectionRadius = value.round();
                  });
                  // 지도에 반영
                  if (_mapController != null) {
                    setState(() {}); // 지오펜스 원 업데이트를 위해
                  }
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
                  '$_detectionRadius',
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
                value: _notificationEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationEnabled = value;
                  });
                },
                activeThumbColor: AppTokens.primaryTeal,
              ),
            ],
          ),
          // 알림 상세 설정
          if (_notificationEnabled) ...[
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
                  _buildNotificationCheckbox(
                    '도착 알림 받기',
                    _arrivalNotification,
                    (value) {
                      setState(() {
                        _arrivalNotification = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationCheckbox(
                    '이탈 알림 받기',
                    _departureNotification,
                    (value) {
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

  Widget _buildNotificationCheckbox(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
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

  // 장소 등록 버튼
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegisterPlace,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primaryTeal,
          disabledBackgroundColor: AppTokens.bgBasic05,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.bgBasic01),
                ),
              )
            : Text(
                widget.geofence != null ? '수정 완료' : '장소 등록',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize16,
                  fontWeight: AppTokens.fontWeightSemibold,
                  color: AppTokens.bgBasic01,
                  height: 1.36,
                ),
              ),
      ),
    );
  }

  // 장소 등록/수정 처리
  Future<void> _handleRegisterPlace() async {
    // 유효성 검사
    if (_placeNameController.text.trim().isEmpty) {
      _showError('장소명을 입력해주세요.');
      return;
    }

    if (_locationLatitude == null || _locationLongitude == null) {
      _showError('지도에서 위치를 선택해주세요.');
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

      if (widget.geofence != null) {
        // 수정 모드
        final geofenceData = await _apiService.updateGeofence(
          geofenceId: widget.geofence!.geofenceId,
          groupId: groupId,
          name: _placeNameController.text.trim(),
          description: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          type: _selectedRiskLevel,
          shapeType: 'circle',
          centerLatitude: _locationLatitude!,
          centerLongitude: _locationLongitude!,
          radiusMeters: _detectionRadius,
          triggerOnEnter: _arrivalNotification,
          triggerOnExit: _departureNotification,
        );

        if (geofenceData == null) {
          _showError('장소 수정에 실패했습니다.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('장소가 수정되었습니다'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true); // 수정 완료 표시
        }
      } else {
        // 생성 모드
        // 위험도에 따른 알림 설정
        bool notifyGroup = false;
        bool notifyGuardians = false;
        if (_selectedRiskLevel == 'caution') {
          notifyGuardians = true;
        }

        // 지오펜스 생성
        final geofenceData = await _apiService.createGeofence(
          groupId: groupId,
          userId: userId,
          name: _placeNameController.text.trim(),
          description: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          type: _selectedRiskLevel, // 'safe' or 'caution'
          shapeType: 'circle',
          centerLatitude: _locationLatitude!,
          centerLongitude: _locationLongitude!,
          radiusMeters: _detectionRadius,
          isAlwaysActive: true,
          triggerOnEnter: _arrivalNotification,
          triggerOnExit: _departureNotification,
          notifyGroup: notifyGroup,
          notifyGuardians: notifyGuardians,
        );

        if (geofenceData == null) {
          _showError('장소 등록에 실패했습니다.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('장소가 등록되었습니다'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[장소] ${widget.geofence != null ? '수정' : '등록'} 실패: $e');
      _showError('장소 ${widget.geofence != null ? '수정' : '등록'} 중 오류가 발생했습니다.');
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTokens.semanticError,
        ),
      );
    }
  }
}


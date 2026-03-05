import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// 역 지오코딩 서비스
class GeocodingService {
  /// 좌표로부터 주소 조회 (간단한 버전)
  /// 형식: "city locality" (예: "서울특별시 강남구 역삼동")
  /// 국가명은 제외됩니다.
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final parts = <String>[];

      // City 부분: 시/도 + 시/군/구
      final cityParts = <String>[];
      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.isNotEmpty) {
        cityParts.add(placemark.administrativeArea!);
      }

      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        // administrativeArea와 locality 중복 확인
        if (cityParts.isEmpty ||
            !cityParts.first.contains(placemark.locality!)) {
          cityParts.add(placemark.locality!);
        }
      }

      if (cityParts.isNotEmpty) {
        parts.add(cityParts.join(' '));
      }

      // Locality 부분: 동/지역
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        parts.add(placemark.subLocality!);
      }

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(' ');
    } catch (e) {
      debugPrint('[GeocodingService] 주소 조회 실패: $e');
      return null;
    }
  }

  /// 좌표로부터 상세 주소 조회 (지오펜스용)
  /// 형식: "시/도 시/군/구 동 도로명 건물번호" (예: "서울특별시 강남구 역삼동 테헤란로 123")
  /// 국가명은 제외됩니다.
  Future<String?> getDetailedAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final parts = <String>[];

      // 시/도 (administrativeArea)
      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.isNotEmpty) {
        parts.add(placemark.administrativeArea!);
      }

      // 시/군/구 (locality)
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        // administrativeArea와 locality 중복 확인
        if (parts.isEmpty || !parts.first.contains(placemark.locality!)) {
          parts.add(placemark.locality!);
        }
      }

      // 동/지역 (subLocality)
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        parts.add(placemark.subLocality!);
      }

      // 도로명 (thoroughfare)
      if (placemark.thoroughfare != null &&
          placemark.thoroughfare!.isNotEmpty) {
        parts.add(placemark.thoroughfare!);
      }

      // 건물번호 (subThoroughfare)
      if (placemark.subThoroughfare != null &&
          placemark.subThoroughfare!.isNotEmpty) {
        parts.add(placemark.subThoroughfare!);
      }

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(' ');
    } catch (e) {
      debugPrint('[GeocodingService] 상세 주소 조회 실패: $e');
      return null;
    }
  }

  /// 나라 정보 조회
  Future<String?> getCountryFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      return placemark.country;
    } catch (e) {
      debugPrint('[GeocodingService] 나라 정보 조회 실패: $e');
      return null;
    }
  }

  /// 나라 코드 조회 (ISO 3166-1 alpha-2)
  Future<String?> getCountryCodeFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      return placemark.isoCountryCode;
    } catch (e) {
      debugPrint('[GeocodingService] 나라 코드 조회 실패: $e');
      return null;
    }
  }

  /// subLocality(동/지역)만 조회
  /// 예: "역삼동", "강남동"
  Future<String?> getSubLocalityFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        return placemark.subLocality;
      }
      return null;
    } catch (e) {
      debugPrint('[GeocodingService] 동/지역 조회 실패: $e');
      return null;
    }
  }

  /// 도로명(street)만 조회 (도로명 + 건물번호)
  /// 예: "테헤란로 123"
  Future<String?> getStreetFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final streetParts = <String>[];

      // 도로명 (thoroughfare)
      if (placemark.thoroughfare != null &&
          placemark.thoroughfare!.isNotEmpty) {
        streetParts.add(placemark.thoroughfare!);
      }

      // 건물번호 (subThoroughfare)
      if (placemark.subThoroughfare != null &&
          placemark.subThoroughfare!.isNotEmpty) {
        streetParts.add(placemark.subThoroughfare!);
      }

      if (streetParts.isEmpty) {
        return null;
      }

      return streetParts.join(' ');
    } catch (e) {
      debugPrint('[GeocodingService] 도로명 조회 실패: $e');
      return null;
    }
  }

  /// 도로명(thoroughfare)만 조회
  /// 예: "테헤란로", "105동" 등
  Future<String?> getThoroughfareFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;

      // thoroughfare 필드가 있고 비어있지 않으면 반환
      if (placemark.thoroughfare != null &&
          placemark.thoroughfare!.isNotEmpty) {
        return placemark.thoroughfare;
      }

      return null;
    } catch (e) {
      debugPrint('[GeocodingService] 도로명 조회 실패: $e');
      return null;
    }
  }

  /// 도로명 주소 조회 (형식: "[country] city locality")
  /// 예: "[한국] 서울특별시 강남구 역삼동"
  Future<String?> getRoadAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      return _buildRoadAddress(placemark);
    } catch (e) {
      debugPrint('[GeocodingService] 도로명 주소 조회 실패: $e');
      return null;
    }
  }

  /// 도로명 주소 구성 (형식: "[country] city locality")
  /// country: 나라 (대괄호로 감싸기)
  /// city: 시/도 + 시/군/구
  /// locality: 동/지역
  String? _buildRoadAddress(Placemark placemark) {
    final parts = <String>[];

    String? administrativeArea = placemark.administrativeArea;
    String? locality = placemark.locality;
    String? subLocality = placemark.subLocality;

    // Country 부분: [나라]
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      parts.add('[${placemark.country}]');
    }

    // City 부분: 시/도 + 시/군/구
    final cityParts = <String>[];
    if (administrativeArea != null && administrativeArea.isNotEmpty) {
      // administrativeArea가 이미 시/도 단위인지 확인
      // (서울특별시, 부산광역시, 경기도, 충청남도 등)
      final isProvinceLevel =
          administrativeArea.contains('특별시') ||
          administrativeArea.contains('광역시') ||
          administrativeArea.contains('도');

      if (isProvinceLevel) {
        // 시/도 단위이면 그대로 추가
        cityParts.add(administrativeArea);

        // locality가 있으면 추가 (예: 경기도 + 수원시)
        if (locality != null && locality.isNotEmpty) {
          // locality가 administrativeArea에 포함되어 있지 않은 경우만 추가
          if (!administrativeArea.contains(locality)) {
            cityParts.add(locality);
          }
        }
      } else {
        // administrativeArea가 시/군/구 단위인 경우 (예: 수원시)
        // locality와 중복 확인
        if (locality != null &&
            locality.isNotEmpty &&
            locality != administrativeArea) {
          // 둘 다 있으면 둘 다 추가 (더 상위 단위가 있을 수 있음)
          cityParts.add(administrativeArea);
          cityParts.add(locality);
        } else {
          // administrativeArea만 추가
          cityParts.add(administrativeArea);
        }
      }
    } else if (locality != null && locality.isNotEmpty) {
      // administrativeArea가 없으면 locality만 추가
      cityParts.add(locality);
    }

    if (cityParts.isNotEmpty) {
      parts.add(cityParts.join(' '));
    }

    // Locality 부분: 동/지역
    if (subLocality != null && subLocality.isNotEmpty) {
      parts.add(subLocality);
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }
}

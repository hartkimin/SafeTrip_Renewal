// SafetyGuide 데이터 모델 (DOC-T3-SFG-021 §3.2)

class SafetyGuideData {
  final GuideOverview? overview;
  final GuideSafety? safety;
  final GuideMedical? medical;
  final GuideEntry? entry;
  final GuideEmergency? emergency;
  final GuideLocalLife? localLife;
  final GuideMeta meta;

  SafetyGuideData({
    this.overview,
    this.safety,
    this.medical,
    this.entry,
    this.emergency,
    this.localLife,
    required this.meta,
  });

  factory SafetyGuideData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final metaJson = json['meta'] as Map<String, dynamic>? ?? {};
    return SafetyGuideData(
      overview: data['overview'] != null
          ? GuideOverview.fromJson(data['overview'])
          : null,
      safety: data['safety'] != null
          ? GuideSafety.fromJson(data['safety'])
          : null,
      medical: data['medical'] != null
          ? GuideMedical.fromJson(data['medical'])
          : null,
      entry:
          data['entry'] != null ? GuideEntry.fromJson(data['entry']) : null,
      emergency: data['emergency'] != null
          ? GuideEmergency.fromJson(data['emergency'])
          : null,
      localLife: data['local_life'] != null
          ? GuideLocalLife.fromJson(data['local_life'])
          : null,
      meta: GuideMeta.fromJson(metaJson),
    );
  }
}

class GuideMeta {
  final String countryCode;
  final bool cached;
  final bool stale;
  final DateTime? fetchedAt;
  final DateTime? expiresAt;

  GuideMeta({
    required this.countryCode,
    this.cached = false,
    this.stale = false,
    this.fetchedAt,
    this.expiresAt,
  });

  factory GuideMeta.fromJson(Map<String, dynamic> json) {
    return GuideMeta(
      countryCode: json['country_code'] as String? ?? '',
      cached: json['cached'] as bool? ?? false,
      stale: json['stale'] as bool? ?? false,
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
    );
  }
}

class GuideOverview {
  final String countryCode;
  final String? countryNameKo;
  final String? countryNameEn;
  final String? flagEmoji;
  final int? travelAlertLevel; // 1-4
  final String? capital;
  final String? currency;
  final String? language;
  final String? timezone;

  GuideOverview({
    required this.countryCode,
    this.countryNameKo,
    this.countryNameEn,
    this.flagEmoji,
    this.travelAlertLevel,
    this.capital,
    this.currency,
    this.language,
    this.timezone,
  });

  factory GuideOverview.fromJson(Map<String, dynamic> json) {
    return GuideOverview(
      countryCode: json['country_code'] as String? ?? '',
      countryNameKo: json['country_name_ko'] as String?,
      countryNameEn: json['country_name_en'] as String?,
      flagEmoji: json['flag_emoji'] as String?,
      travelAlertLevel: json['travel_alert_level'] as int?,
      capital: json['capital'] as String?,
      currency: json['currency'] as String?,
      language: json['language'] as String?,
      timezone: json['timezone'] as String?,
    );
  }
}

class GuideSafety {
  final int? travelAlertLevel;
  final String? travelAlertDescription;
  final String? securityStatus;
  final List<SafetyNotice> recentNotices;
  final List<RegionalAlert> regionalAlerts;

  GuideSafety({
    this.travelAlertLevel,
    this.travelAlertDescription,
    this.securityStatus,
    this.recentNotices = const [],
    this.regionalAlerts = const [],
  });

  factory GuideSafety.fromJson(Map<String, dynamic> json) {
    return GuideSafety(
      travelAlertLevel: json['travel_alert_level'] as int?,
      travelAlertDescription: json['travel_alert_description'] as String?,
      securityStatus: json['security_status'] as String?,
      recentNotices: (json['recent_notices'] as List<dynamic>?)
              ?.map(
                  (e) => SafetyNotice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      regionalAlerts: (json['regional_alerts'] as List<dynamic>?)
              ?.map(
                  (e) => RegionalAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SafetyNotice {
  final String? title;
  final String? content;
  final String? publishedAt;

  SafetyNotice({this.title, this.content, this.publishedAt});

  factory SafetyNotice.fromJson(Map<String, dynamic> json) {
    return SafetyNotice(
      title: json['title'] as String?,
      content: json['content'] as String?,
      publishedAt: json['published_at'] as String?,
    );
  }
}

class RegionalAlert {
  final String? region;
  final int? alertLevel;
  final String? description;

  RegionalAlert({this.region, this.alertLevel, this.description});

  factory RegionalAlert.fromJson(Map<String, dynamic> json) {
    return RegionalAlert(
      region: json['region'] as String?,
      alertLevel: json['alert_level'] as int?,
      description: json['description'] as String?,
    );
  }
}

class GuideMedical {
  final List<Map<String, dynamic>> hospitals;
  final String? insuranceGuide;
  final String? pharmacyInfo;
  final String? emergencyGuide;

  GuideMedical({
    this.hospitals = const [],
    this.insuranceGuide,
    this.pharmacyInfo,
    this.emergencyGuide,
  });

  factory GuideMedical.fromJson(Map<String, dynamic> json) {
    return GuideMedical(
      hospitals: (json['hospitals'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      insuranceGuide: json['insurance_guide'] as String?,
      pharmacyInfo: json['pharmacy_info'] as String?,
      emergencyGuide: json['emergency_guide'] as String?,
    );
  }
}

class GuideEntry {
  final String? visaRequirement;
  final List<String> requiredDocuments;
  final String? customsInfo;
  final String? passportValidity;

  GuideEntry({
    this.visaRequirement,
    this.requiredDocuments = const [],
    this.customsInfo,
    this.passportValidity,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> json) {
    return GuideEntry(
      visaRequirement: json['visa_requirement'] as String?,
      requiredDocuments: (json['required_documents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      customsInfo: json['customs_info'] as String?,
      passportValidity: json['passport_validity'] as String?,
    );
  }
}

class GuideEmergency {
  final List<EmergencyContactItem> contacts;

  GuideEmergency({this.contacts = const []});

  factory GuideEmergency.fromJson(Map<String, dynamic> json) {
    return GuideEmergency(
      contacts: (json['contacts'] as List<dynamic>?)
              ?.map((e) =>
                  EmergencyContactItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 하드코딩 폴백: 영사콜센터만 제공 (§6.1)
  factory GuideEmergency.fallback() {
    return GuideEmergency(
      contacts: [
        EmergencyContactItem(
          contactType: 'consulate_call_center',
          phoneNumber: '+82-2-3210-0404',
          descriptionKo: '영사콜센터 (24시간)',
          is24h: true,
        ),
      ],
    );
  }
}

class EmergencyContactItem {
  final String contactType;
  final String phoneNumber;
  final String? descriptionKo;
  final bool is24h;

  EmergencyContactItem({
    required this.contactType,
    required this.phoneNumber,
    this.descriptionKo,
    this.is24h = true,
  });

  factory EmergencyContactItem.fromJson(Map<String, dynamic> json) {
    return EmergencyContactItem(
      contactType: json['contact_type'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      descriptionKo: json['description_ko'] as String?,
      is24h: json['is_24h'] as bool? ?? true,
    );
  }

  /// 연락처 유형의 한국어 라벨
  String get typeLabel {
    switch (contactType) {
      case 'police':
        return '경찰';
      case 'fire':
        return '소방/구급';
      case 'ambulance':
        return '구급차';
      case 'embassy':
        return '대한민국 대사관';
      case 'consulate_call_center':
        return '영사콜센터';
      default:
        return contactType;
    }
  }
}

class GuideLocalLife {
  final String? transport;
  final String? simCard;
  final String? tippingCulture;
  final String? voltage;
  final String? costReference;
  final String? culturalNotes;

  GuideLocalLife({
    this.transport,
    this.simCard,
    this.tippingCulture,
    this.voltage,
    this.costReference,
    this.culturalNotes,
  });

  factory GuideLocalLife.fromJson(Map<String, dynamic> json) {
    return GuideLocalLife(
      transport: json['transport'] as String?,
      simCard: json['sim_card'] as String?,
      tippingCulture: json['tipping_culture'] as String?,
      voltage: json['voltage'] as String?,
      costReference: json['cost_reference'] as String?,
      culturalNotes: json['cultural_notes'] as String?,
    );
  }
}

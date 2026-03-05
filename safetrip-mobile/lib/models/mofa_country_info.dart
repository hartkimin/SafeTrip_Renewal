/// 외교부 API 재외공관 정보 모델
class EmbassyInfo {
  final String? embassyNm;
  final String? embassyAddr;
  final String? telNo;
  final String? emergencyTelNo;
  final String? email;
  final String? website;
  final String? countryCode;
  final String? countryNameKo;
  final String? countryNameEn;

  EmbassyInfo({
    this.embassyNm,
    this.embassyAddr,
    this.telNo,
    this.emergencyTelNo,
    this.email,
    this.website,
    this.countryCode,
    this.countryNameKo,
    this.countryNameEn,
  });

  factory EmbassyInfo.fromJson(Map<String, dynamic> json) {
    return EmbassyInfo(
      embassyNm:
          json['embassy_name'] as String? ??
          json['embassyNm'] as String? ??
          json['contact_name'] as String?,
      embassyAddr: json['address'] as String? ?? json['embassyAddr'] as String?,
      telNo: json['phone'] as String? ?? json['telNo'] as String?,
      emergencyTelNo:
          json['emergency_tel_no'] as String? ??
          json['emergencyTelNo'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      countryCode:
          json['country_iso_alp2'] as String? ?? json['countryCode'] as String?,
      countryNameKo:
          json['country_nm'] as String? ?? json['countryNameKo'] as String?,
      countryNameEn:
          json['country_eng_nm'] as String? ?? json['countryNameEn'] as String?,
    );
  }
}

/// 외교부 API 현지 연락처 모델
class LocalContactInfo {
  final String? contactType;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? countryCode;
  final String? countryNameKo;

  LocalContactInfo({
    this.contactType,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.countryCode,
    this.countryNameKo,
  });

  factory LocalContactInfo.fromJson(Map<String, dynamic> json) {
    return LocalContactInfo(
      contactType:
          json['contact_type'] as String? ?? json['contactType'] as String?,
      contactName:
          json['contact_name'] as String? ?? json['contactName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      countryCode:
          json['country_iso_alp2'] as String? ?? json['countryCode'] as String?,
      countryNameKo:
          json['country_nm'] as String? ?? json['countryNameKo'] as String?,
    );
  }
}

/// 외교부 API 통합 연락처 정보 (EmergencySheet에서 사용)
class MofaContactInfo {
  final List<EmbassyInfo> embassies;
  final List<LocalContactInfo> localContacts;
  final String? countryCode;
  final String? countryNameKo;

  MofaContactInfo({
    this.embassies = const [],
    this.localContacts = const [],
    this.countryCode,
    this.countryNameKo,
  });
}

/// 외교부 API 여행경보 정보 모델
class TravelWarningInfo {
  final String? countryCode;
  final String? countryNameKo;
  final String? countryNameEn;
  final String? warningLevel;
  final String? warningLevelName;
  final String? title;
  final String? content;
  final String? writtenDate;

  TravelWarningInfo({
    this.countryCode,
    this.countryNameKo,
    this.countryNameEn,
    this.warningLevel,
    this.warningLevelName,
    this.title,
    this.content,
    this.writtenDate,
  });

  factory TravelWarningInfo.fromJson(Map<String, dynamic> json) {
    return TravelWarningInfo(
      countryCode:
          json['country_iso_alp2'] as String? ?? json['countryCode'] as String?,
      countryNameKo:
          json['country_nm'] as String? ?? json['countryNameKo'] as String?,
      countryNameEn:
          json['country_eng_nm'] as String? ?? json['countryNameEn'] as String?,
      warningLevel:
          json['alarm_lvl'] as String? ?? json['warningLevel'] as String?,
      warningLevelName:
          json['alarm_lvl_nm'] as String? ??
          json['warningLevelName'] as String?,
      title: json['title'] as String?,
      content: json['txt_origin_cn'] as String? ?? json['content'] as String?,
      writtenDate: json['wrt_dt'] as String? ?? json['writtenDate'] as String?,
    );
  }
}

/// 외교부 API 안전공지 모델
class SafetyNoticeInfo {
  final String? countryCode;
  final String? countryNameKo;
  final String? countryNameEn;
  final String? title;
  final String? content;
  final String? writtenDate;
  final String? fileDownloadUrl;

  SafetyNoticeInfo({
    this.countryCode,
    this.countryNameKo,
    this.countryNameEn,
    this.title,
    this.content,
    this.writtenDate,
    this.fileDownloadUrl,
  });

  factory SafetyNoticeInfo.fromJson(Map<String, dynamic> json) {
    return SafetyNoticeInfo(
      countryCode:
          json['country_iso_alp2'] as String? ?? json['countryCode'] as String?,
      countryNameKo:
          json['country_nm'] as String? ?? json['countryNameKo'] as String?,
      countryNameEn:
          json['country_eng_nm'] as String? ?? json['countryNameEn'] as String?,
      title: json['title'] as String?,
      content: json['txt_origin_cn'] as String? ?? json['content'] as String?,
      writtenDate: json['wrt_dt'] as String? ?? json['writtenDate'] as String?,
      fileDownloadUrl:
          json['file_download_url'] as String? ??
          json['fileDownloadUrl'] as String?,
    );
  }
}

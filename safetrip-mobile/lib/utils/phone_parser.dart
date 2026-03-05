/// 전화번호 파싱 유틸리티
class PhoneParser {
  /// 전화번호에서 국가코드와 번호를 분리
  /// 입력 형식: "+82 10-1234-5678", "82 10-1234-5678", "010-1234-5678" 등
  /// 반환: {'countryCode': '82', 'number': '01012345678'} (0으로 시작)
  static Map<String, String> parsePhoneNumber(String phoneInput) {
    // 공백, 하이픈, 괄호 제거
    String cleaned = phoneInput.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // 국가코드 패턴: +82, 82, 0082 등
    final countryCodePattern = RegExp(r'^(\+?82|0082)');
    
    String countryCode = '82'; // 기본값: 한국
    String number = cleaned;
    
    // 국가코드가 포함되어 있는지 확인
    if (countryCodePattern.hasMatch(cleaned)) {
      final match = countryCodePattern.firstMatch(cleaned);
      if (match != null) {
        String matchedCode = match.group(0)!;
        // + 제거, 00 제거
        matchedCode = matchedCode.replaceAll('+', '').replaceAll('00', '');
        countryCode = matchedCode;
        // 국가코드 제거
        number = cleaned.substring(match.end);
      }
    }
    
    // 숫자만 남기기
    number = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 한국 전화번호 처리: 0으로 시작하지 않으면 0 추가
    if (!number.startsWith('0') && number.length >= 10) {
      // 국가코드가 포함된 경우 (82로 시작하는 경우) 0 추가
      if (countryCode == '82' && number.length == 10) {
        number = '0$number';
      }
    }
    
    return {
      'countryCode': countryCode,
      'number': number,
    };
  }
  
  /// 국가코드와 번호를 합쳐서 전체 전화번호 반환 (E.164 형식)
  static String combinePhoneNumber(String countryCode, String number) {
    // countryCode에서 + 제거 (이미 포함되어 있을 수 있음)
    String cleanCountryCode = countryCode.replaceAll('+', '');
    
    // 숫자만 추출
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 한국 전화번호인 경우 앞의 0 제거 (E.164 형식: +8210...)
    if (cleanCountryCode == '82' && cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }
    
    return '+$cleanCountryCode$cleanNumber';
  }
  
  /// 전화번호 형식 검증 (한국: 10-11자리, 0으로 시작)
  static bool isValidKoreanPhoneNumber(String number) {
    // 숫자만 추출
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    // 10자리 또는 11자리이고 0으로 시작 (010-1234-5678 형식)
    return digits.length >= 10 && 
           digits.length <= 11 && 
           digits.startsWith('0');
  }
}


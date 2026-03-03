// 공통 유효성 검사 함수

export function isValidPhoneNumber(phone: string): boolean {
  // E.164 형식 검증: +821012345678
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  return phoneRegex.test(phone);
}

export function isValidOTPCode(otp: string): boolean {
  // 6자리 숫자 검증
  const otpRegex = /^\d{6}$/;
  return otpRegex.test(otp);
}

export function isValidUUID(uuid: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}


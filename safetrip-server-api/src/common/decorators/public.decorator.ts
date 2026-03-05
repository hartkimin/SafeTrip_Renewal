import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * @Public() — 특정 라우트의 인증 검사를 건너뜁니다.
 * 로그인, 헬스체크 등 무인증 API에 사용합니다.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

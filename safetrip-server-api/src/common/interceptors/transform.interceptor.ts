import {
    Injectable,
    NestInterceptor,
    ExecutionContext,
    CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * 전역 응답 변환 인터셉터 — 모든 성공 응답을 { success: true, data: ... } 형태로 래핑
 * 기존 Express 클라이언트 호환
 */
@Injectable()
export class TransformInterceptor<T>
    implements NestInterceptor<T, { success: boolean; data: T }> {
    intercept(
        context: ExecutionContext,
        next: CallHandler,
    ): Observable<{ success: boolean; data: T }> {
        return next.handle().pipe(
            map((data) => ({
                success: true,
                data,
            })),
        );
    }
}

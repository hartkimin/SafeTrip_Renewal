import {
    ExceptionFilter,
    Catch,
    ArgumentsHost,
    HttpException,
    HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

/**
 * 전역 예외 필터 — 기존 Express 클라이언트와 동일한 응답 포맷 유지
 * { success: false, error: "..." }
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
    catch(exception: unknown, host: ArgumentsHost) {
        const ctx = host.switchToHttp();
        const response = ctx.getResponse<Response>();

        let status = HttpStatus.INTERNAL_SERVER_ERROR;
        let message = 'Internal server error';

        if (exception instanceof HttpException) {
            status = exception.getStatus();
            const exceptionResponse = exception.getResponse();
            message =
                typeof exceptionResponse === 'string'
                    ? exceptionResponse
                    : (exceptionResponse as any).message || exception.message;
        } else if (exception instanceof Error) {
            message = exception.message;
        }

        const errorResponse: Record<string, any> = {
            success: false,
            error: Array.isArray(message) ? message.join(', ') : message,
        };

        // 개발 환경에서는 스택 트레이스 포함
        if (process.env.NODE_ENV === 'development' && exception instanceof Error) {
            errorResponse.stack = exception.stack;
        }

        response.status(status).json(errorResponse);
    }
}

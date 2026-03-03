import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/**
 * @CurrentUser() — 현재 인증된 사용자의 Firebase UID를 주입합니다.
 * 컨트롤러에서 @CurrentUser() userId: string 으로 사용합니다.
 */
export const CurrentUser = createParamDecorator(
    (data: string | undefined, ctx: ExecutionContext) => {
        const request = ctx.switchToHttp().getRequest();
        if (data) {
            return request.user?.[data];
        }
        return request.userId;
    },
);

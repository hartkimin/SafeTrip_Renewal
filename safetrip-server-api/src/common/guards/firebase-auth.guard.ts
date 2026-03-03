import {
    Injectable,
    CanActivate,
    ExecutionContext,
    UnauthorizedException,
    Inject,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import * as admin from 'firebase-admin';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../entities/user.entity';

/**
 * Firebase ID Token 검증 Auth Guard
 * - 모든 라우트에 기본 적용 (AppModule에서 글로벌 등록)
 * - @Public() 데코레이터가 있는 라우트는 인증 건너뜀
 * - 인증 통과 후, TB_USER에 해당 UID가 없으면 자동 INSERT (upsert)
 */
@Injectable()
export class FirebaseAuthGuard implements CanActivate {
    constructor(
        private reflector: Reflector,
        @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
        @InjectRepository(User) private userRepo: Repository<User>,
    ) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        // @Public() 데코레이터 확인
        const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
            context.getHandler(),
            context.getClass(),
        ]);
        if (isPublic) return true;

        const request = context.switchToHttp().getRequest();
        const authHeader = request.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            throw new UnauthorizedException('No token provided');
        }

        const token = authHeader.split('Bearer ')[1];

        try {
            const decodedToken = await this.firebaseApp
                .auth()
                .verifyIdToken(token);

            // req.user, req.userId 주입 (기존 Express 미들웨어와 동일)
            request.user = decodedToken;
            request.userId = decodedToken.uid;

            // Auto-upsert: tb_user에 없으면 자동 INSERT
            let user = await this.userRepo.findOne({
                where: { userId: decodedToken.uid },
            });

            if (!user) {
                user = this.userRepo.create({
                    userId: decodedToken.uid,
                    phoneNumber: decodedToken.phone_number || '',
                    phoneCountryCode: '+82',
                    displayName: `User_${decodedToken.uid.substring(0, 5)}`,
                    lastVerificationAt: new Date(),
                });
                await this.userRepo.save(user);
            } else {
                // 검증 시각 갱신
                await this.userRepo.update(decodedToken.uid, {
                    lastVerificationAt: new Date(),
                });
            }

            return true;
        } catch (error) {
            throw new UnauthorizedException('Invalid or expired token');
        }
    }
}

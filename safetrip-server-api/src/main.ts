import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { LoggerService } from './common/logger/logger.service';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, {
        bufferLogs: true,
    });

    const logger = app.get(LoggerService);
    app.useLogger(logger);

    // Security
    app.use(helmet());
    app.enableCors({
        origin: process.env.CORS_ORIGINS?.split(',') || '*',
        methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'x-test-bypass', 'x-test-user-id'],
        credentials: true,
    });

    // Global prefix: /api/v1
    app.setGlobalPrefix('api/v1', {
        exclude: ['health'],
    });

    // Global pipes — DTO validation
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            forbidNonWhitelisted: true,
            transform: true,
            transformOptions: { enableImplicitConversion: true },
        }),
    );

    // Global filters & interceptors
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());

    // Swagger / OpenAPI setup
    const swaggerConfig = new DocumentBuilder()
        .setTitle('SafeTrip API')
        .setDescription('SafeTrip Backend API v2.0 (NestJS)')
        .setVersion('2.0')
        .addBearerAuth(
            { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
            'firebase-auth',
        )
        .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);

    const port = process.env.PORT || 3001;
    await app.listen(port);
    logger.log(`SafeTrip API Server (NestJS) running on port ${port}`);
}
bootstrap();

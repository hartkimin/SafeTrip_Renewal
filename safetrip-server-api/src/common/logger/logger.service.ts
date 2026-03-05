import { Injectable, LoggerService as NestLoggerService } from '@nestjs/common';
import * as winston from 'winston';

@Injectable()
export class LoggerService implements NestLoggerService {
    private logger: winston.Logger;

    constructor() {
        this.logger = winston.createLogger({
            level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
            format: winston.format.combine(
                winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
                winston.format.errors({ stack: true }),
                winston.format.json(),
            ),
            defaultMeta: { service: 'safetrip-api' },
            transports: [
                new winston.transports.Console({
                    format: winston.format.combine(
                        winston.format.colorize(),
                        winston.format.printf(({ timestamp, level, message, ...meta }) => {
                            const metaStr = Object.keys(meta).length > 1 ? ` ${JSON.stringify(meta)}` : '';
                            return `${timestamp} [${level}]: ${message}${metaStr}`;
                        }),
                    ),
                }),
            ],
        });
    }

    log(message: string, ...optionalParams: any[]) {
        this.logger.info(message, ...optionalParams);
    }

    error(message: string, ...optionalParams: any[]) {
        this.logger.error(message, ...optionalParams);
    }

    warn(message: string, ...optionalParams: any[]) {
        this.logger.warn(message, ...optionalParams);
    }

    debug(message: string, ...optionalParams: any[]) {
        this.logger.debug(message, ...optionalParams);
    }

    verbose(message: string, ...optionalParams: any[]) {
        this.logger.verbose(message, ...optionalParams);
    }
}

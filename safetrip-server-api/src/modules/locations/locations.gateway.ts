import {
    WebSocketGateway,
    SubscribeMessage,
    MessageBody,
    ConnectedSocket,
    WebSocketServer,
    OnGatewayConnection,
    OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { LocationsService } from './locations.service';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
    cors: {
        origin: '*',
    },
    namespace: '/location'
})
export class LocationsGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private readonly logger = new Logger(LocationsGateway.name);

    constructor(private readonly locationsService: LocationsService) { }

    handleConnection(client: Socket) {
        this.logger.log(`Client Connected: ${client.id}`);
    }

    handleDisconnect(client: Socket) {
        this.logger.log(`Client Disconnected: ${client.id}`);
    }

    // Client emits 'joinTrip' with a tripId
    @SubscribeMessage('joinTrip')
    handleJoinTrip(
        @MessageBody() data: { tripId: string, userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.join(data.tripId);
        this.logger.log(`Client ${client.id} (User: ${data.userId}) joined trip location room: ${data.tripId}`);
        client.to(data.tripId).emit('userLocationJoined', { userId: data.userId });
    }

    // Client emits 'leaveTrip'
    @SubscribeMessage('leaveTrip')
    handleLeaveTrip(
        @MessageBody() data: { tripId: string, userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.leave(data.tripId);
        this.logger.log(`Client ${client.id} (User: ${data.userId}) left trip location room: ${data.tripId}`);
        client.to(data.tripId).emit('userLocationLeft', { userId: data.userId });
    }

    // Client continuously emits 'updateLocation'
    @SubscribeMessage('updateLocation')
    async handleUpdateLocation(
        @MessageBody() data: {
            tripId: string;
            userId: string;
            latitude: number;
            longitude: number;
            accuracy?: number;
            speed?: number;
            heading?: number;
            batteryLevel?: number;
        },
        @ConnectedSocket() client: Socket,
    ) {
        try {
            // Write location update to DB for history/tracking
            await this.locationsService.logLocation(data);

            // Broadcast the location update to all others in the room
            client.to(data.tripId).emit('locationUpdated', {
                userId: data.userId,
                latitude: data.latitude,
                longitude: data.longitude,
                accuracy: data.accuracy,
                speed: data.speed,
                heading: data.heading,
                batteryLevel: data.batteryLevel,
                timestamp: new Date().toISOString()
            });

            return { status: 'ok' };
        } catch (error) {
            this.logger.error(`Error updating location: ${error.message}`);
            return { status: 'error', message: 'Failed to update location' };
        }
    }
}

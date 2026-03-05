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
import { ChatsService } from './chats.service';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
    cors: {
        origin: '*', // Customize for production
    },
    namespace: '/chat'
})
export class ChatsGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private readonly logger = new Logger(ChatsGateway.name);

    constructor(private readonly chatsService: ChatsService) { }

    handleConnection(client: Socket) {
        this.logger.log(`Client Connected: ${client.id}`);
        // Optionally pass user auth tokens here
    }

    handleDisconnect(client: Socket) {
        this.logger.log(`Client Disconnected: ${client.id}`);
    }

    // Client emits 'joinRoom' with a roomId (typically the Trip ID)
    @SubscribeMessage('joinRoom')
    handleJoinRoom(
        @MessageBody() data: { roomId: string, userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.join(data.roomId);
        this.logger.log(`Client ${client.id} (User: ${data.userId}) joined room: ${data.roomId}`);
        client.to(data.roomId).emit('userJoined', { userId: data.userId, message: 'has joined the chat' });
    }

    // Client emits 'leaveRoom'
    @SubscribeMessage('leaveRoom')
    handleLeaveRoom(
        @MessageBody() data: { roomId: string, userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.leave(data.roomId);
        this.logger.log(`Client ${client.id} (User: ${data.userId}) left room: ${data.roomId}`);
        client.to(data.roomId).emit('userLeft', { userId: data.userId, message: 'has left the chat' });
    }

    // Client emits 'sendMessage'
    @SubscribeMessage('sendMessage')
    async handleMessage(
        @MessageBody() data: { roomId: string; senderId: string; content: string },
        @ConnectedSocket() client: Socket,
    ) {
        try {
            // Write message to Database
            const savedMessage = await this.chatsService.sendMessage(
                data.roomId,
                data.senderId,
                { content: data.content }
            );

            // Broadcast to everyone in the room (including sender)
            this.server.to(data.roomId).emit('newMessage', savedMessage);
            return { status: 'ok', data: savedMessage };
        } catch (error) {
            this.logger.error(`Error sending message: ${error.message}`);
            return { status: 'error', message: 'Failed to send message' };
        }
    }
}

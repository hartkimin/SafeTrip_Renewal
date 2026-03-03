import * as functions from 'firebase-functions';
import { onChatMessageCreated } from './triggers/chat-message-trigger';

export const helloWorld = functions.https.onRequest((request, response) => {
  response.json({ message: 'Hello from SafeTrip Functions!' });
});

// RTDB 트리거: 채팅 메시지 생성 시 FCM 알림 전송
export { onChatMessageCreated };


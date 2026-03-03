import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

// Firebase Admin SDK 초기화 (이미 초기화되어 있으면 스킵)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * RTDB 트리거: 채팅 메시지 생성 시 FCM 알림 전송
 * 
 * realtime_messages/{groupId}/{messageId} onCreate 트리거
 * - 그룹 멤버들의 FCM 토큰을 조회하여 알림 전송
 * - 본인 메시지는 제외
 */
export const onChatMessageCreated = functions.database
  .ref('/realtime_messages/{groupId}/{messageId}')
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.val();
    const groupId = context.params.groupId;
    const messageId = context.params.messageId;

    // 메시지 데이터 검증
    if (!messageData) {
      console.error('[ChatMessageTrigger] 메시지 데이터 없음');
      return null;
    }

    const senderUserId = messageData.sender_user_id;
    const senderName = messageData.sender_name || 'Unknown';
    const messageText = messageData.message_text || '';
    const timestamp = messageData.timestamp || Date.now();

    if (!senderUserId) {
      console.error('[ChatMessageTrigger] sender_user_id 없음');
      return null;
    }

    console.log('[ChatMessageTrigger] 새 메시지 감지', {
      groupId,
      messageId,
      senderUserId,
    });

    try {
      // realtime_tokens/{groupId}에서 그룹 멤버들의 토큰 조회
      const tokensRef = admin.database().ref(`realtime_tokens/${groupId}`);
      const tokensSnapshot = await tokensRef.once('value');
      const tokensData = tokensSnapshot.val();

      if (!tokensData) {
        console.log('[ChatMessageTrigger] 그룹 멤버 토큰 없음');
        return null;
      }

      // 각 사용자별 토큰 수집 (본인 제외)
      const tokens: string[] = [];
      const userIds = Object.keys(tokensData);

      for (const userId of userIds) {
        // 본인 제외
        if (userId === senderUserId) {
          continue;
        }

        const userTokenData = tokensData[userId];
        if (userTokenData && userTokenData.token) {
          tokens.push(userTokenData.token);
        }
      }

      if (tokens.length === 0) {
        console.log('[ChatMessageTrigger] 전송할 토큰 없음');
        return null;
      }

      console.log('[ChatMessageTrigger] FCM 전송 대상', {
        tokenCount: tokens.length,
        groupId,
        messageId,
      });

      // 메시지 본문 최대 100자로 제한
      const notificationBody = messageText.length > 100 
        ? messageText.substring(0, 100) + '...' 
        : messageText;

      // FCM 멀티캐스트 메시지 생성
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: senderName,
          body: notificationBody,
        },
        data: {
          type: 'chat',
          group_id: groupId,
          message_id: messageId,
          sender_user_id: senderUserId,
          timestamp: timestamp.toString(),
        },
        apns: {
          headers: {
            'apns-priority': '10', // High priority
          },
          payload: {
            aps: {
              alert: {
                title: senderName,
                body: notificationBody,
              },
              sound: 'default',
            },
          },
        },
        android: {
          priority: 'high',
          notification: {
            title: senderName,
            body: notificationBody,
            sound: 'default',
          },
        },
      };

      // FCM 전송
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log('[ChatMessageTrigger] FCM 전송 완료', {
        successCount: response.successCount,
        failureCount: response.failureCount,
        groupId,
        messageId,
      });

      // 실패한 토큰 처리 (선택사항)
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
            console.error('[ChatMessageTrigger] FCM 전송 실패', {
              token: tokens[idx].substring(0, 20) + '...',
              error: resp.error?.message,
            });
          }
        });

        // 실패한 토큰은 RTDB에서 제거 (선택사항)
        // TODO: 필요시 구현
      }

      return null;
    } catch (error: any) {
      console.error('[ChatMessageTrigger] 에러 발생', {
        error: error.message,
        stack: error.stack,
        groupId,
        messageId,
      });
      return null;
    }
  });


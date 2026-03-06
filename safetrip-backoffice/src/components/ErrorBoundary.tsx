'use client';

/**
 * Error display component for API errors.
 */
export function ErrorMessage({ error, onRetry }) {
    if (!error) return null;

    const statusMessages = {
        0: '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.',
        401: '인증이 만료되었습니다. 다시 로그인해주세요.',
        403: '접근 권한이 없습니다.',
        404: '요청한 리소스를 찾을 수 없습니다.',
        429: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
        500: '서버 내부 오류가 발생했습니다.',
    };

    const message = typeof error === 'string'
        ? error
        : statusMessages[error.status] || error.message || '알 수 없는 오류가 발생했습니다.';

    const statusCode = typeof error === 'object' ? error.status : null;

    return (
        <div className="error-message" style={{
            padding: '1.5rem',
            borderRadius: '16px',
            background: 'rgba(211, 47, 47, 0.05)',
            border: '1px solid rgba(211, 47, 47, 0.2)',
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
            justifyContent: 'space-between',
        }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <span style={{ fontSize: '1.5rem' }}>⚠️</span>
                <div>
                    {statusCode ? (
                        <span style={{ color: 'var(--danger)', fontWeight: 600, fontSize: '0.85rem' }}>
                            Error {statusCode}
                        </span>
                    ) : null}
                    <p style={{ margin: '4px 0 0', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                        {message}
                    </p>
                </div>
            </div>
            {onRetry && (
                <button
                    onClick={onRetry}
                    className="btn btn-primary"
                    style={{ whiteSpace: 'nowrap', padding: '0.5rem 1rem', fontSize: '0.85rem' }}
                >
                    🔄 다시 시도
                </button>
            )}
        </div>
    );
}

export default ErrorMessage;

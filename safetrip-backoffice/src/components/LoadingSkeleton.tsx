'use client';

/**
 * Loading Skeleton Component
 * Displays animated placeholder content while data is loading.
 */
export function LoadingSkeleton({ type = 'card', count = 1 }) {
    const skeletons = Array.from({ length: count }, (_, i) => i);

    if (type === 'table') {
        return (
            <div className="skeleton-table">
                <div className="skeleton-row skeleton-header">
                    {[1, 2, 3, 4, 5].map((i) => (
                        <div key={i} className="skeleton-cell shimmer" />
                    ))}
                </div>
                {skeletons.map((i) => (
                    <div key={i} className="skeleton-row">
                        {[1, 2, 3, 4, 5].map((j) => (
                            <div key={j} className="skeleton-cell shimmer" />
                        ))}
                    </div>
                ))}
            </div>
        );
    }

    if (type === 'stat') {
        return (
            <div style={{ display: 'grid', gridTemplateColumns: `repeat(${Math.min(count, 4)}, 1fr)`, gap: '1.5rem' }}>
                {skeletons.map((i) => (
                    <div key={i} className="card" style={{ padding: '1.5rem' }}>
                        <div className="skeleton-line shimmer" style={{ width: '60%', height: '14px', marginBottom: '12px' }} />
                        <div className="skeleton-line shimmer" style={{ width: '40%', height: '32px' }} />
                    </div>
                ))}
            </div>
        );
    }

    // Default: card
    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {skeletons.map((i) => (
                <div key={i} className="card" style={{ padding: '1.5rem' }}>
                    <div className="skeleton-line shimmer" style={{ width: '70%', height: '16px', marginBottom: '12px' }} />
                    <div className="skeleton-line shimmer" style={{ width: '100%', height: '12px', marginBottom: '8px' }} />
                    <div className="skeleton-line shimmer" style={{ width: '85%', height: '12px' }} />
                </div>
            ))}
        </div>
    );
}

/**
 * Inline loading spinner
 */
export function Spinner({ size = 20 }) {
    return (
        <span
            className="spinner"
            style={{
                width: size,
                height: size,
                border: `3px solid var(--border)`,
                borderTopColor: 'var(--primary)',
                borderRadius: '50%',
                display: 'inline-block',
                animation: 'spin 0.8s linear infinite',
            }}
        />
    );
}

export default LoadingSkeleton;

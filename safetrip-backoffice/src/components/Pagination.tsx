'use client';

/**
 * Pagination Component
 */
export function Pagination({ page, totalPages, onPageChange }) {
    if (totalPages <= 1) return null;

    const pages = [];
    const maxVisible = 5;
    let start = Math.max(1, page - Math.floor(maxVisible / 2));
    let end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start < maxVisible - 1) {
        start = Math.max(1, end - maxVisible + 1);
    }

    for (let i = start; i <= end; i++) {
        pages.push(i);
    }

    return (
        <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.5rem',
            padding: '1rem 0',
        }}>
            <button
                className="btn"
                disabled={page <= 1}
                onClick={() => onPageChange(page - 1)}
                style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}
            >
                ← 이전
            </button>
            {start > 1 && (
                <>
                    <button className="btn" onClick={() => onPageChange(1)} style={{ padding: '0.4rem 0.6rem', fontSize: '0.85rem' }}>1</button>
                    {start > 2 && <span style={{ color: 'var(--text-secondary)' }}>…</span>}
                </>
            )}
            {pages.map((p) => (
                <button
                    key={p}
                    className={`btn ${p === page ? 'btn-primary' : ''}`}
                    onClick={() => onPageChange(p)}
                    style={{ padding: '0.4rem 0.6rem', fontSize: '0.85rem', minWidth: '36px' }}
                >
                    {p}
                </button>
            ))}
            {end < totalPages && (
                <>
                    {end < totalPages - 1 && <span style={{ color: 'var(--text-secondary)' }}>…</span>}
                    <button className="btn" onClick={() => onPageChange(totalPages)} style={{ padding: '0.4rem 0.6rem', fontSize: '0.85rem' }}>{totalPages}</button>
                </>
            )}
            <button
                className="btn"
                disabled={page >= totalPages}
                onClick={() => onPageChange(page + 1)}
                style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}
            >
                다음 →
            </button>
        </div>
    );
}

export default Pagination;

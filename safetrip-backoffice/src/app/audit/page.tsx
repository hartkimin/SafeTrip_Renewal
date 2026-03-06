'use client';

import { useState, useEffect } from 'react';
import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { Pagination } from '@/components/Pagination';
import { ClipboardList, MapPin, Download } from 'lucide-react';

const SEVERITY_BADGE = { critical: 'danger', high: 'warning', medium: 'info', low: 'neutral' };

export default function AuditPage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [logs, setLogs] = useState([]);
    const [filterSeverity, setFilterSeverity] = useState('');
    const [page, setPage] = useState(1);
    const [totalPages, setTotalPages] = useState(1);

    async function fetchLogs() {
        setLoading(true);
        setError(null);
        try {
            const res = await api.get(API.EVENTS.LIST, { page, limit: 20 });
            const eventData = res?.data || res?.events || res || [];
            if (Array.isArray(eventData)) {
                setLogs(eventData.map(e => ({
                    id: e.event_id || e.id,
                    admin: e.admin_email || e.user_name || 'system',
                    action: e.event_type || e.action || '-',
                    target: e.target_id || e.entity_id || '-',
                    severity: e.severity || 'low',
                    ip: e.ip_address || '-',
                    date: e.created_at ? new Date(e.created_at).toLocaleString('ko-KR') : '-',
                })));
                setTotalPages(res?.totalPages || Math.ceil((res?.total || eventData.length) / 20) || 1);
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { fetchLogs(); }, [page]);

    const filtered = filterSeverity ? logs.filter(l => l.severity === filterSeverity) : logs;
    const locationAccessLogs = logs.filter(l => l.action.includes('location'));

    return (
        <div className="slide-in">
            <h1 className="page-title"><ClipboardList size={24} strokeWidth={2} /> Audit Logs</h1>
            <p className="page-subtitle">관리자 행동 기록 및 데이터 접근 이력을 관리합니다. (GDPR / 위치정보법 준수)</p>
            {error && <ErrorMessage error={error} onRetry={fetchLogs} />}

            <div className="panel">
                <div className="panel-header">
                    <span>Admin Action Logs</span>
                    <div style={{ display: 'flex', gap: '8px' }}>
                        <select value={filterSeverity} onChange={e => setFilterSeverity(e.target.value)} style={{ padding: '6px 12px', border: '1px solid var(--border-light)', borderRadius: '8px', fontSize: '13px' }}>
                            <option value="">All Severity</option>
                            <option value="critical">Critical</option>
                            <option value="high">High</option>
                            <option value="medium">Medium</option>
                            <option value="low">Low</option>
                        </select>
                        <button className="btn btn-outline"><Download size={14} /> Export CSV</button>
                    </div>
                </div>
                {loading ? <LoadingSkeleton type="table" count={6} /> : filtered.length === 0 ? (
                    <div className="empty-state"><div className="empty-state-icon"><ClipboardList size={48} strokeWidth={1.5} /></div><p>감사 로그가 없습니다.</p></div>
                ) : (
                    <table className="data-table">
                        <thead><tr><th>ID</th><th>Admin</th><th>Action</th><th>Target</th><th>Severity</th><th>IP</th><th>Timestamp</th></tr></thead>
                        <tbody>
                            {filtered.map(l => (
                                <tr key={l.id}>
                                    <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>{l.id}</td>
                                    <td>{l.admin}</td>
                                    <td><code style={{ fontSize: '12px', background: 'var(--surface-variant)', padding: '2px 8px', borderRadius: '4px' }}>{l.action}</code></td>
                                    <td style={{ fontFamily: 'monospace' }}>{l.target}</td>
                                    <td><span className={`badge ${SEVERITY_BADGE[l.severity] || 'neutral'}`}>{l.severity}</span></td>
                                    <td style={{ fontSize: '12px', color: 'var(--text-tertiary)' }}>{l.ip}</td>
                                    <td style={{ fontSize: '13px' }}>{l.date}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
                <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
            </div>

            {/* Location Data Access Logs (GDPR) */}
            <div className="panel">
                <div className="panel-header"><span><MapPin size={18} /> Location Data Access Tracking (위치정보법 §16)</span><span className="badge danger">{locationAccessLogs.length} records</span></div>
                {locationAccessLogs.length > 0 ? (
                    <table className="data-table">
                        <thead><tr><th>Admin</th><th>Action</th><th>Target User</th><th>IP</th><th>Timestamp</th></tr></thead>
                        <tbody>
                            {locationAccessLogs.map(l => (
                                <tr key={l.id}>
                                    <td>{l.admin}</td>
                                    <td><code style={{ fontSize: '12px', background: '#FFE8EB', padding: '2px 8px', borderRadius: '4px', color: 'var(--sos-danger)' }}>{l.action}</code></td>
                                    <td>{l.target}</td>
                                    <td>{l.ip}</td>
                                    <td>{l.date}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                ) : (
                    <div className="empty-state" style={{ padding: '24px' }}><p>위치 데이터 접근 기록이 없습니다.</p></div>
                )}
            </div>
        </div>
    );
}

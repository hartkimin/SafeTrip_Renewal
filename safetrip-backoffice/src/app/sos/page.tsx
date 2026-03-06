'use client';

import { useState, useEffect, useMemo } from 'react';
import dynamic from 'next/dynamic';
import { sosService } from '@/services/sosService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import {
    ShieldAlert, CircleCheck, MapPin, ClipboardList,
    Battery, Wifi, Clock, Maximize2,
} from 'lucide-react';

// Dynamic import — Leaflet requires `window` (no SSR)
const SOSMap = dynamic(() => import('@/components/SOSMap'), {
    ssr: false,
    loading: () => (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-tertiary)' }}>
            지도 로딩 중...
        </div>
    ),
});

export default function SOSPage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [events, setEvents] = useState([]);
    const [stats, setStats] = useState({ unresolved: 0, inProgress: 0, resolvedToday: 0, avgResponse: '-' });
    const [resolving, setResolving] = useState(null);

    async function fetchSosData() {
        setLoading(true);
        setError(null);
        try {
            const res = await sosService.getEmergencies();
            const emergencies = res?.data || res || [];
            if (Array.isArray(emergencies)) {
                setEvents(emergencies.map(e => ({
                    id: e.emergency_id || e.id,
                    user: e.user_name || e.user?.name || 'Unknown',
                    trip: e.trip_id || '-',
                    location: e.location || '-',
                    time: e.created_at ? new Date(e.created_at).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' }) : '-',
                    status: (e.status || 'ACTIVE').toUpperCase(),
                    battery: e.battery_level ? `${e.battery_level}%` : '-',
                    network: e.network_type || '-',
                    lat: e.latitude || e.lat || null,
                    lng: e.longitude || e.lng || null,
                })));
                setStats({
                    unresolved: emergencies.filter(e => e.status === 'active').length,
                    inProgress: emergencies.filter(e => e.status === 'in_progress').length,
                    resolvedToday: emergencies.filter(e => e.status === 'resolved').length,
                    avgResponse: res?.avgResponseTime || '-',
                });
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    async function handleResolve(eventId) {
        setResolving(eventId);
        try {
            await sosService.resolveEmergency(eventId, { resolved_by: 'admin' });
            setEvents(prev => prev.map(e => e.id === eventId ? { ...e, status: 'RESOLVED' } : e));
        } catch (err) {
            alert(`해결 처리 실패: ${err.message}`);
        } finally {
            setResolving(null);
        }
    }

    useEffect(() => { fetchSosData(); }, []);

    const activeEvents = events.filter(e => e.status === 'ACTIVE');

    return (
        <div className="slide-in">
            <h1 className="page-title"><ShieldAlert size={24} strokeWidth={2} /> SOS Response Center</h1>
            <p className="page-subtitle">실시간 SOS 이벤트를 모니터링하고 즉각적으로 대응합니다.</p>
            {error && <ErrorMessage error={error} onRetry={fetchSosData} />}

            {loading ? <LoadingSkeleton type="stat" count={4} /> : (
                <div className="dashboard-grid">
                    <div className="stat-card alert"><div className="stat-title">UNRESOLVED</div><div className="stat-value danger">{stats.unresolved}</div></div>
                    <div className="stat-card amber"><div className="stat-title">IN PROGRESS</div><div className="stat-value">{stats.inProgress}</div></div>
                    <div className="stat-card success"><div className="stat-title">RESOLVED TODAY</div><div className="stat-value success">{stats.resolvedToday}</div></div>
                    <div className="stat-card teal"><div className="stat-title">AVG RESPONSE</div><div className="stat-value teal">{stats.avgResponse}</div></div>
                </div>
            )}

            <div style={{ display: 'grid', gridTemplateColumns: '380px 1fr', gap: '20px' }}>
                {/* Active Events Sidebar */}
                <div className="panel">
                    <div className="panel-header"><span>Active Events</span><span className="badge danger">{activeEvents.length}</span></div>
                    <div className="panel-content" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        {loading ? <LoadingSkeleton type="card" count={3} /> :
                            activeEvents.length === 0 ? (
                                <div className="empty-state"><div className="empty-state-icon"><CircleCheck size={48} strokeWidth={1.5} /></div><p>활성 SOS 이벤트 없음</p></div>
                            ) : activeEvents.map(ev => (
                                <div key={ev.id} className="sos-event-card">
                                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                        <strong>{ev.user}</strong>
                                        <span className="badge danger">● ACTIVE</span>
                                    </div>
                                    <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '4px' }}>Trip {ev.trip} · {ev.location}</div>
                                    <div style={{ fontSize: '12px', color: 'var(--text-tertiary)', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                        <Battery size={12} /> {ev.battery} · <Wifi size={12} /> {ev.network} · <Clock size={12} /> {ev.time}
                                    </div>
                                    <button
                                        className="btn btn-danger"
                                        style={{ width: '100%', justifyContent: 'center' }}
                                        disabled={resolving === ev.id}
                                        onClick={() => handleResolve(ev.id)}
                                    >
                                        {resolving === ev.id ? '처리 중...' : 'Handle This SOS'}
                                    </button>
                                </div>
                            ))
                        }
                    </div>
                </div>

                {/* Map */}
                <div className="panel" style={{ minHeight: '500px', position: 'relative' }}>
                    <div className="panel-header"><span><MapPin size={16} /> SOS Live Map (OpenStreetMap)</span><button className="btn btn-outline"><Maximize2 size={14} /> Full Screen</button></div>
                    <div style={{ height: 'calc(100% - 56px)', minHeight: '440px' }}>
                        <SOSMap events={events} />
                    </div>
                </div>
            </div>

            {/* Rescue Log */}
            <div className="panel" style={{ marginTop: '20px' }}>
                <div className="panel-header"><ClipboardList size={18} /> Recent Rescue Log</div>
                {loading ? <LoadingSkeleton type="table" count={3} /> : events.length === 0 ? (
                    <div className="empty-state"><div className="empty-state-icon"><ClipboardList size={48} strokeWidth={1.5} /></div><p>SOS 기록이 없습니다.</p></div>
                ) : (
                    <table className="data-table">
                        <thead><tr><th>ID</th><th>User</th><th>Trip</th><th>Location</th><th>Time</th><th>Status</th><th>Actions</th></tr></thead>
                        <tbody>
                            {events.map(ev => (
                                <tr key={ev.id}>
                                    <td style={{ fontWeight: 600 }}>{ev.id}</td>
                                    <td>{ev.user}</td>
                                    <td>{ev.trip}</td>
                                    <td>{ev.location}</td>
                                    <td>{ev.time}</td>
                                    <td><span className={`badge ${ev.status === 'ACTIVE' ? 'danger' : ev.status === 'RESOLVED' ? 'success' : 'warning'}`}>{ev.status}</span></td>
                                    <td>{ev.status === 'ACTIVE' && <button className="btn btn-danger" style={{ padding: '4px 12px', fontSize: '12px' }} onClick={() => handleResolve(ev.id)}>Resolve</button>}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}

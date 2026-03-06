'use client';

import { useState, useEffect } from 'react';
import { tripService } from '@/services/tripService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { Pagination } from '@/components/Pagination';
import { Plane, Users, ChevronRight } from 'lucide-react';

const PRIVACY_LABELS = { safety_first: '안전최우선', standard: '표준', privacy_first: '프라이버시' };
const PRIVACY_BADGE = { safety_first: 'danger', standard: 'info', privacy_first: 'neutral' };
const ROLE_BADGE = { captain: 'captain', crew_chief: 'crew-chief', crew: 'crew', guardian: 'guardian' };

export default function TripsPage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [trips, setTrips] = useState([]);
    const [selectedTrip, setSelectedTrip] = useState(null);
    const [members, setMembers] = useState([]);
    const [membersLoading, setMembersLoading] = useState(false);
    const [page, setPage] = useState(1);
    const [totalPages, setTotalPages] = useState(1);

    async function fetchTrips() {
        setLoading(true);
        setError(null);
        try {
            const res = await tripService.getTrips({ page });
            const tripData = res?.data || res?.trips || res || [];
            if (Array.isArray(tripData)) {
                setTrips(tripData.map(t => ({
                    id: t.trip_id || t.id,
                    name: t.trip_name || t.name || '-',
                    destination: t.destination || '-',
                    captain: t.captain_name || t.captain?.name || '-',
                    members: t.member_count || 0,
                    status: t.status || 'active',
                    privacy: t.privacy_level || 'standard',
                    startDate: t.start_date ? new Date(t.start_date).toISOString().split('T')[0] : '-',
                    endDate: t.end_date ? new Date(t.end_date).toISOString().split('T')[0] : '-',
                })));
                setTotalPages(res?.totalPages || Math.ceil((res?.total || tripData.length) / 20) || 1);
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    async function fetchMembers(tripId) {
        setMembersLoading(true);
        setMembers([]);
        try {
            const res = await tripService.getTripMembers(tripId);
            const memberData = res?.data || res?.members || res || [];
            if (Array.isArray(memberData)) {
                setMembers(memberData.map(m => ({
                    name: m.display_name || m.name || '-',
                    role: m.member_role || m.role || 'crew',
                    status: m.status || 'active',
                })));
            }
        } catch (err) {
            console.error('[Trips] Failed to load members:', err.message);
        } finally {
            setMembersLoading(false);
        }
    }

    useEffect(() => { fetchTrips(); }, [page]);

    function handleTripClick(trip) {
        setSelectedTrip(trip);
        fetchMembers(trip.id);
    }

    const activeTrips = trips.filter(t => t.status === 'active').length;
    const totalMembers = trips.reduce((sum, t) => sum + t.members, 0);

    return (
        <div className="slide-in">
            <h1 className="page-title"><Plane size={24} strokeWidth={2} /> Trips & Groups</h1>
            <p className="page-subtitle">여행 및 그룹을 관리합니다.</p>
            {error && <ErrorMessage error={error} onRetry={fetchTrips} />}

            {loading ? <LoadingSkeleton type="stat" count={4} /> : (
                <div className="dashboard-grid">
                    <div className="stat-card teal"><div className="stat-title">TOTAL TRIPS</div><div className="stat-value teal">{trips.length}</div></div>
                    <div className="stat-card success"><div className="stat-title">ACTIVE</div><div className="stat-value success">{activeTrips}</div></div>
                    <div className="stat-card amber"><div className="stat-title">TOTAL MEMBERS</div><div className="stat-value">{totalMembers}</div></div>
                    <div className="stat-card"><div className="stat-title">AVG GROUP SIZE</div><div className="stat-value">{trips.length ? Math.round(totalMembers / trips.length) : 0}</div></div>
                </div>
            )}

            <div className="panel">
                <div className="panel-header"><span>Trip List</span></div>
                {loading ? <LoadingSkeleton type="table" count={4} /> : trips.length === 0 ? (
                    <div className="empty-state"><div className="empty-state-icon"><Plane size={48} strokeWidth={1.5} /></div><p>여행 데이터가 없습니다.</p></div>
                ) : (
                    <table className="data-table">
                        <thead><tr><th>ID</th><th>Name</th><th>Destination</th><th>Captain</th><th>Members</th><th>Privacy</th><th>Status</th><th>Period</th></tr></thead>
                        <tbody>
                            {trips.map(t => (
                                <tr key={t.id} onClick={() => handleTripClick(t)} style={{ cursor: 'pointer' }}>
                                    <td style={{ fontFamily: 'monospace' }}>{t.id}</td>
                                    <td style={{ fontWeight: 600 }}>{t.name}</td>
                                    <td>{t.destination}</td>
                                    <td>{t.captain}</td>
                                    <td>{t.members}</td>
                                    <td><span className={`badge ${PRIVACY_BADGE[t.privacy] || 'neutral'}`}>{PRIVACY_LABELS[t.privacy] || t.privacy}</span></td>
                                    <td><span className={`badge ${t.status === 'active' ? 'active' : 'neutral'}`}>{t.status}</span></td>
                                    <td style={{ fontSize: '13px' }}>{t.startDate} ~ {t.endDate}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
                <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
            </div>

            {/* Group Members Detail */}
            <div className="panel">
                <div className="panel-header"><span><Users size={18} /> Group Members {selectedTrip ? `— ${selectedTrip.name}` : ''}</span></div>
                <div className="panel-content">
                    {!selectedTrip ? (
                        <div className="empty-state"><div className="empty-state-icon"><ChevronRight size={48} strokeWidth={1.5} /></div><p>여행을 선택하면 그룹 멤버를 확인할 수 있습니다.</p></div>
                    ) : membersLoading ? (
                        <LoadingSkeleton type="card" count={4} />
                    ) : members.length === 0 ? (
                        <div className="empty-state"><div className="empty-state-icon"><Users size={48} strokeWidth={1.5} /></div><p>멤버 데이터가 없습니다.</p></div>
                    ) : (
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '12px' }}>
                            {members.map((m, i) => (
                                <div key={i} style={{ padding: '16px', border: '1px solid var(--border-light)', borderRadius: 'var(--radius-12)' }}>
                                    <div style={{ fontWeight: 600, marginBottom: '8px' }}>{m.name}</div>
                                    <span className={`badge ${ROLE_BADGE[m.role] || 'neutral'}`}>{m.role.replace('_', ' ')}</span>
                                    <span className={`badge ${m.status === 'active' ? 'active' : 'neutral'}`} style={{ marginLeft: '6px' }}>{m.status}</span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

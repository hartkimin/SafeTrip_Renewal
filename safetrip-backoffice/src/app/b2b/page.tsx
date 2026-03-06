'use client';

import { useState, useEffect } from 'react';
import { b2bService } from '@/services/b2bService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { Building2, ClipboardList, Plus, Eye } from 'lucide-react';

export default function B2BPage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [partners, setPartners] = useState([]);
    const [selectedPartner, setSelectedPartner] = useState(null);

    async function fetchPartners() {
        setLoading(true);
        setError(null);
        try {
            const res = await b2bService.getOrganizations();
            const orgData = res?.data || res?.organizations || res || [];
            if (Array.isArray(orgData)) {
                setPartners(orgData.map(o => ({
                    id: o.org_id || o.id,
                    name: o.org_name || o.name || '-',
                    type: o.org_type || o.type || 'corporate',
                    contract: o.contract_status || 'ACTIVE',
                    students: o.member_count || 0,
                    revenue: o.total_revenue ? `₩${Number(o.total_revenue).toLocaleString()}` : '-',
                    startDate: o.contract_start ? new Date(o.contract_start).toISOString().split('T')[0] : '-',
                    endDate: o.contract_end ? new Date(o.contract_end).toISOString().split('T')[0] : '-',
                })));
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { fetchPartners(); }, []);

    const activePartners = partners.filter(p => p.contract === 'ACTIVE').length;
    const totalMembers = partners.reduce((s, p) => s + p.students, 0);

    return (
        <div className="slide-in">
            <h1 className="page-title"><Building2 size={24} strokeWidth={2} /> B2B Partner Management</h1>
            <p className="page-subtitle">B2B 파트너 계약 및 운영을 관리합니다.</p>
            {error && <ErrorMessage error={error} onRetry={fetchPartners} />}

            {loading ? <LoadingSkeleton type="stat" count={4} /> : (
                <div className="dashboard-grid">
                    <div className="stat-card teal"><div className="stat-title">TOTAL PARTNERS</div><div className="stat-value teal">{partners.length}</div></div>
                    <div className="stat-card success"><div className="stat-title">ACTIVE CONTRACTS</div><div className="stat-value success">{activePartners}</div></div>
                    <div className="stat-card amber"><div className="stat-title">TOTAL MEMBERS</div><div className="stat-value">{totalMembers.toLocaleString()}</div></div>
                    <div className="stat-card"><div className="stat-title">SCHOOLS</div><div className="stat-value">{partners.filter(p => p.type === 'school').length}</div></div>
                </div>
            )}

            <div className="panel">
                <div className="panel-header"><span>Partner List</span><button className="btn btn-primary"><Plus size={14} /> Add Partner</button></div>
                {loading ? <LoadingSkeleton type="table" count={4} /> : partners.length === 0 ? (
                    <div className="empty-state"><div className="empty-state-icon"><Building2 size={48} strokeWidth={1.5} /></div><p>B2B 파트너 데이터가 없습니다.</p></div>
                ) : (
                    <table className="data-table">
                        <thead><tr><th>ID</th><th>Name</th><th>Type</th><th>Contract</th><th>Members</th><th>Revenue</th><th>Period</th><th>Actions</th></tr></thead>
                        <tbody>
                            {partners.map(p => (
                                <tr key={p.id} onClick={() => setSelectedPartner(p)} style={{ cursor: 'pointer' }}>
                                    <td style={{ fontFamily: 'monospace' }}>{p.id}</td>
                                    <td style={{ fontWeight: 600 }}>{p.name}</td>
                                    <td><span className={`badge ${p.type === 'school' ? 'info' : 'neutral'}`}>{p.type}</span></td>
                                    <td><span className={`badge ${p.contract === 'ACTIVE' ? 'active' : p.contract === 'PENDING' ? 'warning' : 'neutral'}`}>{p.contract}</span></td>
                                    <td>{p.students}</td>
                                    <td style={{ fontWeight: 600 }}>{p.revenue}</td>
                                    <td style={{ fontSize: '13px' }}>{p.startDate} ~ {p.endDate}</td>
                                    <td><button className="btn btn-ghost"><Eye size={14} /> View</button></td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            {selectedPartner && (
                <div className="panel">
                    <div className="panel-header"><span><ClipboardList size={18} /> Contract Details — {selectedPartner.name}</span><button className="btn btn-ghost" onClick={() => setSelectedPartner(null)}>✕ Close</button></div>
                    <div className="panel-content">
                        <div className="detail-grid">
                            <div>
                                <div className="detail-row"><span className="detail-label">Organization</span><span className="detail-value">{selectedPartner.name}</span></div>
                                <div className="detail-row"><span className="detail-label">Type</span><span className="detail-value">{selectedPartner.type}</span></div>
                                <div className="detail-row"><span className="detail-label">Contract Status</span><span className="detail-value">{selectedPartner.contract}</span></div>
                            </div>
                            <div>
                                <div className="detail-row"><span className="detail-label">Members</span><span className="detail-value">{selectedPartner.students}</span></div>
                                <div className="detail-row"><span className="detail-label">Revenue</span><span className="detail-value">{selectedPartner.revenue}</span></div>
                                <div className="detail-row"><span className="detail-label">Period</span><span className="detail-value">{selectedPartner.startDate} ~ {selectedPartner.endDate}</span></div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

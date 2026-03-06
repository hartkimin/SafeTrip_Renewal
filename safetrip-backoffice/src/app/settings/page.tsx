'use client';

import { useState, useEffect } from 'react';
import { countryService } from '@/services/countryService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { Settings, Globe, RefreshCw, Phone } from 'lucide-react';

const MOFA_BADGE = { 'none': 'success', 'watch': 'info', 'warning': 'warning', 'danger': 'danger', 'ban': 'danger' };
const MOFA_LABEL = { 'none': '안전', 'watch': '관심', 'warning': '주의', 'danger': '위험', 'ban': '여행금지' };

export default function SettingsPage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [countries, setCountries] = useState([]);
    const [activeTab, setActiveTab] = useState('countries');
    const [searchQuery, setSearchQuery] = useState('');

    // Emergency tab state
    const [selectedCountry, setSelectedCountry] = useState(null);
    const [emergencyData, setEmergencyData] = useState(null);
    const [emergencyLoading, setEmergencyLoading] = useState(false);

    async function fetchCountries() {
        setLoading(true);
        setError(null);
        try {
            const res = await countryService.getCountries();
            const countryData = res?.data || res?.countries || res || [];
            if (Array.isArray(countryData)) {
                setCountries(countryData.map(c => ({
                    flag: c.flag_emoji || c.country_code || '-',
                    name: c.country_name_ko || c.country_name_en || c.name || '-',
                    nameEn: c.country_name_en || '-',
                    code: c.country_code || c.code || '-',
                    mofa: c.mofa_travel_alert || 'none',
                    phone: c.phone_code || '-',
                    region: c.region || '-',
                    emergency: c.emergency_number || '-',
                    updated: c.updated_at ? new Date(c.updated_at).toISOString().split('T')[0] : (c.mofa_alert_updated_at ? new Date(c.mofa_alert_updated_at).toISOString().split('T')[0] : '-'),
                })));
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    async function fetchEmergencyNumbers(countryCode) {
        setEmergencyLoading(true);
        setEmergencyData(null);
        try {
            const res = await countryService.getEmergencyNumbers(countryCode);
            setEmergencyData(res?.data || res || null);
        } catch (err) {
            console.error('[Settings] Emergency fetch failed:', err.message);
        } finally {
            setEmergencyLoading(false);
        }
    }

    useEffect(() => { fetchCountries(); }, []);

    const filteredCountries = countries.filter(c => !searchQuery || c.name.toLowerCase().includes(searchQuery.toLowerCase()) || c.code.includes(searchQuery.toUpperCase()));

    return (
        <div className="slide-in">
            <h1 className="page-title"><Settings size={24} strokeWidth={2} /> System Settings</h1>
            <p className="page-subtitle">국가 데이터, 비상 연락망, 약관 등 시스템 설정을 관리합니다.</p>
            {error && <ErrorMessage error={error} onRetry={fetchCountries} />}

            <div className="tabs">
                {['countries', 'emergency'].map(tab => (
                    <button key={tab} className={`tab ${activeTab === tab ? 'active' : ''}`} onClick={() => setActiveTab(tab)}>
                        {tab === 'countries' ? <><Globe size={16} /> Countries & Alerts</> : <><Phone size={16} /> Emergency Numbers</>}
                    </button>
                ))}
            </div>

            {activeTab === 'countries' && (
                <div className="panel">
                    <div className="panel-header">
                        <span>Country & MOFA Travel Alert Management</span>
                        <button className="btn btn-primary" onClick={fetchCountries}><RefreshCw size={14} /> Sync MOFA API</button>
                    </div>
                    <div className="panel-content">
                        <div className="filter-bar">
                            <input placeholder="Search country..." style={{ flex: 1 }} value={searchQuery} onChange={e => setSearchQuery(e.target.value)} />
                            <select><option>All Alert Levels</option><option>Level 0</option><option>Level 1</option><option>Level 2</option><option>Level 3</option><option>Level 4</option></select>
                        </div>
                        {loading ? <LoadingSkeleton type="table" count={5} /> : filteredCountries.length === 0 ? (
                            <div className="empty-state"><div className="empty-state-icon"><Globe size={48} strokeWidth={1.5} /></div><p>국가 데이터가 없습니다.</p></div>
                        ) : (
                            <table className="data-table">
                                <thead><tr><th>FLAG</th><th>COUNTRY</th><th>CODE</th><th>MOFA ALERT</th><th>PHONE CODE</th><th>EMERGENCY #</th><th>LAST UPDATED</th></tr></thead>
                                <tbody>
                                    {filteredCountries.map(c => (
                                        <tr key={c.code}>
                                            <td style={{ fontSize: '18px', fontWeight: 700 }}>{c.flag}</td>
                                            <td style={{ fontWeight: 600 }}>{c.name}</td>
                                            <td>{c.code}</td>
                                            <td><span className={`badge ${MOFA_BADGE[c.mofa] || 'neutral'}`}>{MOFA_LABEL[c.mofa] || c.mofa}</span></td>
                                            <td>{c.phone}</td>
                                            <td style={{ color: 'var(--primary-teal)', fontWeight: 600 }}>{c.emergency}</td>
                                            <td>{c.updated}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        )}
                    </div>
                </div>
            )}

            {activeTab === 'emergency' && (
                <div className="panel">
                    <div className="panel-header"><span><Phone size={18} /> Emergency Numbers by Country</span></div>
                    <div className="panel-content">
                        {loading ? <LoadingSkeleton type="card" count={3} /> : countries.length === 0 ? (
                            <div className="empty-state"><div className="empty-state-icon"><Phone size={48} strokeWidth={1.5} /></div><p>국가 데이터를 먼저 로드하세요.</p></div>
                        ) : (
                            <>
                                <div className="filter-bar">
                                    <select onChange={e => { setSelectedCountry(e.target.value); if (e.target.value) fetchEmergencyNumbers(e.target.value); }} value={selectedCountry || ''} style={{ minWidth: '200px' }}>
                                        <option value="">국가 선택...</option>
                                        {countries.map(c => <option key={c.code} value={c.code}>{c.name} ({c.code})</option>)}
                                    </select>
                                </div>
                                {emergencyLoading ? <LoadingSkeleton type="card" count={1} /> : emergencyData ? (
                                    <div style={{ padding: '16px', border: '1px solid var(--border-light)', borderRadius: 'var(--radius-12)' }}>
                                        <pre style={{ fontSize: '13px', whiteSpace: 'pre-wrap', fontFamily: 'monospace', color: 'var(--text-secondary)' }}>{JSON.stringify(emergencyData, null, 2)}</pre>
                                    </div>
                                ) : selectedCountry ? (
                                    <div className="empty-state" style={{ padding: '20px' }}><p>비상 데이터를 불러올 수 없습니다.</p></div>
                                ) : null}
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}

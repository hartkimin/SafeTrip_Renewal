'use client';

import { useState, useEffect } from 'react';
import { countryService } from '@/services/countryService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { Settings, Globe, RefreshCw, Phone } from 'lucide-react';
import { PageHeader } from '@/components/PageHeader';

const MOFA_BADGE = { 'none': 'status-tag-success', 'watch': 'status-tag-info', 'warning': 'status-tag-warning', 'danger': 'status-tag-danger', 'ban': 'status-tag-danger' };
const MOFA_LABEL = { 'none': '안전', 'watch': '관심', '주의': '주의', 'danger': '위험', 'ban': '여행금지' };

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
        <div className="page-enter space-y-6">
            <PageHeader
                icon={Settings}
                iconBg="bg-slate-100"
                iconColor="text-slate-600"
                glowColor="bg-slate-400"
                title="System Settings"
                subtitle="국가 데이터, 비상 연락망, 약관 등 시스템 설정을 관리합니다."
            />
            {error && <ErrorMessage error={error} onRetry={fetchCountries} />}

            <div className="flex gap-2 p-1 bg-slate-100 rounded-xl w-fit">
                {['countries', 'emergency'].map(tab => (
                    <button key={tab} className={`px-4 py-2 text-sm font-bold rounded-lg transition-colors flex items-center gap-2 ${activeTab === tab ? 'bg-white shadow-sm text-slate-800' : 'text-slate-500 hover:text-slate-700'}`} onClick={() => setActiveTab(tab)}>
                        {tab === 'countries' ? <><Globe size={16} /> Countries & Alerts</> : <><Phone size={16} /> Emergency Numbers</>}
                    </button>
                ))}
            </div>

            {activeTab === 'countries' && (
                <div className="glass-panel rounded-2xl overflow-hidden">
                    <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-white/40">
                        <span className="font-bold text-slate-800">Country & MOFA Travel Alert Management</span>
                        <button className="flex items-center gap-2 bg-[#00A2BD]/10 text-[#00A2BD] hover:bg-[#00A2BD]/20 px-4 py-2 rounded-xl text-sm font-bold transition-colors" onClick={fetchCountries}><RefreshCw size={14} /> Sync MOFA API</button>
                    </div>
                    <div className="p-5">
                        <div className="flex gap-4 mb-4">
                            <input className="flex-1 h-11 px-4 rounded-xl border border-slate-200 bg-white shadow-sm focus:ring-[#00A2BD] focus:outline-none" placeholder="Search country..." value={searchQuery} onChange={e => setSearchQuery(e.target.value)} />
                            <select className="h-11 px-4 rounded-xl border border-slate-200 bg-white shadow-sm focus:ring-[#00A2BD] focus:outline-none"><option>All Alert Levels</option><option>Level 0</option><option>Level 1</option><option>Level 2</option><option>Level 3</option><option>Level 4</option></select>
                        </div>
                        {loading ? <LoadingSkeleton type="table" count={5} /> : filteredCountries.length === 0 ? (
                            <div className="py-12 flex flex-col items-center justify-center text-slate-400"><Globe size={48} className="mb-4 opacity-50" /><p>국가 데이터가 없습니다.</p></div>
                        ) : (
                            <div className="premium-table p-1">
                                <table className="w-full text-sm text-left">
                                    <thead><tr className="border-b border-slate-100 text-slate-500 font-bold uppercase text-[11px] tracking-wider"><th className="p-4">FLAG</th><th className="p-4">COUNTRY</th><th className="p-4">CODE</th><th className="p-4">MOFA ALERT</th><th className="p-4">PHONE CODE</th><th className="p-4">EMERGENCY #</th><th className="p-4">LAST UPDATED</th></tr></thead>
                                    <tbody>
                                        {filteredCountries.map(c => (
                                            <tr key={c.code} className="border-b border-slate-50 hover:bg-slate-50/50 transition-colors">
                                                <td className="p-4 text-xl">{c.flag}</td>
                                                <td className="p-4 font-bold text-slate-700">{c.name}</td>
                                                <td className="p-4 font-mono text-xs">{c.code}</td>
                                                <td className="p-4"><span className={`status-tag ${MOFA_BADGE[c.mofa] || 'status-tag-default'} uppercase`}>{MOFA_LABEL[c.mofa] || c.mofa}</span></td>
                                                <td className="p-4 text-slate-600">{c.phone}</td>
                                                <td className="p-4 font-bold text-[#00A2BD]">{c.emergency}</td>
                                                <td className="p-4 text-xs text-slate-500">{c.updated}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {activeTab === 'emergency' && (
                <div className="glass-panel rounded-2xl overflow-hidden">
                    <div className="p-5 border-b border-slate-100 flex items-center bg-white/40"><span className="font-bold text-slate-800 flex items-center gap-2"><Phone size={18} className="text-slate-500" /> Emergency Numbers by Country</span></div>
                    <div className="p-5">
                        {loading ? <LoadingSkeleton type="card" count={3} /> : countries.length === 0 ? (
                            <div className="py-12 flex flex-col items-center justify-center text-slate-400"><Phone size={48} className="mb-4 opacity-50" /><p>국가 데이터를 먼저 로드하세요.</p></div>
                        ) : (
                            <>
                                <div className="mb-4">
                                    <select className="h-11 px-4 rounded-xl border border-slate-200 bg-white shadow-sm focus:ring-[#00A2BD] focus:outline-none min-w-[200px]" onChange={e => { setSelectedCountry(e.target.value); if (e.target.value) fetchEmergencyNumbers(e.target.value); }} value={selectedCountry || ''}>
                                        <option value="">국가 선택...</option>
                                        {countries.map(c => <option key={c.code} value={c.code}>{c.name} ({c.code})</option>)}
                                    </select>
                                </div>
                                {emergencyLoading ? <LoadingSkeleton type="card" count={1} /> : emergencyData ? (
                                    <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl overflow-x-auto">
                                        <pre className="text-xs font-mono text-slate-600">{JSON.stringify(emergencyData, null, 2)}</pre>
                                    </div>
                                ) : selectedCountry ? (
                                    <div className="py-12 flex flex-col items-center justify-center text-slate-400"><p>비상 데이터를 불러올 수 없습니다.</p></div>
                                ) : null}
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}

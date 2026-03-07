'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { userService } from '@/services/userService';
import { tripService } from '@/services/tripService';
import { sosService } from '@/services/sosService';
import { paymentService } from '@/services/paymentService';
import { b2bService } from '@/services/b2bService';
import {
    BarChart3, Users, Plane, DollarSign, ShieldAlert, Building2,
    TrendingUp, TrendingDown, ArrowRight
} from 'lucide-react';
import {
    LineChart, Line, BarChart, Bar, AreaChart, Area,
    XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts';

import { PageHeader } from '@/components/PageHeader';

const TABS = [
    { id: 'users', label: 'Users', icon: Users },
    { id: 'trips', label: 'Trips', icon: Plane },
    { id: 'revenue', label: 'Revenue', icon: DollarSign },
    { id: 'sos', label: 'SOS', icon: ShieldAlert },
    { id: 'b2b', label: 'B2B', icon: Building2 },
];

// Mock analytics data
const MOCK_DATA: Record<string, any[]> = {
    users: [
        { day: 'Mon', value: 1120, prev: 980 }, { day: 'Tue', value: 1180, prev: 1050 },
        { day: 'Wed', value: 1050, prev: 1100 }, { day: 'Thu', value: 1210, prev: 1140 },
        { day: 'Fri', value: 1340, prev: 1200 }, { day: 'Sat', value: 980, prev: 920 },
        { day: 'Sun', value: 1234, prev: 1100 },
    ],
    trips: [
        { month: 'Jan', active: 45, completed: 120 }, { month: 'Feb', active: 52, completed: 135 },
        { month: 'Mar', active: 61, completed: 148 }, { month: 'Apr', active: 48, completed: 162 },
        { month: 'May', active: 55, completed: 175 }, { month: 'Jun', active: 70, completed: 190 },
    ],
    revenue: [
        { month: 'Jan', amount: 45000000 }, { month: 'Feb', amount: 52000000 },
        { month: 'Mar', amount: 61000000 }, { month: 'Apr', amount: 58000000 },
        { month: 'May', amount: 75000000 }, { month: 'Jun', amount: 82000000 },
    ],
    sos: [
        { month: 'Jan', events: 3, resolved: 3 }, { month: 'Feb', events: 5, resolved: 4 },
        { month: 'Mar', events: 2, resolved: 2 }, { month: 'Apr', events: 7, resolved: 6 },
        { month: 'May', events: 4, resolved: 4 }, { month: 'Jun', events: 1, resolved: 1 },
    ],
    b2b: [
        { month: 'Jan', partners: 5 }, { month: 'Feb', partners: 7 },
        { month: 'Mar', partners: 8 }, { month: 'Apr', partners: 10 },
        { month: 'May', partners: 12 }, { month: 'Jun', partners: 14 },
    ],
};

const KPI_DATA: Record<string, { label: string; value: string; change: string; up: boolean }[]> = {
    users: [
        { label: 'Total Users', value: '12,458', change: '+15%', up: true },
        { label: 'DAU', value: '1,234', change: '+8%', up: true },
        { label: 'MAU', value: '8,920', change: '+12%', up: true },
        { label: 'Churn Rate', value: '2.1%', change: '-0.3%', up: false },
    ],
    trips: [
        { label: 'Total Trips', value: '3,456', change: '+22%', up: true },
        { label: 'Active Trips', value: '61', change: '+5', up: true },
        { label: 'Avg Duration', value: '5.2 days', change: '+0.3', up: true },
        { label: 'Completion Rate', value: '94%', change: '+2%', up: true },
    ],
    revenue: [
        { label: 'Monthly Revenue', value: '₩8,200만', change: '+18%', up: true },
        { label: 'ARPU', value: '₩6,580', change: '+5%', up: true },
        { label: 'MRR Growth', value: '12%', change: '+2%', up: true },
        { label: 'Refund Rate', value: '1.2%', change: '-0.1%', up: false },
    ],
    sos: [
        { label: 'Total Events', value: '22', change: '-40%', up: false },
        { label: 'Avg Response', value: '4.2 min', change: '-1.1', up: false },
        { label: 'Resolution %', value: '96%', change: '+3%', up: true },
        { label: 'False Alarm %', value: '15%', change: '-5%', up: false },
    ],
    b2b: [
        { label: 'Partners', value: '14', change: '+3', up: true },
        { label: 'Active Contracts', value: '11', change: '+2', up: true },
        { label: 'B2B Revenue', value: '₩2,100만', change: '+25%', up: true },
        { label: 'Avg Contract', value: '₩190만', change: '+8%', up: true },
    ],
};

const TOOLTIP_STYLE = {
    borderRadius: 16, border: 'none', fontSize: 13, fontWeight: 600,
    background: 'rgba(255,255,255,0.95)', backdropFilter: 'blur(12px)',
    boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
};

export default function AnalyticsPage() {
    const [activeTab, setActiveTab] = useState('users');
    const data = MOCK_DATA[activeTab] || [];
    const kpis = KPI_DATA[activeTab] || [];

    const chartColors: Record<string, string[]> = {
        users: ['#00A2BD', '#94A3B8'],
        trips: ['#3B82F6', '#10B981'],
        revenue: ['#10B981'],
        sos: ['#EF4444', '#10B981'],
        b2b: ['#8B5CF6'],
    };

    return (
        <div className="page-enter space-y-7">
            <PageHeader
                icon={BarChart3}
                iconBg="bg-violet-50"
                iconColor="text-violet-600"
                glowColor="bg-violet-400"
                title="Analytics & Reports"
                subtitle="서비스 전반의 핵심 지표를 분석하고 인사이트를 도출합니다."
            />

            {/* Tab Navigation */}
            <div className="stagger-2 flex gap-2 overflow-x-auto pb-2">
                {TABS.map(tab => {
                    const Icon = tab.icon;
                    return (
                        <button
                            key={tab.id}
                            className={`flex items-center gap-2 px-5 py-3 rounded-xl text-sm font-bold transition-all whitespace-nowrap
                                ${activeTab === tab.id
                                    ? 'bg-gradient-to-r from-violet-500 to-indigo-600 text-white shadow-md shadow-violet-500/20'
                                    : 'bg-white/60 text-slate-600 hover:bg-white hover:shadow-sm border border-slate-100'
                                }`}
                            onClick={() => setActiveTab(tab.id)}
                        >
                            <Icon size={16} /> {tab.label}
                        </button>
                    );
                })}
            </div>

            {/* KPI Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                {kpis.map((kpi, i) => (
                    <div key={i} className={`stagger-${i + 3} hover-lift rounded-2xl p-5 border border-white/60`}
                        style={{ background: 'linear-gradient(145deg, rgba(255,255,255,0.95), rgba(248,250,252,0.85))', boxShadow: 'var(--elevation-1)' }}>
                        <p className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest">{kpi.label}</p>
                        <p className="text-2xl font-black text-slate-800 mt-2">{kpi.value}</p>
                        <div className={`flex items-center gap-1 mt-2 text-xs font-bold ${kpi.up ? 'text-emerald-600' : 'text-red-500'}`}>
                            {kpi.up ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
                            {kpi.change} vs last period
                        </div>
                    </div>
                ))}
            </div>

            {/* Main Chart */}
            <div className="stagger-7 rounded-2xl border border-white/60 overflow-hidden"
                style={{ background: 'linear-gradient(180deg, rgba(255,255,255,0.95), rgba(248,250,252,0.9))', boxShadow: 'var(--elevation-1)' }}>
                <div className="px-6 py-4 border-b border-slate-100/80">
                    <span className="heading-sm">Trend Analysis</span>
                </div>
                <div className="p-6" style={{ height: 380 }}>
                    <ResponsiveContainer width="100%" height="100%">
                        {activeTab === 'revenue' ? (
                            <AreaChart data={data}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.04)" />
                                <XAxis dataKey="month" tick={{ fontSize: 12, fill: '#94A3B8', fontWeight: 600 }} axisLine={false} tickLine={false} />
                                <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} tickFormatter={(v) => `₩${(v / 10000000).toFixed(0)}천만`} />
                                <Tooltip contentStyle={TOOLTIP_STYLE} formatter={(v: any) => [`₩${v.toLocaleString()}`, 'Revenue']} />
                                <defs>
                                    <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#10B981" stopOpacity={0.3} />
                                        <stop offset="95%" stopColor="#10B981" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <Area type="monotone" dataKey="amount" stroke="#10B981" strokeWidth={3} fill="url(#areaGrad)" dot={{ fill: '#10B981', r: 4, strokeWidth: 2, stroke: '#fff' }} />
                            </AreaChart>
                        ) : activeTab === 'trips' || activeTab === 'sos' ? (
                            <BarChart data={data}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.04)" />
                                <XAxis dataKey="month" tick={{ fontSize: 12, fill: '#94A3B8', fontWeight: 600 }} axisLine={false} tickLine={false} />
                                <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                                <Tooltip contentStyle={TOOLTIP_STYLE} />
                                <Legend />
                                {Object.keys(data[0] || {}).filter(k => k !== 'month').map((key, idx) => (
                                    <Bar key={key} dataKey={key} radius={[8, 8, 2, 2]} fill={chartColors[activeTab]?.[idx] || '#94A3B8'} />
                                ))}
                            </BarChart>
                        ) : (
                            <LineChart data={data}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.04)" />
                                <XAxis dataKey={Object.keys(data[0] || {})[0]} tick={{ fontSize: 12, fill: '#94A3B8', fontWeight: 600 }} axisLine={false} tickLine={false} />
                                <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                                <Tooltip contentStyle={TOOLTIP_STYLE} />
                                <Legend />
                                {Object.keys(data[0] || {}).filter(k => k !== 'day' && k !== 'month').map((key, idx) => (
                                    <Line key={key} type="monotone" dataKey={key} stroke={chartColors[activeTab]?.[idx] || '#94A3B8'} strokeWidth={3} dot={{ r: 4, strokeWidth: 2, stroke: '#fff' }} />
                                ))}
                            </LineChart>
                        )}
                    </ResponsiveContainer>
                </div>
            </div>
        </div>
    );
}

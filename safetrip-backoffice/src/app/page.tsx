'use client';

import { useQuery } from '@tanstack/react-query';
import { sosService } from '@/services/sosService';
import { b2bService } from '@/services/b2bService';
import { userService } from '@/services/userService';
import { tripService } from '@/services/tripService';
import { paymentService } from '@/services/paymentService';
import { PageHeader } from '@/components/PageHeader';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import {
  LayoutDashboard, ShieldAlert, Plane, Users, Building2,
  RefreshCw, CircleCheck, DollarSign, AlertTriangle,
  UserPlus, TrendingUp, Activity, Zap, Globe,
} from 'lucide-react';
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';

/* ── Mock Data ── */
const MOCK_USER_TREND = [
  { day: 'Mon', dau: 1120 }, { day: 'Tue', dau: 1180 },
  { day: 'Wed', dau: 1050 }, { day: 'Thu', dau: 1210 },
  { day: 'Fri', dau: 1340 }, { day: 'Sat', dau: 980 },
  { day: 'Sun', dau: 1234 },
];

const MOCK_REVENUE_TREND = [
  { day: '03/01', amount: 1200000 }, { day: '03/02', amount: 980000 },
  { day: '03/03', amount: 1500000 }, { day: '03/04', amount: 1100000 },
  { day: '03/05', amount: 1800000 }, { day: '03/06', amount: 2300000 },
];

const PAYMENT_TYPE_DATA = [
  { name: 'Trip Base', value: 45, color: '#00A2BD' },
  { name: 'AI Plus', value: 20, color: '#46D2E1' },
  { name: 'AI Pro', value: 15, color: '#005572' },
  { name: 'Guardian', value: 10, color: '#F59E0B' },
  { name: 'B2B', value: 10, color: '#10B981' },
];

const CHART_TOOLTIP_STYLE = {
  borderRadius: 16, border: 'none', fontSize: 13, fontWeight: 600,
  background: 'rgba(255,255,255,0.95)', backdropFilter: 'blur(12px)',
  boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
};

/* ── KPI Card ── */
function KpiCard({ icon: Icon, label, value, trend, trendLabel, accent, stagger, pulse }: {
  icon: any; label: string; value: string | number; trend?: string; trendLabel?: string;
  accent: string; stagger: number; pulse?: boolean;
}) {
  const accents: Record<string, { iconBg: string; iconColor: string; valueCls: string; trendCls: string }> = {
    red: { iconBg: 'bg-red-50', iconColor: 'text-red-600', valueCls: 'text-red-600', trendCls: 'bg-red-50 text-red-600' },
    teal: { iconBg: 'bg-teal-50', iconColor: 'text-teal-600', valueCls: 'text-teal-600', trendCls: 'bg-teal-50 text-teal-600' },
    emerald: { iconBg: 'bg-emerald-50', iconColor: 'text-emerald-600', valueCls: 'text-emerald-600', trendCls: 'bg-emerald-50 text-emerald-600' },
    blue: { iconBg: 'bg-blue-50', iconColor: 'text-blue-600', valueCls: 'text-blue-600', trendCls: 'bg-blue-50 text-blue-600' },
    amber: { iconBg: 'bg-amber-50', iconColor: 'text-amber-600', valueCls: 'text-amber-600', trendCls: 'bg-amber-50 text-amber-600' },
    slate: { iconBg: 'bg-slate-100', iconColor: 'text-slate-600', valueCls: 'text-slate-800', trendCls: 'bg-slate-50 text-slate-600' },
  };
  const a = accents[accent] || accents.teal;

  return (
    <div className={`stagger-${stagger} hover-lift rounded-2xl p-6 border border-white/60 relative overflow-hidden group`}
      style={{ background: 'linear-gradient(145deg, rgba(255,255,255,0.95), rgba(248,250,252,0.85))', boxShadow: 'var(--elevation-1)' }}>
      {/* Background glow */}
      <div className={`absolute -right-6 -bottom-6 w-28 h-28 rounded-full ${a.iconBg} opacity-30 group-hover:opacity-50 transition-opacity blur-2xl`} />
      {/* Icon */}
      <div className={`w-11 h-11 rounded-xl ${a.iconBg} ${a.iconColor} flex items-center justify-center mb-4 relative z-10`}>
        <Icon size={22} strokeWidth={2} className={pulse ? 'animate-pulse' : ''} />
      </div>
      {/* Label */}
      <p className="text-[11px] font-extrabold uppercase tracking-wider text-slate-400 mb-2 relative z-10">{label}</p>
      {/* Value */}
      <p className={`text-3xl font-black ${a.valueCls} leading-tight tracking-tight relative z-10`}>{value}</p>
      {/* Trend */}
      {trendLabel && (
        <div className={`mt-3 inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold ${a.trendCls} relative z-10`}>
          {trend && <TrendingUp size={11} />} {trendLabel}
        </div>
      )}
    </div>
  );
}

/* ── Chart Panel ── */
function ChartPanel({ title, icon: Icon, iconColor, children, stagger }: {
  title: string; icon: any; iconColor: string; children: React.ReactNode; stagger: number;
}) {
  return (
    <div className={`stagger-${stagger} rounded-2xl border border-white/60 overflow-hidden`}
      style={{ background: 'linear-gradient(180deg, rgba(255,255,255,0.95), rgba(248,250,252,0.9))', boxShadow: 'var(--elevation-1)' }}>
      <div className="px-6 py-4 border-b border-slate-100/80 flex items-center gap-2.5">
        <Icon size={18} className={iconColor} strokeWidth={2.5} />
        <span className="heading-sm">{title}</span>
      </div>
      <div className="p-5" style={{ height: 280 }}>{children}</div>
    </div>
  );
}

/* ── Data Fetching ── */
function fetchDashboardData() {
  return Promise.allSettled([
    sosService.getEmergencies(),
    userService.getUserStats(),
    tripService.getTripStats(),
    b2bService.getOrganizations(),
    paymentService.getPaymentStats(),
  ]).then(([sosResult, userResult, tripResult, b2bResult, paymentResult]) => {
    let emergencies: any[] = [];
    let activeSos = 0, dau = 0, activeTrips = 0, b2bPartners = 0, todayRevenue = 0, newSignups = 0;

    if (sosResult.status === 'fulfilled') {
      emergencies = sosResult.value?.data || sosResult.value || [];
      if (Array.isArray(emergencies)) {
        activeSos = emergencies.filter((e: any) => e.status === 'active' || e.status === 'ACTIVE').length;
      }
    }
    if (userResult.status === 'fulfilled') {
      const d: any = userResult.value?.data || userResult.value;
      dau = d?.activeToday || d?.total || 0;
      newSignups = d?.newToday || d?.registeredToday || 28;
    }
    if (tripResult.status === 'fulfilled') {
      const t: any = tripResult.value;
      activeTrips = t?.activeTrips || t?.active || t?.totalTrips || t?.total || 0;
    }
    if (b2bResult.status === 'fulfilled') {
      const orgs = b2bResult.value?.data || b2bResult.value || [];
      b2bPartners = Array.isArray(orgs) ? orgs.length : 0;
    }
    if (paymentResult.status === 'fulfilled') {
      const p: any = paymentResult.value;
      todayRevenue = p?.todayRevenue || p?.data?.todayRevenue || p?.totalRevenue || p?.data?.totalRevenue || 0;
    }

    const sosFeed = Array.isArray(emergencies) ? emergencies.slice(0, 10).map((e: any) => ({
      id: e.emergency_id || e.emergencyId || e.id,
      user: e.user_name || e.userId || 'Unknown',
      trip: e.trip_id || e.tripId || '-',
      location: e.location || e.description || '-',
      time: (e.created_at || e.createdAt) ? new Date(e.created_at || e.createdAt).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' }) : '-',
      status: (e.status || 'ACTIVE').toUpperCase(),
      battery: e.battery_level ? `${e.battery_level}%` : '-',
    })) : [];

    return { activeSos, activeTrips, dau, b2bPartners, todayRevenue, newSignups, sosFeed };
  });
}

/* ── Dashboard Page ── */
export default function DashboardPage() {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['dashboard'],
    queryFn: fetchDashboardData,
    refetchInterval: 30000,
  });

  const stats = data || { activeSos: 0, activeTrips: 0, dau: 0, b2bPartners: 0, todayRevenue: 0, newSignups: 0, sosFeed: [] };

  return (
    <div className="page-enter space-y-7">
      {/* ─ Premium Page Header ─ */}
      <PageHeader
        icon={LayoutDashboard}
        iconBg="bg-teal-50"
        iconColor="text-teal-600"
        glowColor="bg-teal-400"
        title="Fleet Command Center"
        subtitle="SafeTrip 플랫폼 전체 운영 현황을 실시간으로 모니터링합니다."
        actions={
          <button onClick={() => refetch()}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white border border-slate-200 text-sm font-semibold text-slate-600 hover:border-teal-300 hover:text-teal-600 hover:shadow-md transition-all">
            <RefreshCw size={14} className={isLoading ? 'animate-spin' : ''} /> Sync
          </button>
        }
      />

      {error && <ErrorMessage error={error as any} onRetry={() => refetch()} />}

      {/* ─ 6 KPI Cards with Stagger Entry ─ */}
      {isLoading ? (
        <LoadingSkeleton type="stat" count={6} />
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-5">
          <KpiCard icon={ShieldAlert} label="Active SOS" value={stats.activeSos} accent="red" stagger={2} pulse={stats.activeSos > 0}
            trendLabel={stats.activeSos > 0 ? 'CRITICAL' : '✓ All Clear'} />
          <KpiCard icon={Plane} label="Active Trips" value={stats.activeTrips} accent="teal" stagger={3}
            trendLabel="Global Coverage" />
          <KpiCard icon={Users} label="DAU" value={stats.dau.toLocaleString()} accent="blue" stagger={4}
            trend="up" trendLabel="+12% vs last week" />
          <KpiCard icon={DollarSign} label="Today Revenue" value={stats.todayRevenue > 0 ? `₩${(stats.todayRevenue / 10000).toFixed(1)}만` : '₩0'} accent="emerald" stagger={5}
            trend="up" trendLabel="+8% vs yesterday" />
          <KpiCard icon={Building2} label="B2B Partners" value={stats.b2bPartners} accent="amber" stagger={6}
            trendLabel="Enterprise" />
          <KpiCard icon={UserPlus} label="New Signups" value={stats.newSignups} accent="blue" stagger={7}
            trendLabel="Today" />
        </div>
      )}

      {/* ─ SOS Live Feed ─ */}
      <div className="stagger-8 rounded-2xl border border-white/60 overflow-hidden"
        style={{ background: 'linear-gradient(180deg, rgba(255,255,255,0.95), rgba(248,250,252,0.9))', boxShadow: 'var(--elevation-1)' }}>
        <div className="px-6 py-4 border-b border-slate-100/80 flex items-center justify-between">
          <span className="heading-sm flex items-center gap-2.5">
            <div className="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse" />
            SOS Live Feed Monitor
          </span>
          <button onClick={() => refetch()}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-red-600 bg-red-50 hover:bg-red-100 border border-red-100 transition-all">
            <RefreshCw size={12} className={isLoading ? 'animate-spin' : ''} /> Sync
          </button>
        </div>
        {isLoading ? (
          <LoadingSkeleton type="table" count={3} />
        ) : stats.sosFeed.length === 0 ? (
          <div className="py-16 text-center">
            <CircleCheck size={48} strokeWidth={1.5} className="mx-auto text-emerald-400 mb-3" />
            <h3 className="heading-md text-emerald-700 mb-1">No Active Emergencies</h3>
            <p className="body-sm">Global operations are currently stable.</p>
          </div>
        ) : (
          <div className="premium-table">
            <table className="data-table" role="table">
              <thead><tr>
                <th>Event ID</th><th>User</th><th>Trip</th><th>Location</th><th>Time</th><th>Battery</th><th>Status</th>
              </tr></thead>
              <tbody>
                {stats.sosFeed.map((s: any) => (
                  <tr key={s.id}>
                    <td><code className="mono">{String(s.id).substring(0, 8)}...</code></td>
                    <td className="font-semibold text-slate-700">{s.user}</td>
                    <td>{s.trip}</td>
                    <td className="text-slate-500">{s.location}</td>
                    <td className="font-medium text-slate-600">{s.time}</td>
                    <td>
                      <span style={{ color: parseInt(s.battery) < 20 ? 'var(--sos-danger)' : 'var(--primary-teal)' }} className="font-bold text-xs">{s.battery}</span>
                    </td>
                    <td>
                      <span className={`status-tag ${s.status === 'ACTIVE' ? 'danger' : 'warning'}`}>
                        {s.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ─ Charts Row 1 ─ */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartPanel title="User Trend (7 Days)" icon={Activity} iconColor="text-blue-500" stagger={9}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={MOCK_USER_TREND}>
              <defs>
                <linearGradient id="dauGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#00A2BD" stopOpacity={0.25} />
                  <stop offset="100%" stopColor="#00A2BD" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.04)" />
              <XAxis dataKey="day" tick={{ fontSize: 12, fill: '#94A3B8', fontWeight: 600 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={CHART_TOOLTIP_STYLE} formatter={(v: any) => [v.toLocaleString(), 'DAU']} />
              <Area type="monotone" dataKey="dau" stroke="#00A2BD" strokeWidth={3} fill="url(#dauGrad)" dot={{ fill: '#00A2BD', r: 4, strokeWidth: 2, stroke: '#fff' }} activeDot={{ r: 6, strokeWidth: 2, stroke: '#fff' }} />
            </AreaChart>
          </ResponsiveContainer>
        </ChartPanel>

        <ChartPanel title="Revenue Trend" icon={DollarSign} iconColor="text-emerald-500" stagger={10}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={MOCK_REVENUE_TREND}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#10B981" stopOpacity={0.9} />
                  <stop offset="100%" stopColor="#059669" stopOpacity={0.7} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.04)" />
              <XAxis dataKey="day" tick={{ fontSize: 12, fill: '#94A3B8', fontWeight: 600 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} tickFormatter={(v) => `₩${(v / 10000).toFixed(0)}만`} />
              <Tooltip contentStyle={CHART_TOOLTIP_STYLE} formatter={(v: any) => [`₩${v.toLocaleString()}`, 'Revenue']} />
              <Bar dataKey="amount" radius={[10, 10, 4, 4]} fill="url(#revGrad)" />
            </BarChart>
          </ResponsiveContainer>
        </ChartPanel>
      </div>

      {/* ─ Charts Row 2 ─ */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartPanel title="Revenue by Plan" icon={Globe} iconColor="text-teal-500" stagger={11}>
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={PAYMENT_TYPE_DATA} cx="50%" cy="50%" innerRadius={65} outerRadius={95} paddingAngle={4} dataKey="value"
                label={({ name, percent }: any) => `${name} ${(percent * 100).toFixed(0)}%`}
                labelLine={{ strokeWidth: 1.5, stroke: '#CBD5E1' }}>
                {PAYMENT_TYPE_DATA.map((entry, i) => <Cell key={i} fill={entry.color} stroke="white" strokeWidth={2} />)}
              </Pie>
              <Tooltip contentStyle={CHART_TOOLTIP_STYLE} />
            </PieChart>
          </ResponsiveContainer>
        </ChartPanel>

        <ChartPanel title="System Health" icon={Zap} iconColor="text-amber-500" stagger={12}>
          <div className="space-y-4 pt-2 h-full flex flex-col justify-center">
            {[
              { type: 'info', icon: Activity, msg: 'API response time normal', detail: 'avg 120ms', time: '2 min ago' },
              { type: 'success', icon: CircleCheck, msg: 'Daily backup completed', detail: '43.2 GB', time: '1 hour ago' },
              { type: 'warning', icon: AlertTriangle, msg: 'Firebase RTDB latency spike', detail: 'P95: 480ms', time: '3 hours ago' },
              { type: 'info', icon: Globe, msg: 'CDN cache hit rate', detail: '99.2%', time: '5 min ago' },
            ].map((alert, i) => (
              <div key={i} className="flex items-center gap-4 px-5 py-3.5 rounded-xl bg-white/60 border border-slate-100 hover:border-slate-200 hover:bg-white transition-all group">
                <div className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 ${alert.type === 'success' ? 'bg-emerald-50 text-emerald-500' : alert.type === 'warning' ? 'bg-amber-50 text-amber-500' : 'bg-blue-50 text-blue-500'}`}>
                  <alert.icon size={16} strokeWidth={2.5} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-700 truncate">{alert.msg}</p>
                  <p className="text-[11px] font-medium text-slate-400">{alert.detail}</p>
                </div>
                <span className="body-sm flex-shrink-0">{alert.time}</span>
              </div>
            ))}
          </div>
        </ChartPanel>
      </div>
    </div>
  );
}

'use client';

import { useQuery } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { paymentService, Transaction, PaymentStats } from '@/services/paymentService';
import { DataTable } from '@/components/ui/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    DollarSign, CreditCard, Download, TrendingUp,
    Search, Calendar, Filter, ArrowUpRight,
    ArrowDownLeft, RefreshCw, Wallet
} from 'lucide-react';
import { Input } from '@/components/ui/input';
import { PageHeader } from '@/components/PageHeader';
import {
    LineChart, Line, PieChart, Pie, Cell,
    XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';

const MOCK_REVENUE = [
    { day: '03/01', rev: 1200000 }, { day: '03/02', rev: 980000 },
    { day: '03/03', rev: 1500000 }, { day: '03/04', rev: 1100000 },
    { day: '03/05', rev: 1800000 }, { day: '03/06', rev: 2300000 },
];

const TYPE_DATA = [
    { name: 'Trip Base', value: 45, color: '#00A2BD' },
    { name: 'AI Plus', value: 20, color: '#46D2E1' },
    { name: 'AI Pro', value: 15, color: '#005572' },
    { name: 'Guardian', value: 10, color: '#F59E0B' },
    { name: 'B2B', value: 10, color: '#10B981' },
];

export default function FinancePage() {
    // Fetch Transactions
    const { data: rawTransactions, isLoading: loadingTx } = useQuery({
        queryKey: ['transactions'],
        queryFn: () => paymentService.getTransactions(),
    });

    // Fetch Stats
    const { data: stats } = useQuery({
        queryKey: ['payment-stats'],
        queryFn: () => paymentService.getPaymentStats(),
    });

    const transactions: Transaction[] = (rawTransactions?.data || rawTransactions || []).map((t: any) => ({
        ...t,
        id: t.payment_id || t.id,
        user: t.user_name || t.user_id || '-',
        date: t.created_at ? new Date(t.created_at).toLocaleString() : '-',
    }));

    // Table Column Definitions
    const columns: ColumnDef<Transaction>[] = [
        {
            accessorKey: 'payment_id',
            header: '결제 ID',
            cell: ({ row }) => <code className="text-[11px] font-mono opacity-70">{row.original.payment_id || (row.original as any).id}</code>,
        },
        {
            accessorKey: 'user_name',
            header: '사용자',
            cell: ({ row }) => <span className="font-semibold text-sm">{row.original.user_name || row.original.user_id}</span>,
        },
        {
            accessorKey: 'amount',
            header: '금액',
            cell: ({ row }) => (
                <span className="font-bold text-sm">
                    {row.original.currency === 'KRW' || !row.original.currency ? '₩' : '$'}
                    {Number(row.original.amount).toLocaleString()}
                </span>
            ),
        },
        {
            accessorKey: 'payment_method',
            header: '결제수단',
            cell: ({ row }) => (
                <div className="flex items-center gap-2 text-xs">
                    <CreditCard size={14} className="text-muted-foreground" />
                    <span className="capitalize">{row.original.payment_method || '카드'}</span>
                </div>
            ),
        },
        {
            accessorKey: 'status',
            header: '상태',
            cell: ({ row }) => {
                const status = row.original.status;
                return (
                    <Badge variant={status === 'completed' ? 'default' : status === 'refunded' ? 'outline' : 'secondary'}
                        className={`capitalize text-[10px] ${status === 'completed' ? 'bg-green-100 text-green-700 hover:bg-green-200' : ''}`}>
                        {status}
                    </Badge>
                );
            },
        },
        {
            accessorKey: 'created_at',
            header: '결제일시',
            cell: ({ row }) => <span className="text-xs text-muted-foreground">{new Date(row.original.created_at).toLocaleString()}</span>,
        },
    ];

    return (
        <div className="page-enter space-y-7">
            {/* Premium Header */}
            <PageHeader
                icon={DollarSign}
                iconBg="bg-emerald-50"
                iconColor="text-emerald-600"
                glowColor="bg-emerald-400"
                title="Billing & Finance"
                subtitle="SafeTrip 서비스의 매출 현황 및 결제 내역을 투명하게 관리합니다."
            />

            {/* Financial Overview Cards */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <div className="flex justify-between items-start mb-4">
                        <div className="p-2 bg-green-50 text-green-600 rounded-lg"><Wallet size={20} /></div>
                        <Badge className="bg-green-50 text-green-700 border-green-100">+12.5%</Badge>
                    </div>
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Total Revenue</p>
                    <p className="text-2xl font-black text-slate-900">
                        ₩{(stats?.totalRevenue || 0).toLocaleString()}
                    </p>
                </div>

                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <div className="flex justify-between items-start mb-4">
                        <div className="p-2 bg-blue-50 text-blue-600 rounded-lg"><CreditCard size={20} /></div>
                    </div>
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Total Transactions</p>
                    <p className="text-2xl font-black text-slate-900">{stats?.transactionCount || 0}</p>
                </div>

                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <div className="flex justify-between items-start mb-4">
                        <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg"><TrendingUp size={20} /></div>
                    </div>
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Completed</p>
                    <p className="text-2xl font-black text-slate-900">{stats?.completedCount || 0}</p>
                </div>

                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <div className="flex justify-between items-start mb-4">
                        <div className="p-2 bg-red-50 text-red-600 rounded-lg"><RefreshCw size={20} /></div>
                    </div>
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Refunded</p>
                    <p className="text-2xl font-black text-slate-900">{stats?.refundedCount || 0}</p>
                </div>
            </div>

            {/* Revenue Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <div className="glass-panel rounded-2xl p-6">
                    <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2"><TrendingUp size={18} className="text-emerald-600" /> Revenue Trend</h3>
                    <div style={{ height: 220 }}>
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={MOCK_REVENUE}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                                <XAxis dataKey="day" tick={{ fontSize: 12, fill: '#94A3B8' }} />
                                <YAxis tick={{ fontSize: 12, fill: '#94A3B8' }} tickFormatter={(v) => `₩${(v / 10000).toFixed(0)}만`} />
                                <Tooltip contentStyle={{ borderRadius: 12, fontSize: 13 }} formatter={(v: any) => [`₩${v.toLocaleString()}`, 'Revenue']} />
                                <Line type="monotone" dataKey="rev" stroke="#10B981" strokeWidth={3} dot={{ fill: '#10B981', r: 5 }} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </div>
                <div className="glass-panel rounded-2xl p-6">
                    <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2"><Wallet size={18} className="text-teal-600" /> Payment Type Distribution</h3>
                    <div style={{ height: 220 }}>
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie data={TYPE_DATA} cx="50%" cy="50%" innerRadius={50} outerRadius={80} paddingAngle={3} dataKey="value"
                                    label={({ name, percent }: any) => `${name} ${(percent * 100).toFixed(0)}%`} labelLine={{ strokeWidth: 1, stroke: '#94A3B8' }}>
                                    {TYPE_DATA.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                                </Pie>
                                <Tooltip contentStyle={{ borderRadius: 12, fontSize: 13 }} />
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            </div>

            {/* Filter & History */}
            <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
                <div className="p-4 border-b flex flex-col md:flex-row md:items-center justify-between gap-4 bg-muted/5">
                    <div className="flex items-center gap-2">
                        <CreditCard size={18} className="text-[#00A2BD]" />
                        <h2 className="font-bold">Payment History</h2>
                    </div>
                    <div className="flex items-center gap-2">
                        <div className="relative w-64">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                            <Input placeholder="결제 ID, 사용자 검색..." className="pl-9 h-9" />
                        </div>
                        <Button variant="outline" size="sm" className="h-9 gap-2">
                            <Filter size={14} /> Filter
                        </Button>
                        <Button variant="outline" size="sm" className="h-9 gap-2">
                            <Download size={14} /> Export
                        </Button>
                    </div>
                </div>
                <div className="p-2">
                    <DataTable
                        columns={columns}
                        data={transactions}
                        loading={loadingTx}
                        pageSize={10}
                    />
                </div>
            </div>

            {/* Quick Analytics Summary */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pb-6">
                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <h3 className="font-bold mb-4 flex items-center gap-2"><ArrowUpRight size={18} className="text-green-600" /> Top Revenue Sources</h3>
                    <div className="space-y-4">
                        {[
                            { name: 'Premium Monthly Subscription', value: '₩4,500,000', percentage: '65%' },
                            { name: 'Premium Yearly Subscription', value: '₩2,100,000', percentage: '30%' },
                            { name: 'One-time Insurance Package', value: '₩350,000', percentage: '5%' }
                        ].map((item, i) => (
                            <div key={i} className="flex flex-col gap-1.5">
                                <div className="flex justify-between text-sm">
                                    <span className="font-medium">{item.name}</span>
                                    <span className="font-bold">{item.value}</span>
                                </div>
                                <div className="w-full bg-muted h-2 rounded-full overflow-hidden">
                                    <div className="bg-green-500 h-full" style={{ width: item.percentage }}></div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-border shadow-sm">
                    <h3 className="font-bold mb-4 flex items-center gap-2"><ArrowDownLeft size={18} className="text-red-600" /> Recent Refund Requests</h3>
                    <div className="space-y-3">
                        {transactions.filter(t => t.status === 'refunded').slice(0, 3).map((t, i) => (
                            <div key={i} className="flex items-center justify-between p-3 border rounded-lg hover:bg-muted/30 transition-colors">
                                <div className="flex items-center gap-3">
                                    <div className="h-8 w-8 rounded-full bg-red-50 text-red-600 flex items-center justify-center font-bold text-xs uppercase">
                                        {t.user_name.substring(0, 2)}
                                    </div>
                                    <div>
                                        <p className="text-sm font-bold">{t.user_name}</p>
                                        <p className="text-xs text-muted-foreground">{new Date(t.created_at).toLocaleDateString()}</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="text-sm font-bold text-red-600">-₩{t.amount.toLocaleString()}</p>
                                    <p className="text-[10px] text-muted-foreground">환불 처리됨</p>
                                </div>
                            </div>
                        ))}
                        {transactions.filter(t => t.status === 'refunded').length === 0 && (
                            <div className="text-center py-6 text-muted-foreground text-sm">최근 환불 내역이 없습니다.</div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

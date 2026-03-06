'use client';

import { useState, useEffect } from 'react';
import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import { DollarSign, CreditCard, Download, TrendingUp, Search } from 'lucide-react';

export default function FinancePage() {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [payments, setPayments] = useState([]);

    async function fetchPayments() {
        setLoading(true);
        setError(null);
        try {
            const res = await api.get(API.PAYMENTS.ADMIN_TRANSACTIONS);
            const paymentData = res?.data || res?.payments || res || [];
            if (Array.isArray(paymentData)) {
                setPayments(paymentData.map(p => ({
                    id: p.payment_id || p.id,
                    user: p.user_name || p.user_id || '-',
                    amount: p.amount ? `₩${Number(p.amount).toLocaleString()}` : '-',
                    method: p.payment_method || '-',
                    status: p.status || 'completed',
                    date: p.created_at ? new Date(p.created_at).toISOString().split('T')[0] : '-',
                })));
            }
        } catch (err) {
            setError(err);
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => { fetchPayments(); }, []);

    const totalRevenue = payments.reduce((sum, p) => {
        const amt = parseInt(String(p.amount).replace(/[^0-9]/g, '')) || 0;
        return sum + amt;
    }, 0);
    const completedPayments = payments.filter(p => p.status === 'completed').length;

    return (
        <div className="slide-in">
            <h1 className="page-title"><DollarSign size={24} strokeWidth={2} /> Billing & Finance</h1>
            <p className="page-subtitle">결제 내역 및 매출을 관리합니다.</p>
            {error && <ErrorMessage error={error} onRetry={fetchPayments} />}

            {loading ? <LoadingSkeleton type="stat" count={4} /> : (
                <div className="dashboard-grid">
                    <div className="stat-card teal"><div className="stat-title"><DollarSign size={16} /> TOTAL REVENUE</div><div className="stat-value teal">₩{totalRevenue.toLocaleString()}</div></div>
                    <div className="stat-card success"><div className="stat-title"><CreditCard size={16} /> TRANSACTIONS</div><div className="stat-value success">{payments.length}</div></div>
                    <div className="stat-card amber"><div className="stat-title"><TrendingUp size={16} /> COMPLETED</div><div className="stat-value">{completedPayments}</div></div>
                    <div className="stat-card"><div className="stat-title">REFUNDED</div><div className="stat-value">{payments.filter(p => p.status === 'refunded').length}</div></div>
                </div>
            )}

            <div className="panel">
                <div className="panel-header"><span>Payment History</span><button className="btn btn-outline"><Download size={14} /> Export CSV</button></div>
                {loading ? <LoadingSkeleton type="table" count={5} /> : payments.length === 0 ? (
                    <div className="empty-state"><div className="empty-state-icon"><CreditCard size={48} strokeWidth={1.5} /></div><p>결제 데이터가 없습니다.</p></div>
                ) : (
                    <table className="data-table">
                        <thead><tr><th>ID</th><th>User</th><th>Amount</th><th>Method</th><th>Status</th><th>Date</th></tr></thead>
                        <tbody>
                            {payments.map(p => (
                                <tr key={p.id}>
                                    <td style={{ fontFamily: 'monospace', fontSize: '13px' }}>{p.id}</td>
                                    <td>{p.user}</td>
                                    <td style={{ fontWeight: 600 }}>{p.amount}</td>
                                    <td>{p.method}</td>
                                    <td><span className={`badge ${p.status === 'completed' ? 'success' : p.status === 'refunded' ? 'warning' : 'neutral'}`}>{p.status}</span></td>
                                    <td>{p.date}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}

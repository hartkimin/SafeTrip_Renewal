'use client';

import { useState, useEffect } from 'react';
import { sosService } from '@/services/sosService';
import { b2bService } from '@/services/b2bService';
import { userService } from '@/services/userService';
import { tripService } from '@/services/tripService';
import { LoadingSkeleton } from '@/components/LoadingSkeleton';
import { ErrorMessage } from '@/components/ErrorBoundary';
import {
  LayoutDashboard, ShieldAlert, Plane, Users, Building2,
  RefreshCw, CircleCheck, DollarSign, AlertTriangle,
} from 'lucide-react';

export default function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [stats, setStats] = useState({ activeSos: 0, activeTrips: 0, dau: 0, b2bPartners: 0 });
  const [sosFeed, setSosFeed] = useState([]);

  async function fetchDashboardData() {
    setLoading(true);
    setError(null);
    let activeSos = 0, activeTrips = 0, dau = 0, b2bPartners = 0;
    let emergencies = [];

    const fetchers = [
      sosService.getEmergencies().then(res => {
        emergencies = res?.data || res || [];
        activeSos = Array.isArray(emergencies) ? emergencies.filter(e => e.status === 'active' || e.status === 'ACTIVE').length : 0;
      }).catch(err => console.warn('[Dashboard] SOS fetch failed:', err.message)),

      userService.getUserStats().then(res => {
        dau = res?.data?.activeToday || res?.data?.total || 0;
      }).catch(err => console.warn('[Dashboard] User stats failed:', err.message)),

      tripService.getTripStats().then(res => {
        activeTrips = res?.data?.active || res?.data?.total || 0;
      }).catch(err => console.warn('[Dashboard] Trip stats failed:', err.message)),

      b2bService.getOrganizations().then(res => {
        const orgs = res?.data || res || [];
        b2bPartners = Array.isArray(orgs) ? orgs.length : 0;
      }).catch(err => console.warn('[Dashboard] B2B fetch failed:', err.message)),
    ];

    await Promise.allSettled(fetchers);
    setStats({ activeSos, activeTrips, dau, b2bPartners });

    if (Array.isArray(emergencies)) {
      setSosFeed(emergencies.slice(0, 10).map(e => ({
        id: e.emergency_id || e.emergencyId || e.id,
        user: e.user_name || e.userId || 'Unknown',
        trip: e.trip_id || e.tripId || '-',
        location: e.location || e.description || '-',
        time: (e.created_at || e.createdAt) ? new Date(e.created_at || e.createdAt).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' }) : '-',
        status: (e.status || 'ACTIVE').toUpperCase(),
        battery: e.battery_level ? `${e.battery_level}%` : '-',
      })));
    }
    setLoading(false);
  }

  useEffect(() => { fetchDashboardData(); }, []);

  return (
    <div className="slide-in">
      <h1 className="page-title"><LayoutDashboard size={24} strokeWidth={2} /> Dashboard</h1>
      <p className="page-subtitle">SafeTrip 관리 현황 한눈에 보기</p>

      {error && <ErrorMessage error={error} onRetry={fetchDashboardData} />}

      {loading ? (
        <LoadingSkeleton type="stat" count={4} />
      ) : (
        <div className="dashboard-grid">
          <div className="stat-card alert">
            <div className="stat-title"><ShieldAlert size={16} /> ACTIVE SOS</div>
            <div className="stat-value danger">{stats.activeSos}</div>
            {stats.activeSos > 0 && <div className="stat-change down">즉시 대응 필요</div>}
          </div>
          <div className="stat-card teal">
            <div className="stat-title"><Plane size={16} /> ACTIVE TRIPS</div>
            <div className="stat-value teal">{stats.activeTrips}</div>
          </div>
          <div className="stat-card success">
            <div className="stat-title"><Users size={16} /> DAU</div>
            <div className="stat-value">{stats.dau.toLocaleString()}</div>
          </div>
          <div className="stat-card amber">
            <div className="stat-title"><Building2 size={16} /> B2B PARTNERS</div>
            <div className="stat-value">{stats.b2bPartners}</div>
          </div>
        </div>
      )}

      {/* SOS Live Feed */}
      <div className="panel">
        <div className="panel-header">
          <span><ShieldAlert size={18} /> SOS Live Feed</span>
          <button className="btn btn-danger" onClick={fetchDashboardData}><RefreshCw size={14} /> Refresh</button>
        </div>
        {loading ? (
          <LoadingSkeleton type="table" count={3} />
        ) : sosFeed.length === 0 ? (
          <div className="empty-state"><div className="empty-state-icon"><CircleCheck size={48} strokeWidth={1.5} /></div><p>현재 활성 SOS 이벤트가 없습니다.</p></div>
        ) : (
          <table className="data-table">
            <thead><tr>
              <th>ID</th><th>User</th><th>Trip</th><th>Location</th><th>Time</th><th>Battery</th><th>Status</th>
            </tr></thead>
            <tbody>
              {sosFeed.map(s => (
                <tr key={s.id}>
                  <td style={{ fontWeight: 600 }}>{s.id}</td>
                  <td>{s.user}</td>
                  <td>{s.trip}</td>
                  <td>{s.location}</td>
                  <td>{s.time}</td>
                  <td><span style={{ color: parseInt(s.battery) < 20 ? 'var(--sos-danger)' : 'var(--text-secondary)' }}>{s.battery}</span></td>
                  <td><span className={`badge ${s.status === 'ACTIVE' ? 'danger' : 'warning'}`}>{s.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Revenue & Alerts */}
      <div className="detail-grid">
        <div className="panel">
          <div className="panel-header"><DollarSign size={18} /> Revenue Summary</div>
          <div className="panel-content">
            <div className="empty-state" style={{ padding: '20px' }}><p style={{ fontSize: '13px' }}>결제 API 연동 후 표시됩니다.</p></div>
          </div>
        </div>
        <div className="panel">
          <div className="panel-header"><AlertTriangle size={18} /> System Alerts</div>
          <div className="panel-content">
            <div className="empty-state" style={{ padding: '20px' }}><p style={{ fontSize: '13px' }}>이벤트 API 연동 후 표시됩니다.</p></div>
          </div>
        </div>
      </div>
    </div>
  );
}

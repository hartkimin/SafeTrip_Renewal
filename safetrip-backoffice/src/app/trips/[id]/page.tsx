'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { tripService } from '@/services/tripService';
import { sosService } from '@/services/sosService';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    ArrowLeft, Plane, Users, Calendar, MapPin, Shield,
    Clock, AlertTriangle, FileText, Globe
} from 'lucide-react';

const TABS = [
    { id: 'overview', label: 'Overview', icon: Plane },
    { id: 'members', label: 'Members', icon: Users },
    { id: 'schedule', label: 'Schedule', icon: Calendar },
    { id: 'sos', label: 'SOS History', icon: AlertTriangle },
    { id: 'log', label: 'Event Log', icon: FileText },
];

export default function TripDetailPage() {
    const params = useParams();
    const router = useRouter();
    const tripId = params.id as string;
    const [activeTab, setActiveTab] = useState('overview');

    const { data: tripData, isLoading } = useQuery({
        queryKey: ['trip', tripId],
        queryFn: () => tripService.getTripById(tripId),
    });

    const trip: any = tripData?.data || tripData || {};

    if (isLoading) {
        return (
            <div className="animate-in fade-in duration-300 space-y-6">
                <div className="h-8 w-48 bg-slate-200 animate-pulse rounded-lg" />
                <div className="h-64 bg-slate-100 animate-pulse rounded-2xl" />
            </div>
        );
    }

    const statusColor = trip.status === 'active' ? 'emerald' : trip.status === 'planning' ? 'blue' : 'slate';

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 ease-out">
            {/* Back button */}
            <Button variant="ghost" size="sm" className="gap-2" onClick={() => router.push('/trips')}>
                <ArrowLeft size={16} /> Back to Trips
            </Button>

            {/* Trip Header Card */}
            <div className="glass-panel rounded-2xl p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-64 h-64 bg-blue-400 opacity-5 rounded-full blur-3xl -mr-20 -mt-20" />
                <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center gap-6">
                    <div className="h-20 w-20 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-2xl flex items-center justify-center text-white text-3xl shadow-lg">
                        <Plane size={36} />
                    </div>
                    <div className="flex-1">
                        <h1 className="text-2xl font-extrabold text-slate-800 flex items-center gap-3">
                            {trip.name || trip.title || `Trip ${tripId.substring(0, 8)}`}
                            <Badge className={`bg-${statusColor}-100 text-${statusColor}-700 border-${statusColor}-200 capitalize`}>
                                {trip.status || 'unknown'}
                            </Badge>
                        </h1>
                        <p className="text-sm text-slate-500 font-mono mt-1">{trip.trip_id || tripId}</p>
                        <div className="flex items-center gap-4 mt-3 text-sm text-slate-500">
                            {trip.destination && <span className="flex items-center gap-1"><Globe size={14} /> {trip.destination}</span>}
                            {trip.start_date && <span className="flex items-center gap-1"><Calendar size={14} /> {new Date(trip.start_date).toLocaleDateString()}</span>}
                            <span className="flex items-center gap-1"><Users size={14} /> {trip.member_count || 0} members</span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 overflow-x-auto pb-2">
                {TABS.map(tab => {
                    const Icon = tab.icon;
                    return (
                        <button
                            key={tab.id}
                            className={`flex items-center gap-2 px-5 py-3 rounded-xl text-sm font-bold transition-all whitespace-nowrap
                                ${activeTab === tab.id
                                    ? 'bg-gradient-to-r from-blue-500 to-indigo-600 text-white shadow-md shadow-blue-500/20'
                                    : 'bg-white/60 text-slate-600 hover:bg-white hover:shadow-sm border border-slate-100'
                                }`}
                            onClick={() => setActiveTab(tab.id)}
                        >
                            <Icon size={16} /> {tab.label}
                        </button>
                    );
                })}
            </div>

            {/* Tab Content */}
            <div className="glass-panel rounded-2xl p-8">
                {activeTab === 'overview' && (
                    <div className="grid md:grid-cols-2 gap-6">
                        {[
                            { icon: Plane, label: 'Trip Name', value: trip.name || trip.title || '-', color: 'blue' },
                            { icon: Globe, label: 'Destination', value: trip.destination || '-', color: 'teal' },
                            { icon: Calendar, label: 'Start Date', value: trip.start_date ? new Date(trip.start_date).toLocaleDateString() : '-', color: 'purple' },
                            { icon: Calendar, label: 'End Date', value: trip.end_date ? new Date(trip.end_date).toLocaleDateString() : '-', color: 'indigo' },
                            { icon: Users, label: 'Members', value: trip.member_count || 0, color: 'emerald' },
                            { icon: Shield, label: 'Guardian Links', value: trip.guardian_count || 0, color: 'amber' },
                        ].map((item, i) => {
                            const Icon = item.icon;
                            return (
                                <div key={i} className="flex items-center gap-4 p-5 border border-slate-100 rounded-xl bg-white/50 shadow-sm">
                                    <div className={`p-3 bg-${item.color}-50 text-${item.color}-500 rounded-xl`}><Icon size={22} /></div>
                                    <div>
                                        <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">{item.label}</p>
                                        <p className="text-base font-bold text-slate-700 mt-1">{String(item.value)}</p>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}

                {activeTab === 'members' && (
                    <div className="text-center py-12 text-slate-400">
                        <Users size={48} className="mx-auto mb-4 opacity-30" />
                        <p className="font-medium">멤버 목록은 그룹 API 연동 후 표시됩니다.</p>
                    </div>
                )}

                {activeTab === 'schedule' && (
                    <div className="text-center py-12 text-slate-400">
                        <Calendar size={48} className="mx-auto mb-4 opacity-30" />
                        <p className="font-medium">일정은 Schedule API 연동 후 표시됩니다.</p>
                    </div>
                )}

                {activeTab === 'sos' && (
                    <div className="text-center py-12 text-slate-400">
                        <AlertTriangle size={48} className="mx-auto mb-4 opacity-30" />
                        <p className="font-medium">SOS 이력은 여행별 긴급상황 API 연동 후 표시됩니다.</p>
                    </div>
                )}

                {activeTab === 'log' && (
                    <div className="space-y-3">
                        <h3 className="text-lg font-bold text-slate-800">Recent Events</h3>
                        {[
                            { action: 'Trip created', time: trip.created_at ? new Date(trip.created_at).toLocaleString() : '-', icon: Plane },
                            { action: 'Member joined', time: 'N/A', icon: Users },
                        ].map((log, i) => {
                            const LogIcon = log.icon;
                            return (
                                <div key={i} className="flex items-center gap-4 p-4 rounded-xl bg-slate-50 border border-slate-100">
                                    <div className="p-2 bg-blue-100 text-blue-600 rounded-lg"><LogIcon size={16} /></div>
                                    <span className="font-medium text-slate-700 flex-1">{log.action}</span>
                                    <span className="text-xs text-slate-400 flex items-center gap-1"><Clock size={12} /> {log.time}</span>
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>
        </div>
    );
}

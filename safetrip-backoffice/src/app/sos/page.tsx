'use client';

import { useState } from 'react';
import dynamic from 'next/dynamic';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { sosService, EmergencyEvent, SOSStats } from '@/services/sosService';
import { DataTable } from '@/components/ui/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    Dialog, DialogContent, DialogDescription,
    DialogFooter, DialogHeader, DialogTitle
} from '@/components/ui/dialog';
import {
    ShieldAlert, CircleCheck, MapPin, ClipboardList,
    Battery, Wifi, Clock, Maximize2, Siren, RefreshCw,
    MessageSquare, CheckCircle2, AlertTriangle
} from 'lucide-react';
import { Input } from '@/components/ui/input';
import { toast } from 'sonner';
import { PageHeader } from '@/components/PageHeader';

// Dynamic import — Leaflet requires `window` (no SSR)
const SOSMap = dynamic(() => import('@/components/SOSMap'), {
    ssr: false,
    loading: () => (
        <div className="flex items-center justify-center h-full bg-muted/20 text-muted-foreground italic">
            지도 데이터를 불러오는 중...
        </div>
    ),
});

export default function SOSPage() {
    const queryClient = useQueryClient();
    const [selectedEvent, setSelectedEvent] = useState<EmergencyEvent | null>(null);
    const [resolveDialogOpen, setResolveDialogOpen] = useState(false);
    const [resolveNotes, setResolveNotes] = useState('');

    // Fetch SOS Events (Polling every 30s for real-time feel)
    const { data: rawEvents, isLoading: loadingEvents } = useQuery({
        queryKey: ['emergencies'],
        queryFn: () => sosService.getEmergencies(),
        refetchInterval: 30000, // 30 seconds
    });

    const { data: stats } = useQuery({
        queryKey: ['sos-stats'],
        queryFn: () => sosService.getStats(),
        refetchInterval: 30000,
    });

    const events: EmergencyEvent[] = (rawEvents?.data || rawEvents || []).map((e: any) => ({
        ...e,
        id: e.emergency_id || e.id,
        user: e.user_name || 'Unknown',
        time: e.created_at ? new Date(e.created_at).toLocaleTimeString('ko-KR') : '-',
        lat: e.latitude || e.lat,
        lng: e.longitude || e.lng,
    }));

    const activeEvents = events.filter(e => e.status === 'active');

    // Mutation for resolving SOS
    const resolveMutation = useMutation({
        mutationFn: (vars: { id: string, notes: string }) =>
            sosService.resolveEmergency(vars.id, { resolved_by: 'admin', notes: vars.notes }),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['emergencies'] });
            queryClient.invalidateQueries({ queryKey: ['sos-stats'] });
            toast.success('SOS 이벤트가 성공적으로 해결되었습니다.');
            setResolveDialogOpen(false);
            setResolveNotes('');
            setSelectedEvent(null);
        },
        onError: (err: any) => {
            toast.error(`해결 처리 실패: ${err.message}`);
        }
    });

    const handleOpenResolve = (event: EmergencyEvent) => {
        setSelectedEvent(event);
        setResolveDialogOpen(true);
    };

    const confirmResolve = () => {
        if (selectedEvent) {
            resolveMutation.mutate({ id: selectedEvent.emergency_id || (selectedEvent as any).id, notes: resolveNotes });
        }
    };

    // Table Columns for Rescue Log
    const columns: ColumnDef<EmergencyEvent>[] = [
        {
            accessorKey: 'emergency_id',
            header: 'ID',
            cell: ({ row }) => <span className="font-mono text-xs">{row.original.emergency_id || (row.original as any).id}</span>,
        },
        {
            accessorKey: 'user_name',
            header: '사용자',
            cell: ({ row }) => <span className="font-bold text-sm">{row.original.user_name}</span>,
        },
        {
            accessorKey: 'location',
            header: '위치',
            cell: ({ row }) => <span className="text-sm truncate max-w-[150px] inline-block">{row.original.location || '-'}</span>,
        },
        {
            accessorKey: 'status',
            header: '상태',
            cell: ({ row }) => (
                <span className={`status-tag ${row.original.status === 'active' ? 'status-tag-danger' : 'status-tag-default'} uppercase`}>
                    {row.original.status}
                </span>
            ),
        },
        {
            accessorKey: 'created_at',
            header: '시간',
            cell: ({ row }) => <span className="text-xs">{new Date(row.original.created_at).toLocaleString()}</span>,
        },
        {
            id: 'actions',
            header: '관리',
            cell: ({ row }) => (
                row.original.status === 'active' ? (
                    <Button
                        size="sm"
                        variant="destructive"
                        className="h-7 text-[11px]"
                        onClick={() => handleOpenResolve(row.original)}
                    >
                        Resolve
                    </Button>
                ) : <span className="text-xs text-muted-foreground italic">처리완료</span>
            ),
        },
    ];

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 ease-out">
            <PageHeader
                icon={Siren}
                iconBg="bg-red-100"
                iconColor="text-red-600"
                glowColor="bg-red-500"
                title="SOS Control Center"
                subtitle="실시간 긴급 상황을 통합 관제하고 즉각적인 구조 대응을 지휘합니다."
                actions={
                    <div className="flex items-center gap-2 text-xs font-bold text-slate-600 bg-white/80 backdrop-blur-md px-4 py-2 rounded-full border border-red-100 shadow-sm">
                        <span className="relative flex h-2 w-2">
                            <span className={loadingEvents ? "animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" : ""}></span>
                            <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
                        </span>
                        LIVE TRACKING {loadingEvents && <RefreshCw className="h-3 w-3 animate-spin ml-1 text-red-500" />}
                    </div>
                }
            />

            {/* Stats Dashboard */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform border border-red-100/50 relative overflow-hidden">
                    <div className="absolute -right-4 -top-4 w-16 h-16 bg-red-500 opacity-10 rounded-full blur-xl"></div>
                    <div className="p-3.5 bg-gradient-to-br from-red-500 to-rose-600 text-white rounded-xl shadow-md shadow-red-500/20 relative z-10"><AlertTriangle size={22} className="animate-pulse flex-none" /></div>
                    <div className="relative z-10">
                        <p className="text-[11px] font-bold text-red-400 uppercase tracking-widest">Unresolved</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.unresolved || 0}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform border border-amber-100/50">
                    <div className="p-3.5 bg-gradient-to-br from-amber-400 to-orange-500 text-white rounded-xl shadow-md shadow-amber-500/20"><Clock size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-amber-500 uppercase tracking-widest">In Progress</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.inProgress || 0}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform border border-emerald-100/50">
                    <div className="p-3.5 bg-gradient-to-br from-emerald-400 to-teal-500 text-white rounded-xl shadow-md shadow-emerald-500/20"><CheckCircle2 size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-emerald-500 uppercase tracking-widest">Resolved Today</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.resolvedToday || 0}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform border border-indigo-100/50">
                    <div className="p-3.5 bg-gradient-to-br from-indigo-400 to-blue-500 text-white rounded-xl shadow-md shadow-blue-500/20"><Maximize2 size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-indigo-400 uppercase tracking-widest">Avg Response</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.avgResponseTime || '-'}</p>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-[400px_1fr] gap-6">
                {/* Active Events Sidebar */}
                <div className="flex flex-col gap-4">
                    <div className="glass-panel rounded-2xl flex flex-col h-[650px] overflow-hidden border border-red-50/50">
                        <div className="p-5 border-b border-slate-100/60 flex items-center justify-between bg-gradient-to-r from-red-50/50 to-white/30 backdrop-blur-sm">
                            <h2 className="font-bold text-red-700 flex items-center gap-2"><Siren size={18} className="text-red-600" /> Active Alerts</h2>
                            <Badge className="bg-gradient-to-r from-red-500 to-rose-600 text-white border-0 rounded-full px-3 py-0.5 shadow-sm">{activeEvents.length}</Badge>
                        </div>
                        <div className="flex-1 overflow-y-auto p-4 space-y-4 custom-scroll bg-white/30">
                            {loadingEvents ? <div className="space-y-4 pt-4 text-center text-slate-400 font-medium animate-pulse">이벤트 상태 확인 중...</div> :
                                activeEvents.length === 0 ? (
                                    <div className="flex flex-col items-center justify-center h-full text-center py-12 px-4 space-y-3 opacity-80 mix-blend-multiply">
                                        <div className="p-5 bg-gradient-to-br from-emerald-100 to-teal-50 rounded-full shadow-inner"><CircleCheck size={48} className="text-emerald-500" /></div>
                                        <div>
                                            <p className="text-base font-bold text-slate-700">모든 지역 정상</p>
                                            <p className="text-xs font-medium text-slate-500 mt-1">현재 활성 SOS가 없습니다.</p>
                                        </div>
                                    </div>
                                ) : activeEvents.map(ev => (
                                    <div key={ev.emergency_id || (ev as any).id}
                                        className="p-5 rounded-xl bg-white border border-red-100 hover:border-red-300 transition-all shadow-sm hover:shadow-md cursor-pointer relative overflow-hidden group"
                                        onClick={() => setSelectedEvent(ev)}>
                                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-red-400 to-red-600 group-hover:w-1.5 transition-all"></div>
                                        <div className="flex justify-between items-start mb-3 pl-2">
                                            <div className="font-extrabold text-slate-800 text-lg">{ev.user_name}</div>
                                            <Badge className="bg-red-500/10 text-red-600 border border-red-200 text-[10px] animate-pulse rounded-full px-2 py-0">CRITICAL</Badge>
                                        </div>
                                        <div className="text-sm text-slate-600 mb-4 flex items-start gap-2 pl-2 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                                            <MapPin size={16} className="mt-0.5 shrink-0 text-[#00A2BD]" />
                                            <span className="line-clamp-2 leading-relaxed font-medium">{ev.location || '위치 정보 수신 중...'}</span>
                                        </div>
                                        <div className="flex items-center justify-between text-[11px] text-slate-500 mb-5 font-bold px-2">
                                            <span className="flex items-center gap-1.5 bg-slate-100 px-2 py-1 rounded-md"><Battery size={14} className={ev.battery_level && (ev.battery_level as any) < 20 ? 'text-red-500' : 'text-emerald-500'} /> {ev.battery_level ? `${ev.battery_level}%` : '-'}</span>
                                            <span className="flex items-center gap-1.5 bg-slate-100 px-2 py-1 rounded-md"><Wifi size={14} className="text-blue-500" /> {ev.network_type || '-'}</span>
                                            <span className="flex items-center gap-1.5 bg-slate-100 px-2 py-1 rounded-md"><Clock size={14} className="text-amber-500" /> {new Date(ev.created_at).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}</span>
                                        </div>
                                        <div className="flex gap-2 pl-2">
                                            <Button size="sm" className="flex-1 bg-gradient-to-r from-red-500 to-rose-600 hover:shadow-lg shadow-md text-white border-0 h-10 rounded-lg font-bold" onClick={(e) => { e.stopPropagation(); handleOpenResolve(ev); }}>해결 처리 (Resolve)</Button>
                                            <Button variant="outline" size="sm" className="h-10 w-12 bg-white border-slate-200 rounded-lg text-slate-500 hover:text-[#00A2BD] hover:border-[#00A2BD]"><MessageSquare size={16} /></Button>
                                        </div>
                                    </div>
                                ))
                            }
                        </div>
                    </div>
                </div>

                {/* Map & Rescue Log */}
                <div className="space-y-6 flex flex-col">
                    <div className="glass-panel p-2 rounded-2xl h-[450px] relative">
                        <div className="absolute top-6 left-6 z-[1000] flex flex-col gap-2">
                            <div className="bg-white/90 backdrop-blur-md shadow-lg p-2.5 rounded-xl border border-white flex items-center gap-2">
                                <span className="relative flex h-3 w-3">
                                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                                    <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                                </span>
                                <span className="text-[11px] font-black uppercase tracking-widest text-slate-700">Live Geo-Fence</span>
                            </div>
                        </div>
                        <div className="w-full h-full rounded-xl overflow-hidden shadow-inner border border-slate-200/50">
                            <SOSMap events={events} onEventClick={setSelectedEvent} />
                        </div>
                    </div>

                    <div className="glass-panel rounded-2xl overflow-hidden flex-1">
                        <div className="p-5 border-b border-slate-100 flex items-center gap-2 bg-white/40">
                            <div className="p-1.5 bg-[#00A2BD]/10 text-[#00A2BD] rounded-md"><ClipboardList size={18} /></div>
                            <span className="font-bold text-slate-800 text-lg">Rescue Logs & Recent History</span>
                        </div>
                        <div className="premium-table p-1">
                            <DataTable
                                columns={columns}
                                data={events}
                                loading={loadingEvents}
                                pageSize={5}
                            />
                        </div>
                    </div>
                </div>
            </div>

            {/* Resolve Confirmation Dialog */}
            <Dialog open={resolveDialogOpen} onOpenChange={setResolveDialogOpen}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>SOS 상황 해결 처리</DialogTitle>
                        <DialogDescription>
                            {selectedEvent?.user_name} 사용자의 SOS 상황을 종료합니다. <br />
                            해결 내용 또는 조치 사항을 간단히 기록해주세요.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="py-4">
                        <Input
                            placeholder="예: 현지 경찰 연동 완료, 무사 귀가 확인 등..."
                            value={resolveNotes}
                            onChange={(e) => setResolveNotes(e.target.value)}
                        />
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setResolveDialogOpen(false)}>취소</Button>
                        <Button variant="destructive" onClick={confirmResolve} disabled={resolveMutation.isPending}>
                            {resolveMutation.isPending ? '처리 중...' : '해결 완료 처리'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}

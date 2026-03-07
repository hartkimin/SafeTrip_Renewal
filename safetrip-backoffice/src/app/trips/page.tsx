'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { tripService, Trip } from '@/services/tripService';
import { DataTable } from '@/components/ui/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
    Sheet,
    SheetContent,
    SheetDescription,
    SheetHeader,
    SheetTitle
} from '@/components/ui/sheet';
import {
    Plane, Users, Search, MapPin, Calendar,
    ChevronRight, Info, UserCheck, ShieldAlert
} from 'lucide-react';
import { PageHeader } from '@/components/PageHeader';

const PRIVACY_LABELS: Record<string, string> = { safety_first: '안전최우선', standard: '표준', privacy_first: '프라이버시' };
const PRIVACY_VARIANTS: Record<string, any> = { safety_first: 'destructive', standard: 'default', privacy_first: 'secondary' };
const ROLE_VARIANTS: Record<string, any> = { captain: 'default', crew_chief: 'secondary', crew: 'outline', guardian: 'destructive' };

export default function TripsPage() {
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
    const [isSheetOpen, setIsSheetOpen] = useState(false);

    // Fetch Trips
    const { data: rawTrips, isLoading, refetch } = useQuery({
        queryKey: ['trips', searchQuery],
        queryFn: () => tripService.getTrips({ search: searchQuery }),
    });

    const { data: stats } = useQuery({
        queryKey: ['trip-stats'],
        queryFn: () => tripService.getTripStats(),
    });

    // Fetch Members when a trip is selected
    const { data: membersRaw, isLoading: membersLoading } = useQuery({
        queryKey: ['trip-members', selectedTrip?.trip_id],
        queryFn: () => tripService.getTripMembers(selectedTrip?.trip_id || ''),
        enabled: !!selectedTrip?.trip_id,
    });

    const trips: any[] = (rawTrips?.data || rawTrips || []).map((t: any) => ({
        ...t,
        id: t.trip_id || t.id,
        name: t.trip_name || t.name || '-',
        destination: t.destination || '-',
        captain: t.captain_name || t.captain?.name || '-',
        members: t.member_count || 0,
        status: t.status || 'active',
        privacy: t.privacy_level || 'standard',
        startDate: t.start_date ? new Date(t.start_date).toISOString().split('T')[0] : '-',
        endDate: t.end_date ? new Date(t.end_date).toISOString().split('T')[0] : '-',
    }));

    const members: any[] = (membersRaw?.data || membersRaw?.members || membersRaw || []).map((m: any) => ({
        name: m.display_name || m.name || '-',
        role: m.member_role || m.role || 'crew',
        status: m.status || 'active',
    }));

    const handleRowClick = (trip: Trip) => {
        setSelectedTrip(trip);
        setIsSheetOpen(true);
    };

    // Table Columns
    const columns: ColumnDef<any>[] = [
        {
            accessorKey: 'id',
            header: '여행 ID',
            cell: ({ row }) => <code className="text-[11px] font-mono opacity-70">{row.original.id}</code>,
        },
        {
            accessorKey: 'name',
            header: '여행명',
            cell: ({ row }) => <span className="font-bold text-sm">{row.original.name}</span>,
        },
        {
            accessorKey: 'destination',
            header: '목적지',
            cell: ({ row }) => (
                <div className="flex items-center gap-1 text-sm">
                    <MapPin size={12} className="text-muted-foreground" />
                    <span>{row.original.destination}</span>
                </div>
            ),
        },
        {
            accessorKey: 'captain',
            header: '캡틴(방장)',
            cell: ({ row }) => <span className="text-sm font-medium">{row.original.captain}</span>,
        },
        {
            accessorKey: 'members',
            header: '인원',
            cell: ({ row }) => (
                <div className="flex items-center gap-1 text-sm">
                    <Users size={12} className="text-muted-foreground" />
                    <span>{row.original.members}명</span>
                </div>
            ),
        },
        {
            accessorKey: 'privacy',
            header: '공유 설정',
            cell: ({ row }) => (
                <Badge variant={PRIVACY_VARIANTS[row.original.privacy] || 'outline'} className="text-[10px]">
                    {PRIVACY_LABELS[row.original.privacy] || row.original.privacy}
                </Badge>
            ),
        },
        {
            accessorKey: 'status',
            header: '상태',
            cell: ({ row }) => (
                <Badge variant={row.original.status === 'active' ? 'default' : 'secondary'} className="capitalize text-[10px]">
                    {row.original.status}
                </Badge>
            ),
        },
        {
            accessorKey: 'endDate',
            header: '기간',
            cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.startDate} ~ {row.original.endDate}</span>,
        },
        {
            id: 'actions',
            header: '상세',
            cell: ({ row }) => (
                <Button variant="ghost" size="icon" className="h-8 w-8 text-primary" onClick={(e) => { e.stopPropagation(); handleRowClick(row.original); }}>
                    <ChevronRight className="h-4 w-4" />
                </Button>
            ),
        },
    ];

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 ease-out">
            {/* ─── Premium Header ─── */}
            <PageHeader
                icon={Plane}
                iconBg="bg-teal-100"
                iconColor="text-[#00A2BD]"
                glowColor="bg-teal-400"
                title="Trips & Groups"
                subtitle="생성된 전 세계 여행 그룹과 멤버 현황을 실시간으로 확인합니다."
            />

            {/* Trip Dashboard Stats */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform">
                    <div className="p-3.5 bg-gradient-to-br from-[#00A2BD] to-[#46D2E1] text-white rounded-xl shadow-md"><Plane size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Total Trips</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.totalTrips || trips.length}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform">
                    <div className="p-3.5 bg-gradient-to-br from-emerald-400 to-emerald-500 text-white rounded-xl shadow-md"><UserCheck size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Active</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.activeTrips || trips.filter(t => t.status === 'active').length}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform">
                    <div className="p-3.5 bg-gradient-to-br from-amber-400 to-amber-500 text-white rounded-xl shadow-md"><Calendar size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Planning</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">{stats?.planningTrips || trips.filter(t => t.status === 'planning').length}</p>
                    </div>
                </div>
                <div className="glass-panel p-5 rounded-2xl flex items-center gap-4 hover:-translate-y-1 transition-transform">
                    <div className="p-3.5 bg-gradient-to-br from-indigo-400 to-purple-500 text-white rounded-xl shadow-md"><Users size={22} /></div>
                    <div>
                        <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Avg Group</p>
                        <p className="text-2xl font-black text-slate-800 tracking-tight">
                            {trips.length ? Math.round(trips.reduce((s, t) => s + t.members, 0) / trips.length) : 0}
                        </p>
                    </div>
                </div>
            </div>

            {/* List */}
            <div className="glass-panel rounded-2xl overflow-hidden">
                <div className="p-5 border-b border-slate-100 flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white/40">
                    <h2 className="font-bold text-lg text-slate-800">Trip Directory</h2>
                    <div className="relative w-full md:w-80">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                        <Input
                            placeholder="여행명, 캡틴, 목적지 검색..."
                            className="pl-9 h-11 bg-white/60 border-slate-200/60 transition-all focus-visible:ring-[#00A2BD] rounded-xl"
                            value={searchQuery}
                            onChange={e => setSearchQuery(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && refetch()}
                        />
                    </div>
                </div>
                <div className="premium-table p-1">
                    <DataTable
                        columns={columns}
                        data={trips}
                        loading={isLoading}
                        pageSize={10}
                    />
                </div>
            </div>

            {/* Trip Details Sheet */}
            <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
                <SheetContent className="sm:max-w-md overflow-y-auto">
                    <SheetHeader className="mb-6">
                        <SheetTitle className="text-xl">여행 상세 정보</SheetTitle>
                        <SheetDescription>그룹 멤버 구성 및 여행 일정을 확인합니다.</SheetDescription>
                    </SheetHeader>

                    {selectedTrip && (
                        <div className="space-y-6 py-4">
                            <div className="bg-gradient-to-br from-[#00A2BD]/5 to-[#46D2E1]/10 p-6 rounded-2xl border border-[#00A2BD]/10 text-center space-y-3 relative overflow-hidden">
                                <div className="absolute right-0 top-0 w-32 h-32 bg-[#00A2BD] opacity-5 rounded-full blur-2xl -mr-10 -mt-10"></div>
                                <div className="mx-auto h-14 w-14 bg-gradient-to-br from-[#00A2BD] to-[#008196] shadow-lg rounded-full flex items-center justify-center text-white mb-2 relative z-10">
                                    <Plane size={24} />
                                </div>
                                <div className="relative z-10">
                                    <h3 className="text-2xl font-black text-slate-800 tracking-tight">{(selectedTrip as any).name}</h3>
                                    <p className="text-sm font-semibold text-[#00A2BD] flex items-center justify-center gap-1.5 mt-1">
                                        <MapPin size={16} /> {(selectedTrip as any).destination}
                                    </p>
                                    <div className="flex justify-center gap-2 mt-3">
                                        <Badge variant={(selectedTrip as any).status === 'active' ? 'default' : 'secondary'} className="uppercase px-3 rounded-full">
                                            {(selectedTrip as any).status}
                                        </Badge>
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="p-4 border border-slate-100 rounded-xl bg-slate-50">
                                    <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">여행 기간</p>
                                    <p className="text-sm font-bold text-slate-700">{(selectedTrip as any).startDate}</p>
                                    <p className="text-sm font-bold text-slate-700">~ {(selectedTrip as any).endDate}</p>
                                </div>
                                <div className="p-4 border border-slate-100 rounded-xl bg-slate-50">
                                    <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">안전/공유 모드</p>
                                    <Badge variant={PRIVACY_VARIANTS[(selectedTrip as any).privacy] || 'outline'} className="mt-1">
                                        {PRIVACY_LABELS[(selectedTrip as any).privacy] || (selectedTrip as any).privacy}
                                    </Badge>
                                </div>
                            </div>

                            <div className="border-t border-slate-100 pt-6">
                                <h4 className="font-bold flex items-center gap-2 mb-4 text-slate-800">
                                    <Users size={18} className="text-[#00A2BD]" /> 그룹 구성원 ({(selectedTrip as any).members}명)
                                </h4>

                                {membersLoading ? (
                                    <div className="text-center py-6 text-sm font-medium text-slate-400 animate-pulse bg-slate-50 rounded-xl">멤버 데이터 동기화 중...</div>
                                ) : members.length === 0 ? (
                                    <div className="text-center py-6 text-sm font-medium text-slate-400 bg-slate-50 rounded-xl">멤버 데이터가 없습니다.</div>
                                ) : (
                                    <div className="space-y-3 max-h-60 overflow-y-auto pr-2 custom-scroll">
                                        {members.map((m, idx) => (
                                            <div key={idx} className="flex items-center justify-between p-3.5 border border-slate-100 rounded-xl hover:bg-slate-50 transition-colors bg-white shadow-sm">
                                                <div className="flex items-center gap-3">
                                                    <div className="h-9 w-9 rounded-full bg-gradient-to-br from-slate-200 to-slate-300 flex items-center justify-center font-bold text-slate-600 text-sm shadow-inner">
                                                        {m.name.charAt(0)}
                                                    </div>
                                                    <div>
                                                        <p className="text-sm font-bold text-slate-700">{m.name}</p>
                                                        <p className="text-xs font-medium text-emerald-500 capitalize leading-none mt-0.5">{m.status}</p>
                                                    </div>
                                                </div>
                                                <Badge variant={ROLE_VARIANTS[m.role] || 'outline'} className="capitalize border border-[#00A2BD]/30 shadow-sm text-xs rounded-full px-3 py-0.5">
                                                    {m.role.replace('_', ' ')}
                                                </Badge>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            <div className="pt-6 flex gap-3">
                                <Button className="flex-1 bg-gradient-to-r from-[#00A2BD] to-[#008196] shadow-md hover:shadow-lg text-white font-bold h-12 rounded-xl">일정표 보기</Button>
                                <Button variant="outline" className="flex-1 h-12 rounded-xl font-bold border-slate-200">위치 기록 확인</Button>
                            </div>
                        </div>
                    )}
                </SheetContent>
            </Sheet>
        </div>
    );
}

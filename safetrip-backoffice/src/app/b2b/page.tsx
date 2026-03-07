'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { b2bService, B2BOrganization } from '@/services/b2bService';
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
    Building2, Search, Plus, Eye,
    Calendar, Users, DollarSign, FileText
} from 'lucide-react';
import { PageHeader } from '@/components/PageHeader';

export default function B2BPage() {
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedOrg, setSelectedOrg] = useState<any | null>(null);
    const [isSheetOpen, setIsSheetOpen] = useState(false);

    // Fetch B2B Organizations
    const { data: rawOrgs, isLoading, refetch } = useQuery({
        queryKey: ['organizations', searchQuery],
        queryFn: () => b2bService.getOrganizations({ search: searchQuery }),
    });

    const { data: rawStats } = useQuery({
        queryKey: ['b2b-stats'],
        queryFn: () => b2bService.getStats(),
    });

    const stats = rawStats?.data || rawStats; // Safely unwrap NestJS envelope

    const organizations: any[] = (rawOrgs?.data || rawOrgs || []).map((o: any) => ({
        id: o.org_id || o.id,
        name: o.org_name || o.name || '-',
        type: o.org_type || o.type || 'corporate',
        contract: o.contract_status || 'ACTIVE',
        students: o.member_count || 0,
        revenue: o.total_revenue || 0,
        startDate: o.contract_start ? new Date(o.contract_start).toISOString().split('T')[0] : '-',
        endDate: o.contract_end ? new Date(o.contract_end).toISOString().split('T')[0] : '-',
    }));

    // Table Columns
    const columns: ColumnDef<any>[] = [
        {
            accessorKey: 'id',
            header: '조직 ID',
            cell: ({ row }) => <code className="text-[11px] font-mono opacity-70">{row.original.id}</code>,
        },
        {
            accessorKey: 'name',
            header: '기관명',
            cell: ({ row }) => <span className="font-bold text-sm">{row.original.name}</span>,
        },
        {
            accessorKey: 'type',
            header: '구분',
            cell: ({ row }) => (
                <Badge variant="outline" className="capitalize text-[11px]">
                    {row.original.type}
                </Badge>
            ),
        },
        {
            accessorKey: 'contract',
            header: '계약 상태',
            cell: ({ row }) => (
                <span className={`status-tag no-dot ${row.original.contract === 'ACTIVE' ? 'active' : 'inactive'}`}>
                    {row.original.contract}
                </span>
            ),
        },
        {
            accessorKey: 'students',
            header: '소속 인원',
            cell: ({ row }) => <span className="font-medium">{row.original.students.toLocaleString()}명</span>,
        },
        {
            accessorKey: 'endDate',
            header: '계약 종료일',
            cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.endDate}</span>,
        },
        {
            id: 'actions',
            header: '관리',
            cell: ({ row }) => (
                <Button variant="ghost" size="icon" className="h-8 w-8 text-primary hover:text-primary" onClick={() => {
                    setSelectedOrg(row.original);
                    setIsSheetOpen(true);
                }}>
                    <Eye className="h-4 w-4" />
                </Button>
            ),
        },
    ];

    return (
        <div className="page-enter space-y-7">
            <PageHeader
                icon={Building2}
                iconBg="bg-amber-50"
                iconColor="text-amber-600"
                glowColor="bg-amber-400"
                title="B2B Partner Management"
                subtitle="여행사, 학교, 기업 등 SafeTrip B2B 제휴 파트너를 관리합니다."
            />

            {/* B2B Dashboard Stats */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
                {[
                    { icon: Building2, label: 'Total Partners', value: stats?.totalPartners || 0, color: 'amber', stagger: 2 },
                    { icon: FileText, label: 'Active Contracts', value: stats?.activePartners || 0, color: 'emerald', stagger: 3 },
                    { icon: Calendar, label: 'Expiring Soon', value: stats?.expiringSoon || 0, color: 'red', stagger: 4 },
                    { icon: DollarSign, label: 'Est. Revenue', value: `₩${(stats?.totalRevenue || 0).toLocaleString()}`, color: 'blue', stagger: 5 },
                ].map((kpi) => {
                    const bgMap: Record<string, string> = { amber: 'bg-amber-50', emerald: 'bg-emerald-50', red: 'bg-red-50', blue: 'bg-blue-50' };
                    const textMap: Record<string, string> = { amber: 'text-amber-600', emerald: 'text-emerald-600', red: 'text-red-600', blue: 'text-blue-600' };
                    return (
                        <div key={kpi.label} className={`stagger-${kpi.stagger} hover-lift rounded-2xl p-5 border border-white/60 flex items-center gap-4`}
                            style={{ background: 'linear-gradient(145deg, rgba(255,255,255,0.95), rgba(248,250,252,0.85))', boxShadow: 'var(--elevation-1)' }}>
                            <div className={`w-11 h-11 rounded-xl ${bgMap[kpi.color]} ${textMap[kpi.color]} flex items-center justify-center`}>
                                <kpi.icon size={22} />
                            </div>
                            <div>
                                <p className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest">{kpi.label}</p>
                                <p className={`text-2xl font-black ${textMap[kpi.color]}`}>{kpi.value}</p>
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* List & Actions */}
            <div className="stagger-6 rounded-2xl border border-white/60 overflow-hidden"
                style={{ background: 'linear-gradient(180deg, rgba(255,255,255,0.95), rgba(248,250,252,0.9))', boxShadow: 'var(--elevation-1)' }}>
                <div className="px-6 py-4 border-b border-slate-100/80 flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <span className="heading-sm">Partner Directory</span>
                    <div className="flex items-center gap-2">
                        <div className="relative w-64">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                            <Input
                                placeholder="기관명, 도메인 검색..."
                                className="pl-9 h-9"
                                value={searchQuery}
                                onChange={e => setSearchQuery(e.target.value)}
                                onKeyDown={e => e.key === 'Enter' && refetch()}
                            />
                        </div>
                        <Button className="h-9 gap-2 bg-amber-500 hover:bg-amber-600">
                            <Plus size={14} /> Add Partner
                        </Button>
                    </div>
                </div>
                <div className="p-2 premium-table">
                    <DataTable
                        columns={columns}
                        data={organizations}
                        loading={isLoading}
                        pageSize={10}
                    />
                </div>
            </div>

            {/* B2B Org Details Sheet */}
            <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
                <SheetContent className="sm:max-w-md overflow-y-auto">
                    <SheetHeader className="mb-6">
                        <SheetTitle className="text-xl">기관 상세 정보</SheetTitle>
                        <SheetDescription>B2B 파트너 계약 및 소속 그룹 현황을 확인합니다.</SheetDescription>
                    </SheetHeader>

                    {selectedOrg && (
                        <div className="space-y-6 py-4">
                            <div className="flex items-center gap-4 bg-muted/30 p-4 rounded-xl border border-border">
                                <div className="h-14 w-14 bg-amber-100 text-amber-600 rounded-lg flex items-center justify-center text-xl font-bold">
                                    <Building2 />
                                </div>
                                <div>
                                    <h3 className="text-lg font-bold">{selectedOrg.name}</h3>
                                    <p className="text-sm text-muted-foreground font-mono">{selectedOrg.id}</p>
                                    <div className="flex gap-2 mt-1">
                                        <Badge variant="outline" className="text-[10px]">{selectedOrg.type}</Badge>
                                        <Badge variant={selectedOrg.contract === 'ACTIVE' ? 'default' : 'secondary'} className="text-[10px]">{selectedOrg.contract}</Badge>
                                    </div>
                                </div>
                            </div>

                            <div className="grid gap-4">
                                <div className="p-4 border rounded-xl space-y-3">
                                    <h4 className="text-sm font-bold flex items-center gap-2"><FileText size={16} className="text-primary" /> 계약 정보</h4>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-muted-foreground">계약 기간</span>
                                        <span className="font-medium">{selectedOrg.startDate} ~ {selectedOrg.endDate}</span>
                                    </div>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-muted-foreground">결제 금액(추정)</span>
                                        <span className="font-medium text-blue-600">₩{Number(selectedOrg.revenue).toLocaleString()}</span>
                                    </div>
                                </div>

                                <div className="p-4 border rounded-xl space-y-3">
                                    <h4 className="text-sm font-bold flex items-center gap-2"><Users size={16} className="text-primary" /> 운영 현황</h4>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-muted-foreground">소속 인원</span>
                                        <span className="font-bold">{selectedOrg.students.toLocaleString()}명</span>
                                    </div>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-muted-foreground">진행 중인 여행</span>
                                        <span className="font-bold">4건</span>
                                    </div>
                                    <div className="flex justify-between text-sm">
                                        <span className="text-muted-foreground">관리자 계정</span>
                                        <span className="font-medium">2명</span>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 flex flex-col gap-2">
                                <Button className="w-full bg-amber-600 hover:bg-amber-700">대시보드 설정 (Dashboard Config)</Button>
                                <Button variant="outline" className="w-full">계약 연장 / 수정</Button>
                            </div>
                        </div>
                    )}
                </SheetContent>
            </Sheet>
        </div>
    );
}

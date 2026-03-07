'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { userService, User } from '@/services/userService';
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
    Users, Search, Download, Eye, Ban,
    Calendar, Phone, Mail, User as UserIcon, ShieldAlert
} from 'lucide-react';
import { toast } from 'sonner';
import { PageHeader } from '@/components/PageHeader';

export default function UsersPage() {
    const router = useRouter();
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedUser, setSelectedUser] = useState<User | null>(null);
    const [isSheetOpen, setIsSheetOpen] = useState(false);

    // Fetch users using TanStack Query
    const { data: userResponse, isLoading, error, refetch } = useQuery({
        queryKey: ['users', searchQuery],
        queryFn: () => userService.getUsers({ search: searchQuery }),
    });

    const users = userResponse?.data || userResponse?.users || userResponse || [];

    // Table Column Definitions
    const columns: ColumnDef<User>[] = [
        {
            accessorKey: 'user_id',
            header: 'UID',
            cell: ({ row }) => <code className="text-[11px] font-mono opacity-70">{row.getValue('user_id')}</code>,
        },
        {
            accessorKey: 'display_name',
            header: '사용자명',
            cell: ({ row }) => <span className="font-semibold text-sm">{row.getValue('display_name')}</span>,
        },
        {
            accessorKey: 'phone_number',
            header: '연락처',
            cell: ({ row }) => <span className="text-sm">{row.getValue('phone_number')}</span>,
        },
        {
            accessorKey: 'status',
            header: '상태',
            cell: ({ row }) => {
                const status = row.getValue('status') as string;
                let statusClass = 'status-tag-info';
                if (status === 'active') statusClass = 'status-tag-active';
                if (status === 'banned') statusClass = 'status-tag-danger';

                return (
                    <span className={`status-tag ${statusClass} capitalize`}>
                        {status}
                    </span>
                );
            },
        },
        {
            accessorKey: 'minor_status',
            header: '구분',
            cell: ({ row }) => {
                const isMinor = row.getValue('minor_status') === 'minor';
                return isMinor ? (
                    <span className="status-tag status-tag-warning">미성년자</span>
                ) : (
                    <span className="text-xs text-muted-foreground ml-2">성인</span>
                );
            },
        },
        {
            accessorKey: 'created_at',
            header: '가입일',
            cell: ({ row }) => {
                const date = row.getValue('created_at') as string;
                return <span className="text-xs">{date ? new Date(date).toISOString().split('T')[0] : '-'}</span>;
            },
        },
        {
            id: 'actions',
            header: '관리',
            cell: ({ row }) => (
                <div className="flex items-center gap-2">
                    <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => handleViewUser(row.original)}>
                        <Eye className="h-4 w-4" />
                    </Button>
                    <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive hover:text-destructive" onClick={() => handleBanUser(row.original.user_id)}>
                        <Ban className="h-4 w-4" />
                    </Button>
                </div>
            ),
        },
    ];

    const handleViewUser = (user: User) => {
        router.push(`/users/${user.user_id}`);
    };

    const handleBanUser = (uid: string) => {
        if (confirm('해당 사용자를 차단하시겠습니까?')) {
            toast.promise(userService.banUser(uid), {
                loading: '차단 처리 중...',
                success: '사용자가 성공적으로 차단되었습니다.',
                error: '차단 처리에 실패했습니다.',
            });
        }
    };

    return (
        <div className="page-enter space-y-6">
            <PageHeader
                icon={Users}
                title="User Management"
                subtitle="SafeTrip 서비스 사용자를 안전하게 관리하고 조회합니다."
                actions={
                    <Button className="hover-lift gap-2 bg-[#00A2BD]/10 text-[#00A2BD] hover:bg-[#00A2BD]/20">
                        <Users className="h-4 w-4" />
                        사용자 데이터 통계
                    </Button>
                }
            />

            {/* Filter & Search Bar */}
            <div className="glass-panel p-4 flex flex-col md:flex-row items-center justify-between gap-4 rounded-2xl stagger-1">
                <div className="relative flex-1 w-full md:max-w-md">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                    <Input
                        placeholder="이름, UID, 전화번호 검색..."
                        className="pl-11 bg-white/60 border-slate-200/60 focus-visible:ring-[#00A2BD] focus-visible:ring-offset-0 rounded-xl h-11 transition-all"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
                <div className="flex items-center gap-3 w-full md:w-auto">
                    <Button variant="outline" className="gap-2 rounded-xl h-11 border-slate-200 hover:bg-slate-50 flex-1 md:flex-none">
                        <Download className="h-4 w-4 text-slate-500" /> <span className="text-slate-700 font-semibold">Export CSV</span>
                    </Button>
                    <Button className="bg-gradient-to-r from-[#00A2BD] to-[#008196] hover:shadow-lg hover:-translate-y-0.5 transition-all text-white gap-2 rounded-xl h-11 px-6 shadow-md shadow-[#00A2BD]/20 flex-1 md:flex-none" onClick={() => refetch()}>
                        <Search className="h-4 w-4" /> Search
                    </Button>
                </div>
            </div>

            {/* Data Table */}
            <div className="premium-table stagger-2">
                <DataTable
                    columns={columns}
                    data={users}
                    loading={isLoading}
                    pageSize={10}
                />
            </div>

            {/* User Detail Sheet */}
            <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
                <SheetContent className="sm:max-w-md overflow-y-auto">
                    <SheetHeader className="mb-6">
                        <SheetTitle className="text-xl">사용자 상세 정보</SheetTitle>
                        <SheetDescription>사용자의 계정 상태 및 활동 내역을 확인합니다.</SheetDescription>
                    </SheetHeader>

                    {selectedUser && (
                        <div className="space-y-6 py-4">
                            <div className="flex items-center gap-4 bg-gradient-to-br from-slate-50 to-slate-100 p-5 rounded-2xl border border-slate-100 shadow-sm relative overflow-hidden">
                                <div className="absolute right-0 top-0 w-32 h-32 bg-[#00A2BD] opacity-[0.03] rounded-full blur-2xl -mr-10 -mt-10"></div>
                                <div className="h-16 w-16 bg-gradient-to-br from-[#00A2BD] to-[#46D2E1] rounded-full flex items-center justify-center text-white text-2xl font-bold shadow-lg shadow-[#00A2BD]/30 z-10">
                                    {selectedUser.display_name?.charAt(0)}
                                </div>
                                <div className="z-10">
                                    <h3 className="text-xl font-bold text-slate-800">{selectedUser.display_name}</h3>
                                    <p className="text-xs text-slate-500 font-mono mt-1">{selectedUser.user_id}</p>
                                    <Badge className="mt-2 capitalize rounded-full px-3" variant={selectedUser.status === 'active' ? 'default' : 'destructive'}>
                                        {selectedUser.status}
                                    </Badge>
                                </div>
                            </div>

                            <div className="grid gap-3">
                                <div className="flex items-center gap-4 p-4 border border-slate-100 rounded-xl bg-white shadow-sm hover:border-[#00A2BD]/30 transition-colors">
                                    <div className="p-2.5 bg-blue-50 text-blue-500 rounded-lg"><Mail size={20} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Email Address</p>
                                        <p className="text-sm font-bold text-slate-700 mt-0.5">{selectedUser.email || 'Not Provided'}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-4 p-4 border border-slate-100 rounded-xl bg-white shadow-sm hover:border-[#00A2BD]/30 transition-colors">
                                    <div className="p-2.5 bg-emerald-50 text-emerald-500 rounded-lg"><Phone size={20} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Phone Contact</p>
                                        <p className="text-sm font-bold text-slate-700 mt-0.5">{selectedUser.phone_number}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-4 p-4 border border-slate-100 rounded-xl bg-white shadow-sm hover:border-[#00A2BD]/30 transition-colors">
                                    <div className="p-2.5 bg-purple-50 text-purple-500 rounded-lg"><Calendar size={20} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Joined Date</p>
                                        <p className="text-sm font-bold text-slate-700 mt-0.5">{selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleString() : '-'}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-4 p-4 border border-slate-100 rounded-xl bg-white shadow-sm hover:border-[#00A2BD]/30 transition-colors">
                                    <div className="p-2.5 bg-amber-50 text-amber-500 rounded-lg"><ShieldAlert size={20} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Account Classification</p>
                                        <p className="text-sm font-bold text-slate-700 mt-0.5">{selectedUser.minor_status === 'minor' ? 'Minor (Guardian Required)' : 'Standard (Adult)'}</p>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 border-t border-slate-100">
                                <h4 className="text-sm font-bold text-slate-800 mb-4">Activity Overview</h4>
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="bg-slate-50 border border-slate-100 p-4 rounded-xl text-center">
                                        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Trips</p>
                                        <p className="text-3xl font-extrabold text-[#00A2BD] mt-2">{selectedUser.trip_count}</p>
                                    </div>
                                    <div className="bg-slate-50 border border-slate-100 p-4 rounded-xl text-center">
                                        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Policy Strikes</p>
                                        <p className="text-3xl font-extrabold text-slate-700 mt-2">0</p>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 flex gap-3">
                                <Button className="flex-1 bg-gradient-to-r from-[#00A2BD] to-[#008196] hover:shadow-lg shadow-md text-white font-bold h-12 rounded-xl border-none">정보 수정</Button>
                                <Button variant="destructive" className="flex-1 h-12 rounded-xl font-bold shadow-sm" onClick={() => handleBanUser(selectedUser.user_id)}>계정 정지</Button>
                            </div>
                        </div>
                    )}
                </SheetContent>
            </Sheet>
        </div>
    );
}

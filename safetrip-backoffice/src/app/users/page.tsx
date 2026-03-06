'use client';

import { useState } from 'react';
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

export default function UsersPage() {
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
                return (
                    <Badge variant={status === 'active' ? 'default' : status === 'banned' ? 'destructive' : 'secondary'} className="capitalize">
                        {status}
                    </Badge>
                );
            },
        },
        {
            accessorKey: 'minor_status',
            header: '구분',
            cell: ({ row }) => {
                const isMinor = row.getValue('minor_status') === 'minor';
                return isMinor ? (
                    <Badge variant="outline" className="text-amber-600 border-amber-200 bg-amber-50">미성년자</Badge>
                ) : (
                    <span className="text-xs text-muted-foreground">성인</span>
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
        setSelectedUser(user);
        setIsSheetOpen(true);
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
        <div className="space-y-6">
            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
                    <Users className="h-6 w-6 text-[#00A2BD]" /> User Management
                </h1>
                <p className="text-muted-foreground">SafeTrip 서비스 사용자를 조회하고 관리합니다.</p>
            </div>

            {/* Filter & Search Bar */}
            <div className="flex items-center justify-between gap-4 bg-white p-4 rounded-xl border border-border shadow-sm">
                <div className="relative flex-1 max-w-sm">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input 
                        placeholder="이름, UID, 전화번호 검색..." 
                        className="pl-9"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
                <div className="flex items-center gap-2">
                    <Button variant="outline" size="sm" className="gap-2">
                        <Download className="h-4 w-4" /> Export CSV
                    </Button>
                    <Button variant="default" size="sm" className="bg-[#00A2BD] hover:bg-[#008196]" onClick={() => refetch()}>
                        Search
                    </Button>
                </div>
            </div>

            {/* Data Table */}
            <div className="bg-white rounded-xl border border-border shadow-sm p-1">
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
                            <div className="flex items-center gap-4 bg-muted/30 p-4 rounded-xl">
                                <div className="h-16 w-16 bg-[#00A2BD] rounded-full flex items-center justify-center text-white text-2xl font-bold">
                                    {selectedUser.display_name?.charAt(0)}
                                </div>
                                <div>
                                    <h3 className="text-lg font-bold">{selectedUser.display_name}</h3>
                                    <p className="text-sm text-muted-foreground font-mono">{selectedUser.user_id}</p>
                                    <Badge className="mt-2 capitalize" variant={selectedUser.status === 'active' ? 'default' : 'destructive'}>
                                        {selectedUser.status}
                                    </Badge>
                                </div>
                            </div>

                            <div className="grid gap-4">
                                <div className="flex items-center gap-3 p-3 border rounded-lg">
                                    <div className="p-2 bg-blue-50 text-blue-600 rounded-md"><Mail size={18} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs text-muted-foreground">이메일</p>
                                        <p className="text-sm font-medium">{selectedUser.email || '-'}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3 p-3 border rounded-lg">
                                    <div className="p-2 bg-green-50 text-green-600 rounded-md"><Phone size={18} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs text-muted-foreground">연락처</p>
                                        <p className="text-sm font-medium">{selectedUser.phone_number}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3 p-3 border rounded-lg">
                                    <div className="p-2 bg-purple-50 text-purple-600 rounded-md"><Calendar size={18} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs text-muted-foreground">가입일</p>
                                        <p className="text-sm font-medium">{selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleString() : '-'}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3 p-3 border rounded-lg">
                                    <div className="p-2 bg-amber-50 text-amber-600 rounded-md"><ShieldAlert size={18} /></div>
                                    <div className="flex-1">
                                        <p className="text-xs text-muted-foreground">미성년자 여부</p>
                                        <p className="text-sm font-medium">{selectedUser.minor_status === 'minor' ? '대상 (보호자 연동 필요)' : '일반 (성인)'}</p>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 border-t">
                                <h4 className="text-sm font-bold mb-3">최근 활동 요약</h4>
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="bg-muted/50 p-3 rounded-lg text-center">
                                        <p className="text-xs text-muted-foreground">진행한 여행</p>
                                        <p className="text-xl font-bold">{selectedUser.trip_count}</p>
                                    </div>
                                    <div className="bg-muted/50 p-3 rounded-lg text-center">
                                        <p className="text-xs text-muted-foreground">신고/제재</p>
                                        <p className="text-xl font-bold">0</p>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 flex gap-3">
                                <Button className="flex-1 bg-[#00A2BD] hover:bg-[#008196]">정보 수정</Button>
                                <Button variant="destructive" className="flex-1" onClick={() => handleBanUser(selectedUser.user_id)}>계정 정지</Button>
                            </div>
                        </div>
                    )}
                </SheetContent>
            </Sheet>
        </div>
    );
}

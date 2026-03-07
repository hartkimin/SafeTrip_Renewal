'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { userService } from '@/services/userService';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
    Dialog, DialogContent, DialogDescription,
    DialogFooter, DialogHeader, DialogTitle
} from '@/components/ui/dialog';
import {
    ArrowLeft, User, Mail, Phone, Calendar, Shield, Plane,
    CreditCard, AlertTriangle, History, MapPin, Ban, CircleCheck,
    Clock, FileText
} from 'lucide-react';
import { toast } from 'sonner';

const TABS = [
    { id: 'info', label: 'Basic Info', icon: User },
    { id: 'trips', label: 'Trip History', icon: Plane },
    { id: 'payments', label: 'Payments', icon: CreditCard },
    { id: 'guardians', label: 'Guardians', icon: Shield },
    { id: 'activity', label: 'Activity', icon: History },
    { id: 'ban', label: 'Ban History', icon: AlertTriangle },
];

export default function UserDetailPage() {
    const params = useParams();
    const router = useRouter();
    const queryClient = useQueryClient();
    const userId = params.id as string;
    const [activeTab, setActiveTab] = useState('info');
    const [banDialogOpen, setBanDialogOpen] = useState(false);
    const [banReason, setBanReason] = useState('');

    const { data: userData, isLoading } = useQuery({
        queryKey: ['user', userId],
        queryFn: () => userService.getUserDetail(userId),
    });

    const user: any = userData?.data || userData || {};

    const banMutation = useMutation({
        mutationFn: () => userService.banUser(userId, banReason),
        onSuccess: () => {
            toast.success('사용자가 차단되었습니다.');
            queryClient.invalidateQueries({ queryKey: ['user', userId] });
            setBanDialogOpen(false);
            setBanReason('');
        },
        onError: (err: any) => toast.error(`차단 실패: ${err.message}`),
    });

    if (isLoading) {
        return (
            <div className="animate-in fade-in duration-300 space-y-6">
                <div className="h-8 w-48 bg-slate-200 animate-pulse rounded-lg" />
                <div className="h-64 bg-slate-100 animate-pulse rounded-2xl" />
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 ease-out">
            {/* ─── Back + Header ─── */}
            <div className="flex items-center gap-4">
                <Button variant="ghost" size="sm" className="gap-2" onClick={() => router.push('/users')}>
                    <ArrowLeft size={16} /> Back to Users
                </Button>
            </div>

            {/* ─── Profile Card ─── */}
            <div className="glass-panel rounded-2xl p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-64 h-64 bg-teal-400 opacity-5 rounded-full blur-3xl -mr-20 -mt-20" />
                <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center gap-6">
                    <div className="h-20 w-20 bg-gradient-to-br from-[#00A2BD] to-[#46D2E1] rounded-2xl flex items-center justify-center text-white text-3xl font-bold shadow-lg shadow-[#00A2BD]/30">
                        {user.display_name?.charAt(0) || 'U'}
                    </div>
                    <div className="flex-1">
                        <h1 className="text-2xl font-extrabold text-slate-800 flex items-center gap-3">
                            {user.display_name || 'Unknown User'}
                            <Badge variant={user.status === 'active' ? 'default' : 'destructive'} className="capitalize">
                                {user.status || 'unknown'}
                            </Badge>
                            {user.minor_status === 'minor' && (
                                <Badge variant="outline" className="text-amber-600 border-amber-200 bg-amber-50">미성년자</Badge>
                            )}
                        </h1>
                        <p className="text-sm text-slate-500 font-mono mt-1">{user.user_id || userId}</p>
                    </div>
                    <div className="flex gap-3">
                        <Button variant="outline" className="gap-2 rounded-xl" onClick={() => toast.info('Edit feature coming soon')}>
                            <FileText size={16} /> Edit
                        </Button>
                        <Button variant="destructive" className="gap-2 rounded-xl" onClick={() => setBanDialogOpen(true)}>
                            <Ban size={16} /> Ban User
                        </Button>
                    </div>
                </div>
            </div>

            {/* ─── Tab Navigation ─── */}
            <div className="flex gap-2 overflow-x-auto pb-2">
                {TABS.map(tab => {
                    const Icon = tab.icon;
                    return (
                        <button
                            key={tab.id}
                            className={`flex items-center gap-2 px-5 py-3 rounded-xl text-sm font-bold transition-all whitespace-nowrap
                                ${activeTab === tab.id
                                    ? 'bg-gradient-to-r from-[#00A2BD] to-[#008196] text-white shadow-md shadow-[#00A2BD]/20'
                                    : 'bg-white/60 text-slate-600 hover:bg-white hover:shadow-sm border border-slate-100'
                                }`}
                            onClick={() => setActiveTab(tab.id)}
                        >
                            <Icon size={16} /> {tab.label}
                        </button>
                    );
                })}
            </div>

            {/* ─── Tab Content ─── */}
            <div className="glass-panel rounded-2xl p-8">
                {activeTab === 'info' && (
                    <div className="grid md:grid-cols-2 gap-6">
                        {[
                            { icon: Mail, label: 'Email', value: user.email || 'Not Provided', color: 'blue' },
                            { icon: Phone, label: 'Phone', value: user.phone_number || '-', color: 'emerald' },
                            { icon: Calendar, label: 'Joined', value: user.created_at ? new Date(user.created_at).toLocaleDateString() : '-', color: 'purple' },
                            { icon: Shield, label: 'Classification', value: user.minor_status === 'minor' ? 'Minor (Guardian Required)' : 'Adult', color: 'amber' },
                            { icon: Plane, label: 'Total Trips', value: user.trip_count || 0, color: 'teal' },
                            { icon: MapPin, label: 'Last Location', value: user.last_location || 'Unknown', color: 'rose' },
                        ].map((item, i) => {
                            const Icon = item.icon;
                            return (
                                <div key={i} className="flex items-center gap-4 p-5 border border-slate-100 rounded-xl bg-white/50 shadow-sm hover:border-[#00A2BD]/30 transition-colors">
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

                {activeTab === 'trips' && (
                    <div className="space-y-4">
                        <h3 className="text-lg font-bold text-slate-800">Travel History</h3>
                        <div className="text-center py-12 text-slate-400">
                            <Plane size={48} className="mx-auto mb-4 opacity-30" />
                            <p className="font-medium">여행 이력은 API 연동 후 표시됩니다.</p>
                            <p className="text-sm mt-1">사용자별 여행 조회 API가 구현되면 자동으로 데이터가 표시됩니다.</p>
                        </div>
                    </div>
                )}

                {activeTab === 'payments' && (
                    <div className="space-y-4">
                        <h3 className="text-lg font-bold text-slate-800">Payment History</h3>
                        <div className="text-center py-12 text-slate-400">
                            <CreditCard size={48} className="mx-auto mb-4 opacity-30" />
                            <p className="font-medium">결제 이력은 API 연동 후 표시됩니다.</p>
                        </div>
                    </div>
                )}

                {activeTab === 'guardians' && (
                    <div className="space-y-4">
                        <h3 className="text-lg font-bold text-slate-800">Guardian Connections</h3>
                        <div className="text-center py-12 text-slate-400">
                            <Shield size={48} className="mx-auto mb-4 opacity-30" />
                            <p className="font-medium">보호자 연결 정보는 API 연동 후 표시됩니다.</p>
                        </div>
                    </div>
                )}

                {activeTab === 'activity' && (
                    <div className="space-y-4">
                        <h3 className="text-lg font-bold text-slate-800">Activity Log</h3>
                        <div className="space-y-3">
                            {[
                                { action: 'Login', time: '2 hours ago', icon: CircleCheck, color: 'emerald' },
                                { action: 'Profile Updated', time: '1 day ago', icon: User, color: 'blue' },
                                { action: 'Trip Created', time: '3 days ago', icon: Plane, color: 'teal' },
                            ].map((log, i) => {
                                const LogIcon = log.icon;
                                return (
                                    <div key={i} className="flex items-center gap-4 p-4 rounded-xl bg-slate-50 border border-slate-100">
                                        <div className={`p-2 bg-${log.color}-100 text-${log.color}-600 rounded-lg`}><LogIcon size={16} /></div>
                                        <span className="font-medium text-slate-700 flex-1">{log.action}</span>
                                        <span className="text-xs text-slate-400 flex items-center gap-1"><Clock size={12} /> {log.time}</span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                )}

                {activeTab === 'ban' && (
                    <div className="space-y-4">
                        <h3 className="text-lg font-bold text-slate-800">Ban History</h3>
                        {user.status === 'banned' ? (
                            <div className="p-6 rounded-xl bg-red-50 border border-red-200">
                                <div className="flex items-center gap-3 mb-3">
                                    <Ban size={20} className="text-red-600" />
                                    <span className="font-bold text-red-700">Currently Banned</span>
                                </div>
                                <p className="text-sm text-red-600">This user is currently under suspension.</p>
                            </div>
                        ) : (
                            <div className="text-center py-12 text-slate-400">
                                <CircleCheck size={48} className="mx-auto mb-4 text-emerald-400 opacity-50" />
                                <p className="font-medium">차단 이력이 없습니다.</p>
                            </div>
                        )}
                    </div>
                )}
            </div>

            {/* ─── Ban Dialog ─── */}
            <Dialog open={banDialogOpen} onOpenChange={setBanDialogOpen}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>사용자 차단</DialogTitle>
                        <DialogDescription>
                            {user.display_name} 사용자를 차단합니다. 차단 사유를 입력해주세요.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="py-4">
                        <Input
                            placeholder="차단 사유 (예: 서비스 악용, 허위 SOS 발생 등)"
                            value={banReason}
                            onChange={(e) => setBanReason(e.target.value)}
                        />
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setBanDialogOpen(false)}>취소</Button>
                        <Button variant="destructive" onClick={() => banMutation.mutate()} disabled={banMutation.isPending || !banReason}>
                            {banMutation.isPending ? '처리 중...' : '차단 확인'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}

'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { authService } from '@/services/authService';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { toast } from 'sonner';
import { ShieldCheck, Loader2, Plane, Globe, Shield, Lock } from 'lucide-react';

const loginSchema = z.object({
    email: z.string().email({ message: '유효한 이메일 주소를 입력해주세요.' }),
    password: z.string().min(6, { message: '비밀번호는 최소 6자 이상이어야 합니다.' }),
});

type LoginFormValues = z.infer<typeof loginSchema>;

export default function LoginPage() {
    const router = useRouter();
    const [isLoading, setIsLoading] = useState(false);

    const form = useForm<LoginFormValues>({
        resolver: zodResolver(loginSchema),
        defaultValues: {
            email: '',
            password: '',
        },
    });

    async function onSubmit(values: LoginFormValues) {
        setIsLoading(true);
        try {
            await authService.devLogin(values.email);
            toast.success('로그인 성공', {
                description: 'SafeTrip 관리자 대시보드로 이동합니다.',
            });
            router.push('/');
        } catch (error: any) {
            toast.error('로그인 실패', {
                description: error.message || '이메일 또는 비밀번호를 확인해주세요.',
            });
        } finally {
            setIsLoading(false);
        }
    }

    return (
        <div className="flex min-h-screen bg-[#F6F8FA] overflow-hidden">
            {/* Left Decorative Side (SafeTrip Brand) */}
            <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-[#00A2BD] via-[#015572] to-[#0A1628] relative items-center justify-center p-12">
                <div className="absolute inset-0 opacity-10 bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')]"></div>
                <div className="relative z-10 w-full max-w-lg space-y-8 text-white">
                    <div className="flex items-center gap-3">
                        <div className="w-12 h-12 bg-white/20 backdrop-blur-md rounded-2xl flex items-center justify-center border border-white/30">
                            <Plane className="text-white" size={28} />
                        </div>
                        <h1 className="text-3xl font-extrabold tracking-tight">SafeTrip <span className="text-[#13ECCF]">Admin</span></h1>
                    </div>
                    
                    <div className="space-y-6">
                        <h2 className="text-4xl font-bold leading-tight">
                            당신의 여정을 <br />
                            <span className="text-[#13ECCF]">더 안전하게</span> 관리하세요.
                        </h2>
                        <p className="text-white/70 text-lg leading-relaxed max-w-md">
                            SafeTrip 백오피스는 실시간 SOS 관제, 사용자 관리 및 B2B 파트너 협업을 위한 통합 관리 시스템입니다.
                        </p>
                    </div>

                    <div className="grid grid-cols-2 gap-6 pt-8">
                        <div className="bg-white/10 backdrop-blur-sm p-4 rounded-2xl border border-white/10">
                            <Shield className="text-[#13ECCF] mb-3" size={24} />
                            <h3 className="font-bold text-sm">실시간 관제</h3>
                            <p className="text-xs text-white/60 mt-1">24/7 SOS 이벤트 모니터링</p>
                        </div>
                        <div className="bg-white/10 backdrop-blur-sm p-4 rounded-2xl border border-white/10">
                            <Globe className="text-[#13ECCF] mb-3" size={24} />
                            <h3 className="font-bold text-sm">글로벌 서비스</h3>
                            <p className="text-xs text-white/60 mt-1">전 세계 여행 데이터 통합 관리</p>
                        </div>
                    </div>
                </div>
                
                {/* Decorative Circles */}
                <div className="absolute top-[-10%] right-[-10%] w-[40%] h-[40%] bg-[#13ECCF]/20 rounded-full blur-[120px]"></div>
                <div className="absolute bottom-[-10%] left-[-10%] w-[40%] h-[40%] bg-[#00A2BD]/30 rounded-full blur-[120px]"></div>
            </div>

            {/* Right Side (Login Form) */}
            <div className="flex-1 flex flex-col items-center justify-center p-6 lg:p-12 relative">
                <div className="w-full max-w-md space-y-8">
                    <div className="lg:hidden flex flex-col items-center text-center space-y-2 mb-8">
                        <div className="w-16 h-16 bg-gradient-to-br from-[#00A2BD] to-[#13ECCF] rounded-2xl flex items-center justify-center shadow-lg mb-4">
                            <Plane className="text-white" size={32} />
                        </div>
                        <h1 className="text-3xl font-black text-[#1A1A2E]">SafeTrip</h1>
                        <p className="text-muted-foreground">관리자 시스템 로그인</p>
                    </div>

                    <div className="space-y-2 text-center lg:text-left mb-8 hidden lg:block">
                        <h3 className="text-2xl font-bold text-[#1A1A2E]">환영합니다!</h3>
                        <p className="text-muted-foreground">계정 정보를 입력하여 대시보드에 접속하세요.</p>
                    </div>

                    <Card className="border-none shadow-none bg-transparent">
                        <CardContent className="p-0">
                            <Form {...form}>
                                <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5">
                                    <FormField
                                        control={form.control}
                                        name="email"
                                        render={({ field }) => (
                                            <FormItem className="space-y-1.5">
                                                <FormLabel className="text-xs font-bold text-slate-500 uppercase tracking-wider">이메일 주소</FormLabel>
                                                <FormControl>
                                                    <div className="relative group">
                                                        <Input 
                                                            placeholder="admin@safetrip.com" 
                                                            {...field} 
                                                            disabled={isLoading} 
                                                            className="h-12 bg-white border-slate-200 rounded-xl focus:border-[#00A2BD] focus:ring-[#00A2BD]/20 transition-all pl-11"
                                                        />
                                                        <Globe className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-[#00A2BD] transition-colors" size={18} />
                                                    </div>
                                                </FormControl>
                                                <FormMessage className="text-[11px]" />
                                            </FormItem>
                                        )}
                                    />
                                    <FormField
                                        control={form.control}
                                        name="password"
                                        render={({ field }) => (
                                            <FormItem className="space-y-1.5">
                                                <FormLabel className="text-xs font-bold text-slate-500 uppercase tracking-wider">비밀번호</FormLabel>
                                                <FormControl>
                                                    <div className="relative group">
                                                        <Input 
                                                            type="password" 
                                                            placeholder="••••••••" 
                                                            {...field} 
                                                            disabled={isLoading} 
                                                            className="h-12 bg-white border-slate-200 rounded-xl focus:border-[#00A2BD] focus:ring-[#00A2BD]/20 transition-all pl-11"
                                                        />
                                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-[#00A2BD] transition-colors" size={18} />
                                                    </div>
                                                </FormControl>
                                                <FormMessage className="text-[11px]" />
                                            </FormItem>
                                        )}
                                    />
                                    
                                    <div className="flex items-center justify-between py-2">
                                        <div className="flex items-center gap-2">
                                            <input type="checkbox" id="remember" className="rounded border-slate-300 text-[#00A2BD] focus:ring-[#00A2BD]" />
                                            <label htmlFor="remember" className="text-sm text-slate-500 cursor-pointer">로그인 기억하기</label>
                                        </div>
                                        <button type="button" className="text-sm font-semibold text-[#00A2BD] hover:underline">비밀번호 찾기</button>
                                    </div>

                                    <Button 
                                        className="w-full bg-[#00A2BD] hover:bg-[#015572] text-white h-14 rounded-xl text-lg font-bold shadow-lg shadow-[#00A2BD]/20 transition-all" 
                                        type="submit" 
                                        disabled={isLoading}
                                    >
                                        {isLoading ? (
                                            <>
                                                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                                                보안 연결 중...
                                            </>
                                        ) : (
                                            '로그인'
                                        )}
                                    </Button>
                                </form>
                            </Form>
                        </CardContent>
                    </Card>

                    <div className="pt-12 text-center">
                        <p className="text-sm text-slate-400 flex items-center justify-center gap-2">
                            <ShieldCheck size={16} /> 
                            관리 시스템은 승인된 인원만 이용할 수 있습니다.
                        </p>
                        <p className="text-[10px] text-slate-300 mt-4 uppercase tracking-[0.2em]">
                            © 2026 SAFETRIP SECURITY TEAM. ALL RIGHTS RESERVED.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
}

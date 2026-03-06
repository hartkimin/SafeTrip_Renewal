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
import { ShieldCheck, Loader2 } from 'lucide-react';

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
            // Real production would use Firebase Auth here to get a token
            // For now, we use devLogin to demonstrate the flow
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
        <div className="flex items-center justify-center min-h-screen bg-[#F6F8FA]">
            <Card className="w-full max-w-md shadow-lg border-none">
                <CardHeader className="space-y-1 flex flex-col items-center">
                    <div className="w-12 h-12 bg-[#00A2BD] rounded-xl flex items-center justify-center mb-4 text-white">
                        <ShieldCheck size={28} />
                    </div>
                    <CardTitle className="text-2xl font-bold tracking-tight">SafeTrip Backoffice</CardTitle>
                    <CardDescription>
                        관리자 계정으로 로그인하여 시스템을 관리하세요.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Form {...form}>
                        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                            <FormField
                                control={form.control}
                                name="email"
                                render={({ field }) => (
                                    <FormItem>
                                        <FormLabel>이메일</FormLabel>
                                        <FormControl>
                                            <Input placeholder="admin@safetrip.com" {...field} disabled={isLoading} />
                                        </FormControl>
                                        <FormMessage />
                                    </FormItem>
                                )}
                            />
                            <FormField
                                control={form.control}
                                name="password"
                                render={({ field }) => (
                                    <FormItem>
                                        <FormLabel>비밀번호</FormLabel>
                                        <FormControl>
                                            <Input type="password" placeholder="••••••" {...field} disabled={isLoading} />
                                        </FormControl>
                                        <FormMessage />
                                    </FormItem>
                                )}
                            />
                            <Button className="w-full bg-[#00A2BD] hover:bg-[#008196] text-white py-6 text-base" type="submit" disabled={isLoading}>
                                {isLoading ? (
                                    <>
                                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                        로그인 중...
                                    </>
                                ) : (
                                    '로그인'
                                )}
                            </Button>
                        </form>
                    </Form>
                </CardContent>
                <CardFooter className="flex flex-col space-y-4 text-center">
                    <p className="text-xs text-muted-foreground">
                        본 시스템은 권한이 부여된 관리자만 접근 가능합니다.<br />
                        모든 활동은 보안 정책에 따라 기록 및 모니터링됩니다.
                    </p>
                </CardFooter>
            </Card>
        </div>
    );
}

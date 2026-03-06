'use client';

import { usePathname, useRouter } from 'next/navigation';
import {
    LayoutDashboard, Siren, Users, Plane, Building2,
    CreditCard, Settings, ClipboardList, Bell, Search,
    LogOut, User
} from 'lucide-react';
import { auth } from '@/lib/auth';
import { authService } from '@/services/authService';
import { 
    DropdownMenu, 
    DropdownMenuContent, 
    DropdownMenuItem, 
    DropdownMenuLabel, 
    DropdownMenuSeparator, 
    DropdownMenuTrigger 
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';

const NAV_ITEMS = [
    {
        section: 'Overview', items: [
            { href: '/', icon: LayoutDashboard, label: 'Dashboard' },
        ]
    },
    {
        section: 'Emergency', items: [
            { href: '/sos', icon: Siren, label: 'SOS Center', highlight: true },
        ]
    },
    {
        section: 'Management', items: [
            { href: '/users', icon: Users, label: 'Users' },
            { href: '/trips', icon: Plane, label: 'Trips & Groups' },
            { href: '/b2b', icon: Building2, label: 'B2B Partners' },
        ]
    },
    {
        section: 'Finance', items: [
            { href: '/finance', icon: CreditCard, label: 'Billing & Finance' },
        ]
    },
    {
        section: 'System', items: [
            { href: '/settings', icon: Settings, label: 'Settings' },
            { href: '/audit', icon: ClipboardList, label: 'Audit Logs' },
        ]
    },
];

export function Sidebar() {
    const pathname = usePathname();
    const user = auth.getUser();

    return (
        <aside className="sidebar">
            <div className="sidebar-header">
                <div className="logo-icon">ST</div>
                <h2>SafeTrip Admin</h2>
            </div>
            <nav className="sidebar-nav">
                {NAV_ITEMS.map(section => (
                    <div key={section.section}>
                        <div className="nav-section-title">{section.section}</div>
                        {section.items.map(item => {
                            const Icon = item.icon;
                            const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
                            return (
                                <a
                                    key={item.href}
                                    href={item.href}
                                    className={`nav-item ${item.highlight ? 'sos-highlight' : ''} ${isActive ? 'active' : ''}`}
                                >
                                    <span className="nav-icon"><Icon size={18} strokeWidth={2} /></span>
                                    {item.label}
                                </a>
                            );
                        })}
                    </div>
                ))}
            </nav>
            <div className="sidebar-footer">
                <div className="admin-profile">
                    <div className="admin-avatar">
                        {user?.name?.substring(0, 2).toUpperCase() || 'AD'}
                    </div>
                    <div className="admin-info">
                        <div className="admin-name">{user?.name || 'Admin'}</div>
                        <div className="admin-role">{user?.role === 'super_admin' ? 'Super Admin' : 'Staff'}</div>
                    </div>
                </div>
            </div>
        </aside>
    );
}

export function Topbar() {
    const router = useRouter();
    const user = auth.getUser();

    const handleLogout = async () => {
        await authService.logout();
    };

    return (
        <header className="topbar">
            <div className="topbar-search">
                <Search size={16} strokeWidth={2} className="search-icon" />
                <input type="text" placeholder="Search users, trips, SOS events..." />
            </div>
            <div className="topbar-actions">
                <button className="notification-btn"><Bell size={20} strokeWidth={2} /></button>
                
                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <button className="profile-img cursor-pointer">
                            {user?.name?.substring(0, 2).toUpperCase() || 'AD'}
                        </button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-56">
                        <DropdownMenuLabel>내 계정</DropdownMenuLabel>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem className="cursor-pointer">
                            <User className="mr-2 h-4 w-4" />
                            <span>프로필 설정</span>
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem className="text-red-600 cursor-pointer" onClick={handleLogout}>
                            <LogOut className="mr-2 h-4 w-4" />
                            <span>로그아웃</span>
                        </DropdownMenuItem>
                    </DropdownMenuContent>
                </DropdownMenu>
            </div>
        </header>
    );
}

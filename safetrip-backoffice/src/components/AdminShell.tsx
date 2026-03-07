'use client';

import { useState, useEffect } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import {
    LayoutDashboard, Siren, Users, Plane, Building2,
    CreditCard, Settings, ClipboardList, Bell, Search,
    LogOut, User, TerminalSquare, BarChart3, FileText,
    ChevronLeft, ChevronRight, Menu, X, Moon, Sun
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
        section: 'Operations', items: [
            { href: '/sos', icon: Siren, label: 'SOS Center', highlight: true, badge: true },
            { href: '/users', icon: Users, label: 'User Management' },
            { href: '/trips', icon: Plane, label: 'Trip Management' },
            { href: '/finance', icon: CreditCard, label: 'Finance' },
        ]
    },
    {
        section: 'Partners', items: [
            { href: '/b2b', icon: Building2, label: 'B2B Partners' },
        ]
    },
    {
        section: 'Analytics', items: [
            { href: '/analytics', icon: BarChart3, label: 'Analytics' },
            { href: '/audit', icon: ClipboardList, label: 'Audit Logs' },
        ]
    },
    {
        section: 'System', items: [
            { href: '/settings', icon: Settings, label: 'Settings' },
            { href: '/api-explorer', icon: TerminalSquare, label: 'API Explorer' },
        ]
    },
];

interface SidebarProps {
    collapsed: boolean;
    onToggle: () => void;
    mobileOpen: boolean;
    onMobileClose: () => void;
}

export function Sidebar({ collapsed, onToggle, mobileOpen, onMobileClose }: SidebarProps) {
    const pathname = usePathname();
    const user = auth.getUser();

    return (
        <>
            {/* Mobile overlay */}
            {mobileOpen && (
                <div
                    className="fixed inset-0 bg-black/40 backdrop-blur-sm z-40 lg:hidden"
                    onClick={onMobileClose}
                />
            )}

            <aside className={`sidebar ${collapsed ? 'sidebar-collapsed' : ''} ${mobileOpen ? 'sidebar-mobile-open' : ''}`}>
                {/* Header */}
                <div className="sidebar-header">
                    <div className="logo-icon">ST</div>
                    {!collapsed && <h2>SafeTrip Admin</h2>}
                    <button
                        className="sidebar-toggle hidden lg:flex"
                        onClick={onToggle}
                        title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
                    >
                        {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
                    </button>
                    <button
                        className="sidebar-toggle lg:hidden"
                        onClick={onMobileClose}
                    >
                        <X size={16} />
                    </button>
                </div>

                {/* Navigation */}
                <nav className="sidebar-nav">
                    {NAV_ITEMS.map(section => (
                        <div key={section.section}>
                            {!collapsed && <div className="nav-section-title">{section.section}</div>}
                            {section.items.map(item => {
                                const Icon = item.icon;
                                const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
                                return (
                                    <a
                                        key={item.href}
                                        href={item.href}
                                        className={`nav-item ${item.highlight ? 'sos-highlight' : ''} ${isActive ? 'active' : ''}`}
                                        title={collapsed ? item.label : undefined}
                                        onClick={onMobileClose}
                                    >
                                        <span className="nav-icon"><Icon size={18} strokeWidth={2} /></span>
                                        {!collapsed && item.label}
                                        {item.badge && !collapsed && (
                                            <span className="sos-badge" id="sos-nav-badge">0</span>
                                        )}
                                        {item.badge && collapsed && (
                                            <span className="sos-badge-mini" id="sos-nav-badge-mini"></span>
                                        )}
                                    </a>
                                );
                            })}
                        </div>
                    ))}
                </nav>

                {/* Footer */}
                <div className="sidebar-footer">
                    {!collapsed ? (
                        <div className="admin-profile">
                            <div className="admin-avatar">
                                {user?.name?.substring(0, 2).toUpperCase() || 'AD'}
                            </div>
                            <div className="admin-info">
                                <div className="admin-name">{user?.name || 'Admin'}</div>
                                <div className="admin-role">{user?.role === 'super_admin' ? 'Super Admin' : 'Staff'}</div>
                            </div>
                        </div>
                    ) : (
                        <div className="admin-avatar mx-auto" title={user?.name || 'Admin'}>
                            {user?.name?.substring(0, 2).toUpperCase() || 'AD'}
                        </div>
                    )}
                </div>
            </aside>
        </>
    );
}

export function Topbar({ onMenuClick }: { onMenuClick?: () => void }) {
    const router = useRouter();
    const user = auth.getUser();
    const [searchFocused, setSearchFocused] = useState(false);

    const handleLogout = async () => {
        await authService.logout();
    };

    return (
        <header className="topbar">
            {/* Mobile menu button */}
            <button className="topbar-menu-btn lg:hidden" onClick={onMenuClick}>
                <Menu size={20} strokeWidth={2} />
            </button>

            {/* Search */}
            <div className={`topbar-search ${searchFocused ? 'focused' : ''}`}>
                <Search size={18} strokeWidth={2} className="search-icon" />
                <input
                    type="text"
                    placeholder="Search users, trips, SOS events... (⌘K)"
                    onFocus={() => setSearchFocused(true)}
                    onBlur={() => setSearchFocused(false)}
                />
            </div>

            {/* Actions */}
            <div className="topbar-actions">
                {/* Notification bell */}
                <button className="notification-btn" title="Notifications">
                    <Bell size={20} strokeWidth={2} />
                    <span className="notification-badge" id="notification-count" style={{ display: 'none' }}>0</span>
                </button>

                {/* User menu */}
                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <div className="cursor-pointer flex items-center gap-3 bg-white/50 hover:bg-white/80 border border-border/50 pl-2 pr-4 py-1.5 rounded-full transition-all shadow-sm">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#00A2BD] to-[#46D2E1] flex items-center justify-center text-white font-bold text-xs shadow-inner">
                                {user?.name?.substring(0, 2).toUpperCase() || 'AD'}
                            </div>
                            <span className="text-sm font-bold text-slate-700 hidden sm:inline">{user?.name || 'Admin'}</span>
                        </div>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-56 mt-2 rounded-xl p-2 shadow-xl border-slate-100">
                        <DropdownMenuLabel className="font-bold text-slate-500 text-xs uppercase tracking-wider">My Account</DropdownMenuLabel>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem className="cursor-pointer rounded-md focus:bg-[#00A2BD]/10 focus:text-[#00A2BD] py-2">
                            <User className="mr-3 h-4 w-4" />
                            <span className="font-semibold">Profile Settings</span>
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem className="text-red-600 focus:text-red-700 cursor-pointer rounded-md focus:bg-red-50 py-2" onClick={handleLogout}>
                            <LogOut className="mr-3 h-4 w-4" />
                            <span className="font-semibold">Log out</span>
                        </DropdownMenuItem>
                    </DropdownMenuContent>
                </DropdownMenu>
            </div>
        </header>
    );
}

/**
 * AdminLayout wraps all pages with Sidebar + Topbar.
 * Manages sidebar collapse/expand and mobile drawer state.
 */
export function AdminLayout({ children }: { children: React.ReactNode }) {
    const [collapsed, setCollapsed] = useState(false);
    const [mobileOpen, setMobileOpen] = useState(false);

    // Auto-collapse on smaller screens
    useEffect(() => {
        const handleResize = () => {
            if (window.innerWidth < 1024) {
                setCollapsed(true);
                setMobileOpen(false);
            }
        };
        handleResize();
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    return (
        <div className={`admin-container ${collapsed ? 'sidebar-is-collapsed' : ''}`}>
            <Sidebar
                collapsed={collapsed}
                onToggle={() => setCollapsed(!collapsed)}
                mobileOpen={mobileOpen}
                onMobileClose={() => setMobileOpen(false)}
            />
            <div className="main-content">
                <Topbar onMenuClick={() => setMobileOpen(true)} />
                <div className="content-wrapper">
                    {children}
                </div>
            </div>
        </div>
    );
}

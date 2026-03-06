'use client';

/**
 * SafeTrip Backoffice — Lucide Icon Components
 * Centralized icon exports for premium, consistent SVG icons across all pages.
 */

import {
    LayoutDashboard,
    ShieldAlert,
    Users,
    Plane,
    Building2,
    CreditCard,
    Settings,
    ClipboardList,
    Bell,
    Search,
    RefreshCw,
    MapPin,
    Map,
    Globe,
    Phone,
    CircleCheck,
    AlertTriangle,
    DollarSign,
    FileText,
    UserX,
    UserCheck,
    TrendingUp,
    TrendingDown,
    Handshake,
    School,
    Download,
    ChevronRight,
    ChevronLeft,
    X,
    Plus,
    Eye,
    Ban,
    Battery,
    Wifi,
    Clock,
    Calendar,
    CircleAlert,
    Siren,
    Shield,
    Activity,
    Loader2,
} from 'lucide-react';

// ─── Sidebar Navigation Icons ───
export const NavIcons = {
    dashboard: LayoutDashboard,
    sos: Siren,
    users: Users,
    trips: Plane,
    b2b: Building2,
    finance: CreditCard,
    settings: Settings,
    audit: ClipboardList,
};

// ─── Topbar Icons ───
export const TopbarIcons = {
    search: Search,
    notification: Bell,
};

// ─── Page Title Icons ───
export const PageIcons = {
    dashboard: LayoutDashboard,
    sos: ShieldAlert,
    users: Users,
    trips: Plane,
    b2b: Building2,
    finance: DollarSign,
    settings: Settings,
    audit: ClipboardList,
};

// ─── Action Icons ───
export const ActionIcons = {
    refresh: RefreshCw,
    export: Download,
    add: Plus,
    close: X,
    view: Eye,
    ban: Ban,
    search: Search,
};

// ─── Status / Stat Icons ───
export const StatIcons = {
    alert: CircleAlert,
    activeTrips: Plane,
    users: Users,
    partners: Building2,
    revenue: DollarSign,
    trending: TrendingUp,
    trendingDown: TrendingDown,
    resolved: CircleCheck,
    inProgress: Activity,
    clock: Clock,
    warning: AlertTriangle,
    calendar: Calendar,
    shield: Shield,
};

// ─── Feature / Context Icons ───
export const FeatureIcons = {
    map: Map,
    mapPin: MapPin,
    globe: Globe,
    phone: Phone,
    battery: Battery,
    wifi: Wifi,
    file: FileText,
    handshake: Handshake,
    school: School,
    userCheck: UserCheck,
    userX: UserX,
    siren: Siren,
    loading: Loader2,
};

// ─── Empty State Icons ───
export const EmptyIcons = {
    noData: Globe,
    noUsers: Users,
    noTrips: Plane,
    noSos: CircleCheck,
    noPayments: CreditCard,
    noPartners: Building2,
    noLogs: ClipboardList,
    noEmergency: Shield,
    select: ChevronRight,
};

// Re-export individual icons for direct usage
export {
    LayoutDashboard,
    ShieldAlert,
    Users,
    Plane,
    Building2,
    CreditCard,
    Settings,
    ClipboardList,
    Bell,
    Search,
    RefreshCw,
    MapPin,
    Map,
    Globe,
    Phone,
    CircleCheck,
    AlertTriangle,
    DollarSign,
    FileText,
    UserX,
    UserCheck,
    TrendingUp,
    Download,
    Handshake,
    School,
    ChevronRight,
    ChevronLeft,
    X,
    Plus,
    Eye,
    Ban,
    Battery,
    Wifi,
    Clock,
    Calendar,
    CircleAlert,
    Siren,
    Shield,
    Activity,
    Loader2,
};

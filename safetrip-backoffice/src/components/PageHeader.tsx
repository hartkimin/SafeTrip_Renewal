'use client';

import { ReactNode, ElementType } from 'react';

interface PageHeaderProps {
    icon: ElementType;
    iconBg?: string;   // e.g. 'bg-teal-100', 'bg-red-100', 'bg-emerald-100'
    iconColor?: string; // e.g. 'text-teal-600', 'text-red-600'
    glowColor?: string; // e.g. 'bg-teal-400', 'bg-red-400'
    title: string;
    subtitle: string;
    actions?: ReactNode;
}

export function PageHeader({
    icon: Icon,
    iconBg = 'bg-teal-50',
    iconColor = 'text-teal-600',
    glowColor = 'bg-teal-400',
    title,
    subtitle,
    actions,
}: PageHeaderProps) {
    return (
        <div className="page-header stagger-1" style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.95), rgba(248,250,252,0.9))' }}>
            <div className={`header-glow ${glowColor}`} />
            <div className="flex items-center justify-between relative z-10">
                <div className="flex items-center gap-5">
                    <div className={`header-icon ${iconBg} ${iconColor}`}>
                        <Icon className="w-6 h-6" />
                    </div>
                    <div>
                        <h1 className="header-title">{title}</h1>
                        <p className="header-subtitle">{subtitle}</p>
                    </div>
                </div>
                {actions && <div className="flex items-center gap-3">{actions}</div>}
            </div>
        </div>
    );
}

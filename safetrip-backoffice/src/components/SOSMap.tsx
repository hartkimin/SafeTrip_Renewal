'use client';

import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Fix default marker icons (Leaflet + Next.js/Webpack common issue)
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// Custom SOS marker icon
const sosIcon = new L.DivIcon({
    className: 'sos-marker',
    html: `<div style="
    width: 32px; height: 32px;
    background: #D32F2F;
    border: 3px solid #fff;
    border-radius: 50%;
    box-shadow: 0 2px 8px rgba(211,47,47,0.5);
    display: flex; align-items: center; justify-content: center;
    animation: sosPulse 1.5s ease-in-out infinite;
  "><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg></div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
    popupAnchor: [0, -18],
});

const resolvedIcon = new L.DivIcon({
    className: 'sos-marker-resolved',
    html: `<div style="
    width: 28px; height: 28px;
    background: #2E9F65;
    border: 3px solid #fff;
    border-radius: 50%;
    box-shadow: 0 2px 6px rgba(46,159,101,0.4);
    display: flex; align-items: center; justify-content: center;
  "><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    popupAnchor: [0, -16],
});

/**
 * SOSMap — OpenStreetMap component for SOS Live Map
 *
 * @param {Object} props
 * @param {Array} props.events — SOS events: [{ id, user, location, lat, lng, status, time, battery }]
 * @param {Function} props.onEventClick — callback when a marker is clicked
 * @param {Object} props.style — container style overrides
 */
interface SOSMapProps {
    events?: any[];
    onEventClick?: (event: any) => void;
    style?: React.CSSProperties;
}

export default function SOSMap({ events = [], onEventClick, style }: SOSMapProps) {
    const mapRef = useRef(null);
    const mapInstance = useRef(null);
    const markersRef = useRef([]);

    // Initialize map
    useEffect(() => {
        if (mapInstance.current) return;

        mapInstance.current = L.map(mapRef.current, {
            center: [36.5, 127.5], // South Korea center
            zoom: 7,
            zoomControl: true,
            attributionControl: true,
        });

        // OSM tile layer
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom: 19,
        }).addTo(mapInstance.current);

        // Cleanup
        return () => {
            if (mapInstance.current) {
                mapInstance.current.remove();
                mapInstance.current = null;
            }
        };
    }, []);

    // Update markers when events change
    useEffect(() => {
        if (!mapInstance.current) return;

        // Clear existing markers
        markersRef.current.forEach(m => m.remove());
        markersRef.current = [];

        const validEvents = events.filter(e => e.lat && e.lng);

        validEvents.forEach(event => {
            const isActive = event.status === 'ACTIVE' || event.status === 'active';
            const icon = isActive ? sosIcon : resolvedIcon;

            const marker = L.marker([event.lat, event.lng], { icon })
                .addTo(mapInstance.current)
                .bindPopup(`
          <div style="min-width:180px;font-family:'Plus Jakarta Sans',sans-serif;">
            <div style="font-weight:700;font-size:14px;margin-bottom:6px;">${event.user || 'Unknown'}</div>
            <div style="font-size:12px;color:#666;margin-bottom:4px;">📍 ${event.location || '-'}</div>
            <div style="font-size:12px;color:#666;margin-bottom:4px;">🕐 ${event.time || '-'}</div>
            <div style="font-size:12px;color:#666;margin-bottom:8px;">🔋 ${event.battery || '-'}</div>
            <span style="
              display:inline-block;
              padding:3px 10px;
              border-radius:12px;
              font-size:11px;
              font-weight:600;
              background:${isActive ? '#FFE8EB' : '#E6F7EF'};
              color:${isActive ? '#D32F2F' : '#2E9F65'};
            ">${event.status}</span>
          </div>
        `);

            if (onEventClick) {
                marker.on('click', () => onEventClick(event));
            }

            markersRef.current.push(marker);
        });

        // Fit bounds if there are markers
        if (validEvents.length > 0) {
            const bounds = L.latLngBounds(validEvents.map(e => [e.lat, e.lng]));
            mapInstance.current.fitBounds(bounds, { padding: [50, 50], maxZoom: 14 });
        }
    }, [events, onEventClick]);

    return (
        <div
            ref={mapRef}
            style={{
                width: '100%',
                height: '100%',
                borderRadius: 'var(--radius-12)',
                ...style,
            }}
        />
    );
}

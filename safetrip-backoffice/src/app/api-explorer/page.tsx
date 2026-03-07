'use client';

import { useState, useMemo } from 'react';
import { API } from '@/lib/apiEndpoints';
import api from '@/lib/apiClient';
import {
    TerminalSquare, Server, Play, ChevronRight, CheckCircle2,
    XCircle, Database, Lock, Clock, AlertTriangle, ArrowRightLeft
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

interface EndpointDefinition {
    key: string;
    path: string | Function;
    method: string;
    requiredParams?: string[];
}

export default function ApiExplorerPage() {
    const [selectedDomain, setSelectedDomain] = useState<string>('AUTH');
    const [selectedEndpoint, setSelectedEndpoint] = useState<EndpointDefinition | null>(null);
    const [testResponse, setTestResponse] = useState<any>(null);
    const [isTesting, setIsTesting] = useState(false);
    const [paramInputs, setParamInputs] = useState<Record<string, string>>({});

    // Parse API object into structured domain/endpoint maps
    const apiStructure = useMemo(() => {
        const structure: Record<string, EndpointDefinition[]> = {};

        Object.keys(API).forEach(domainKey => {
            const domain = (API as any)[domainKey];
            structure[domainKey] = [];

            Object.keys(domain).forEach(endpointKey => {
                const value = domain[endpointKey];
                const isMethod = typeof value === 'function';

                // Extrapolate required params by parsing the function string Signature if it's a function
                let requiredParams: string[] = [];
                if (isMethod) {
                    const funcStr = value.toString();
                    const argsMatch = funcStr.match(/\(([^)]+)\)/);
                    if (argsMatch && argsMatch[1]) {
                        requiredParams = argsMatch[1].split(',').map(arg => arg.trim());
                    }
                }

                // Best guess for HTTP method based on nomenclature
                let method = 'GET';
                const upperKey = endpointKey.toUpperCase();
                if (upperKey.includes('CREATE') || upperKey.includes('POST') || upperKey.includes('REGISTER') || upperKey.includes('JOIN')) method = 'POST';
                if (upperKey.includes('UPDATE') || upperKey.includes('PUT')) method = 'PUT';
                if (upperKey.includes('DELETE') || upperKey.includes('REMOVE') || upperKey.includes('CANCEL')) method = 'DELETE';

                structure[domainKey].push({
                    key: endpointKey,
                    path: value,
                    method,
                    requiredParams
                });
            });
        });

        return structure;
    }, []);

    const handleSelectEndpoint = (endpoint: EndpointDefinition) => {
        setSelectedEndpoint(endpoint);
        setTestResponse(null);
        // Pre-fill dummy data for specific tests or leave blank
        const newParams: Record<string, string> = {};
        endpoint.requiredParams?.forEach(p => newParams[p] = '');
        setParamInputs(newParams);
    };

    const handleTestEndpoint = async () => {
        if (!selectedEndpoint) return;
        setIsTesting(true);
        setTestResponse(null);

        try {
            // Reconstruct path
            let finalPath = '';
            if (typeof selectedEndpoint.path === 'function') {
                const args = selectedEndpoint.requiredParams?.map(p => paramInputs[p] || 'test_id') || [];
                finalPath = selectedEndpoint.path(...args);
            } else {
                finalPath = selectedEndpoint.path as string;
            }

            // Only allow GET for safety unless confirmed
            if (selectedEndpoint.method !== 'GET') {
                setTestResponse({
                    error: true,
                    message: `Safety Lock: Testing ${selectedEndpoint.method} requests from the browser is restricted by default to prevent accidental data modification.`,
                    simulatedPath: finalPath
                });
                setIsTesting(false);
                return;
            }

            const startTime = performance.now();
            const res = await api.get(finalPath);
            const duration = Math.round(performance.now() - startTime);

            setTestResponse({
                success: true,
                status: 200,
                duration,
                data: res
            });
        } catch (error: any) {
            setTestResponse({
                error: true,
                status: error?.response?.status || 500,
                message: error.message || 'Unknown network error',
                data: error?.response?.data
            });
        } finally {
            setIsTesting(false);
        }
    };

    const methodColor = (m: string) => {
        switch (m) {
            case 'GET': return 'bg-blue-100 text-blue-700 border-blue-200';
            case 'POST': return 'bg-green-100 text-green-700 border-green-200';
            case 'PUT': return 'bg-amber-100 text-amber-700 border-amber-200';
            case 'DELETE': return 'bg-red-100 text-red-700 border-red-200';
            default: return 'bg-gray-100 text-gray-700 border-gray-200';
        }
    };

    return (
        <div className="flex flex-col h-[calc(100vh-100px)] slide-in">
            <div className="flex flex-col gap-1 mb-6">
                <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
                    <TerminalSquare className="h-6 w-6 text-indigo-500" /> API Explorer
                </h1>
                <p className="text-muted-foreground">백엔드 서버에 등록된 {Object.keys(apiStructure).length}개의 주요 도메인 API 레지스트리를 탐색하고 실시간 상태를 테스트합니다.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 flex-1 min-h-0">
                {/* Domain Sidebar */}
                <div className="md:col-span-1 bg-white rounded-xl border border-border shadow-sm flex flex-col overflow-hidden">
                    <div className="p-4 border-b bg-muted/20 font-bold flex items-center gap-2 text-sm text-slate-700">
                        <Database size={16} className="text-indigo-500" /> Modules
                    </div>
                    <div className="flex-1 overflow-y-auto p-2 space-y-1 custom-scrollbar">
                        {Object.keys(apiStructure).map(domain => (
                            <button
                                key={domain}
                                onClick={() => { setSelectedDomain(domain); setSelectedEndpoint(null); setTestResponse(null); }}
                                className={`w-full text-left px-3 py-2.5 rounded-lg text-sm font-medium transition-colors flex justify-between items-center ${selectedDomain === domain
                                        ? 'bg-indigo-50 text-indigo-700 border border-indigo-100/50'
                                        : 'text-slate-600 hover:bg-slate-50'
                                    }`}
                            >
                                <span>{domain}</span>
                                <span className="text-xs bg-black/5 px-2 py-0.5 rounded-full text-slate-500">
                                    {apiStructure[domain].length}
                                </span>
                            </button>
                        ))}
                    </div>
                </div>

                {/* Main Content Area */}
                <div className="md:col-span-3 bg-white rounded-xl border border-border shadow-sm flex flex-col overflow-hidden">
                    {/* Header */}
                    <div className="p-4 border-b bg-muted/20 flex items-center justify-between">
                        <div className="flex items-center gap-2 font-bold text-slate-700 text-sm">
                            <Server size={16} className="text-indigo-500" />
                            {selectedDomain}
                            <ChevronRight size={14} className="text-muted-foreground mx-1" />
                            {selectedEndpoint ? selectedEndpoint.key : 'Endpoonts'}
                        </div>
                        {selectedEndpoint && (
                            <Badge variant="outline" className={`font-mono ${methodColor(selectedEndpoint.method)}`}>
                                {selectedEndpoint.method}
                            </Badge>
                        )}
                    </div>

                    <div className="flex-1 overflow-y-auto overflow-x-hidden custom-scrollbar bg-slate-50 flex">
                        {!selectedEndpoint ? (
                            // List View
                            <div className="w-full p-6">
                                <h3 className="text-lg font-bold mb-4">{selectedDomain} API Directory</h3>
                                <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
                                    {apiStructure[selectedDomain].map(ep => (
                                        <div
                                            key={ep.key}
                                            onClick={() => handleSelectEndpoint(ep)}
                                            className="bg-white p-4 rounded-xl shadow-sm border border-slate-200/60 hover:border-indigo-300 hover:shadow-md cursor-pointer transition-all flex flex-col gap-2 relative overflow-hidden group"
                                        >
                                            <div className="absolute top-0 right-0 w-12 h-full bg-gradient-to-l from-indigo-50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
                                            <div className="flex items-center gap-2">
                                                <Badge className={`text-[10px] w-14 justify-center ${methodColor(ep.method)}`}>{ep.method}</Badge>
                                                <span className="font-bold text-sm text-slate-700">{ep.key}</span>
                                            </div>
                                            <code className="text-xs bg-slate-100 px-2 py-1.5 rounded-md font-mono text-slate-500 truncate mt-1 border border-slate-200/50">
                                                {typeof ep.path === 'function' ? ep.path.toString().split('=>')[1].trim().replace(/`/g, '') : String(ep.path)}
                                            </code>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        ) : (
                            // Detail/Test View
                            <div className="w-full h-full flex flex-col lg:flex-row">
                                {/* Left: Config */}
                                <div className="w-full lg:w-1/2 p-6 border-r border-slate-200 border-dashed space-y-6">
                                    <div className="space-y-2">
                                        <h3 className="font-bold text-sm text-slate-700 uppercase tracking-wider">Endpoint Path</h3>
                                        <div className="bg-slate-800 text-teal-300 font-mono text-sm p-3 rounded-lg flex items-center gap-3 overflow-x-auto">
                                            <span className="text-pink-400 font-bold">{selectedEndpoint.method}</span>
                                            <span>
                                                {typeof selectedEndpoint.path === 'function' ? selectedEndpoint.path.toString().split('=>')[1].trim().replace(/`/g, '') : String(selectedEndpoint.path)}
                                            </span>
                                        </div>
                                    </div>

                                    {selectedEndpoint.requiredParams && selectedEndpoint.requiredParams.length > 0 && (
                                        <div className="space-y-3">
                                            <h3 className="font-bold text-sm text-slate-700 uppercase tracking-wider">Path Parameters</h3>
                                            <div className="space-y-3 bg-white p-4 rounded-lg border border-slate-200">
                                                {selectedEndpoint.requiredParams.map(param => (
                                                    <div key={param} className="space-y-1.5">
                                                        <label className="text-xs font-bold text-slate-500">{param}</label>
                                                        <Input
                                                            placeholder={`Enter ${param}...`}
                                                            className="h-8 font-mono text-sm shadow-inner"
                                                            value={paramInputs[param] || ''}
                                                            onChange={e => setParamInputs(prev => ({ ...prev, [param]: e.target.value }))}
                                                        />
                                                    </div>
                                                ))}
                                            </div>
                                        </div>
                                    )}

                                    <div className="pt-4 flex gap-3">
                                        <Button
                                            className="flex-1 gap-2 bg-indigo-600 hover:bg-indigo-700 text-white shadow-md hover:shadow-lg transition-all"
                                            onClick={handleTestEndpoint}
                                            disabled={isTesting}
                                        >
                                            <Play size={16} className={isTesting ? "animate-pulse" : ""} />
                                            {isTesting ? 'Sending Request...' : 'Test Request'}
                                        </Button>
                                        <Button variant="outline" onClick={() => setSelectedEndpoint(null)}>
                                            Back
                                        </Button>
                                    </div>

                                    {selectedEndpoint.method !== 'GET' && (
                                        <div className="mt-4 p-3 bg-amber-50 rounded-lg border border-amber-200 flex items-start gap-2">
                                            <AlertTriangle size={16} className="text-amber-500 mt-0.5 shrink-0" />
                                            <p className="text-xs text-amber-700 leading-relaxed">
                                                <strong>Safety Lock:</strong> 테스트 환경 보호를 위해 GET 이외의 변경 가능한 메서드는 백오피스 탐색기에서의 직접 실행이 제한되어 있습니다.
                                            </p>
                                        </div>
                                    )}
                                </div>

                                {/* Right: Response */}
                                <div className="w-full lg:w-1/2 p-6 bg-slate-900 text-slate-300 flex flex-col font-mono text-xs overflow-hidden relative">
                                    <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/10 blur-3xl mix-blend-screen pointer-events-none"></div>

                                    <div className="flex items-center justify-between mb-4 border-b border-slate-700/50 pb-2">
                                        <h3 className="font-bold text-slate-400">Response Object</h3>
                                        {testResponse && (
                                            <div className="flex items-center gap-3 text-[11px]">
                                                {testResponse.duration && <span className="text-slate-500 flex items-center gap-1"><Clock size={12} /> {testResponse.duration}ms</span>}
                                                <Badge variant="outline" className={testResponse.success ? 'bg-teal-900/40 text-teal-400 border-teal-800' : 'bg-pink-900/40 text-pink-400 border-pink-800'}>
                                                    {testResponse.error ? 'FAILED' : `HTTP ${testResponse.status}`}
                                                </Badge>
                                            </div>
                                        )}
                                    </div>

                                    <div className="flex-1 overflow-y-auto custom-scrollbar">
                                        {!testResponse && !isTesting ? (
                                            <div className="h-full flex flex-col items-center justify-center text-slate-600 space-y-3">
                                                <ArrowRightLeft size={32} className="opacity-50" />
                                                <p>Execute "Test Request" to view payload.</p>
                                            </div>
                                        ) : isTesting ? (
                                            <div className="h-full flex flex-col items-center justify-center text-indigo-400 space-y-4">
                                                <div className="w-6 h-6 border-2 border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
                                                <p className="animate-pulse">Awaiting Server Response...</p>
                                            </div>
                                        ) : (
                                            <div className="space-y-4">
                                                {testResponse.simulatedPath && (
                                                    <div className="text-slate-400 mb-2 p-2 bg-slate-800/50 rounded-md border border-slate-700">
                                                        <span className="text-slate-500 mr-2">Target URL:</span>
                                                        <span className="text-teal-300">{testResponse.simulatedPath}</span>
                                                    </div>
                                                )}
                                                <pre className="whitespace-pre-wrap leading-relaxed text-[11px] overflow-x-hidden">
                                                    {JSON.stringify(testResponse, null, 2)}
                                                </pre>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

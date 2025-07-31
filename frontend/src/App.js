import React, { useState, useEffect } from 'react';
import { Activity, Zap, Database, Users, ChevronRight, Play, BarChart3 } from 'lucide-react';
import InferencePlayground from './components/InferencePlayground';
import MetricsDashboard from './components/MetricsDashboard';
import SystemStatus from './components/SystemStatus';
import './index.css';

function App() {
  const [activeTab, setActiveTab] = useState('playground');
  const [systemHealth, setSystemHealth] = useState({
    prefillPods: 1,
    decodePods: 2,
    eppPods: 1,
    cacheHitRate: 16.0,
    totalRequests: 2002,
    totalHits: 320
  });

  const tabs = [
    { id: 'playground', name: 'Inference Playground', icon: Play },
    { id: 'metrics', name: 'Performance Metrics', icon: BarChart3 },
    { id: 'system', name: 'System Status', icon: Activity }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-slate-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <Zap className="h-8 w-8 text-llm-blue" />
                <h1 className="text-2xl font-bold text-gray-900">LLM-D</h1>
              </div>
              <div className="hidden sm:flex items-center space-x-2 text-sm text-gray-600">
                <ChevronRight className="h-4 w-4" />
                <span>Distributed Inference Demo</span>
              </div>
            </div>
            
            {/* Quick Stats */}
            <div className="hidden md:flex items-center space-x-6 text-sm">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span className="text-gray-600">System Healthy</span>
              </div>
              <div className="flex items-center space-x-2">
                <Database className="h-4 w-4 text-llm-purple" />
                <span className="text-gray-900 font-medium">{systemHealth.cacheHitRate}%</span>
                <span className="text-gray-600">Cache Hit Rate</span>
              </div>
              <div className="flex items-center space-x-2">
                <Users className="h-4 w-4 text-llm-green" />
                <span className="text-gray-900 font-medium">{systemHealth.prefillPods + systemHealth.decodePods}</span>
                <span className="text-gray-600">Active Pods</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="bg-white border-b border-slate-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                    activeTab === tab.id
                      ? 'border-llm-blue text-llm-blue'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <Icon className="h-4 w-4" />
                  <span>{tab.name}</span>
                </button>
              );
            })}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'playground' && <InferencePlayground />}
        {activeTab === 'metrics' && <MetricsDashboard />}
        {activeTab === 'system' && <SystemStatus />}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 mt-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4 text-sm text-gray-600">
              <span>LLM-D v1.0.0</span>
              <span>•</span>
              <span>Kubernetes-Native Distributed Inference</span>
            </div>
            <div className="flex items-center space-x-4 text-sm text-gray-600">
              <span>Model: meta-llama/Llama-3.2-1B</span>
              <span>•</span>
              <span>Namespace: llm-d</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;

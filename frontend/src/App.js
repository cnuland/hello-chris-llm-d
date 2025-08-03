import React, { useState } from 'react';
import { Play, BarChart3, Activity, Target } from 'lucide-react';
import InferencePlayground from './components/InferencePlayground';
import MetricsDashboard from './components/MetricsDashboard';
import SystemStatus from './components/SystemStatus';
import CacheRoutingDemo from './components/CacheRoutingDemo';
import './index.css';

function App() {
  const [activeTab, setActiveTab] = useState('playground');
  
  const systemHealth = {
    prefillPods: 1,
    decodePods: 3,
    eppPods: 1,
    cacheHitRate: 80.0,
    totalRequests: 3975,
    totalHits: 3456
  };

  const tabs = [
    { id: 'playground', name: 'Inference Playground', icon: Play },
    { id: 'cache-demo', name: 'Cache Routing Demo', icon: Target },
    { id: 'metrics', name: 'Performance Metrics', icon: BarChart3 },
    { id: 'system', name: 'System Status', icon: Activity }
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-gray-800 shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center space-x-2">
              <BarChart3 className="h-8 w-8 text-blue-500" />
              <h1 className="text-2xl font-bold text-white">LLM-D Dashboard</h1>
            </div>
            
            {/* Quick Stats */}
            <div className="hidden md:flex items-center space-x-6 text-sm text-white">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span className="text-green-400">System Healthy</span>
              </div>
              <div className="flex items-center space-x-2">
                <span>{systemHealth.cacheHitRate}%</span>
                <span className="text-gray-300">Cache Hit</span>
              </div>
              <div className="flex items-center space-x-2">
                <span>{systemHealth.prefillPods + systemHealth.decodePods}</span>
                <span className="text-gray-300">Active Pods</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="bg-gray-900">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 py-4 px-1 border-b-4 font-medium text-sm transition-colors duration-150 ${
                    activeTab === tab.id
                      ? 'border-blue-500 text-blue-500'
                      : 'border-transparent text-gray-300 hover:text-gray-400 hover:border-gray-200'
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
        {activeTab === 'cache-demo' && <CacheRoutingDemo />}
        {activeTab === 'metrics' && <MetricsDashboard />}
        {activeTab === 'system' && <SystemStatus />}
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <span>LLM-D v1.0</span>
              <span>•</span>
              <span>Kubernetes-Native Distributed Inference</span>
            </div>
            <div className="flex items-center space-x-4">
              <span>Model: Meta-LLaMA-3.2-1B</span>
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

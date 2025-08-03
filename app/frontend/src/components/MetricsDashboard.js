import React, { useState, useEffect } from 'react';
import { BarChart3, TrendingUp, Zap, Database, Clock, Activity, RefreshCw } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell } from 'recharts';

const MetricsDashboard = () => {
  const [metrics, setMetrics] = useState({
    cacheHitRate: 80.0,
    totalQueries: 3975,
    totalHits: 3456,
    avgLatency: 850,
    requestsPerSecond: 4.2,
    activePods: 3
  });

  const [chartData, setChartData] = useState([]);
  const [lastUpdated, setLastUpdated] = useState(new Date());

  // Mock real-time data for demonstration
  useEffect(() => {
    const generateMockData = () => {
      const now = new Date();
      const timePoints = [];
      
      for (let i = 9; i >= 0; i--) {
        const time = new Date(now.getTime() - i * 30000); // 30 second intervals
        timePoints.push({
          time: time.toLocaleTimeString(),
          timestamp: time.getTime(),
          cacheHitRate: 75 + Math.random() * 10,
          requestsPerSecond: 2 + Math.random() * 4,
          avgLatency: 1000 + Math.random() * 500,
          totalRequests: 1800 + i * 20 + Math.random() * 50
        });
      }
      
      return timePoints;
    };

    const initialData = generateMockData();
    setChartData(initialData);

    // Simulate real-time updates
    const interval = setInterval(() => {
      setChartData(prevData => {
        const newData = [...prevData.slice(1)];
        const lastPoint = prevData[prevData.length - 1];
        const now = new Date();
        
        newData.push({
          time: now.toLocaleTimeString(),
          timestamp: now.getTime(),
          cacheHitRate: Math.max(70, Math.min(90, lastPoint.cacheHitRate + (Math.random() - 0.5) * 4)),
          requestsPerSecond: Math.max(0, lastPoint.requestsPerSecond + (Math.random() - 0.5) * 1),
          avgLatency: Math.max(500, Math.min(3000, lastPoint.avgLatency + (Math.random() - 0.5) * 200)),
          totalRequests: lastPoint.totalRequests + Math.random() * 10
        });
        
        return newData;
      });
      
      setLastUpdated(new Date());
    }, 5000); // Update every 5 seconds

    return () => clearInterval(interval);
  }, []);

  // Pod distribution data
  const podData = [
    { name: 'Prefill Pods', value: 1, color: '#16a34a' },
    { name: 'Decode Pods', value: 2, color: '#2563eb' },
    { name: 'EPP Pods', value: 1, color: '#9333ea' }
  ];

  // Performance comparison data
  const comparisonData = [
    { metric: 'TTFT (P95)', standard: 8200, llmD: 2700, improvement: 67 },
    { metric: 'Throughput (QPS)', standard: 12, llmD: 26, improvement: 117 },
    { metric: 'GPU Utilization', standard: 45, llmD: 82, improvement: 82 },
    { metric: 'Cache Hit Rate', standard: 0, llmD: 80, improvement: 100 }
  ];

  const refreshMetrics = () => {
    // In a real app, this would fetch from the API
    setMetrics(prev => ({
      ...prev,
      cacheHitRate: 78 + Math.random() * 8,
      totalQueries: prev.totalQueries + Math.floor(Math.random() * 20),
      totalHits: prev.totalHits + Math.floor(Math.random() * 5),
      avgLatency: 1000 + Math.random() * 600,
      requestsPerSecond: 2 + Math.random() * 3
    }));
    setLastUpdated(new Date());
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-gray-900">Performance Metrics</h2>
          <div className="flex items-center space-x-4">
            <span className="text-sm text-gray-600">
              Last updated: {lastUpdated.toLocaleTimeString()}
            </span>
            <button
              onClick={refreshMetrics}
              className="flex items-center space-x-2 text-sm text-llm-blue hover:text-blue-700 font-medium"
            >
              <RefreshCw className="h-4 w-4" />
              <span>Refresh</span>
            </button>
          </div>
        </div>
        <p className="text-gray-600">
          Real-time monitoring of LLM-D distributed inference performance, cache efficiency, and system health.
        </p>
      </div>

      {/* Key Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Cache Hit Rate</p>
              <p className="text-2xl font-bold text-llm-green">{metrics.cacheHitRate.toFixed(1)}%</p>
            </div>
            <Database className="h-8 w-8 text-llm-green" />
          </div>
          <p className="text-xs text-gray-500 mt-2">
            {metrics.totalHits} hits / {metrics.totalQueries} queries
          </p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Avg Latency</p>
              <p className="text-2xl font-bold text-llm-blue">{metrics.avgLatency.toFixed(0)}ms</p>
            </div>
            <Clock className="h-8 w-8 text-llm-blue" />
          </div>
          <p className="text-xs text-gray-500 mt-2">Time to first token</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Throughput</p>
              <p className="text-2xl font-bold text-llm-purple">{metrics.requestsPerSecond.toFixed(1)} RPS</p>
            </div>
            <TrendingUp className="h-8 w-8 text-llm-purple" />
          </div>
          <p className="text-xs text-gray-500 mt-2">Requests per second</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Active Pods</p>
              <p className="text-2xl font-bold text-llm-orange">{metrics.activePods}</p>
            </div>
            <Activity className="h-8 w-8 text-llm-orange" />
          </div>
          <p className="text-xs text-gray-500 mt-2">Prefill + Decode + EPP</p>
        </div>
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Real-time Performance Chart */}
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Real-time Performance</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis yAxisId="left" />
              <YAxis yAxisId="right" orientation="right" />
              <Tooltip />
              <Legend />
              <Line 
                yAxisId="left"
                type="monotone" 
                dataKey="cacheHitRate" 
                stroke="#16a34a" 
                strokeWidth={2}
                name="Cache Hit Rate (%)"
              />
              <Line 
                yAxisId="right"
                type="monotone" 
                dataKey="requestsPerSecond" 
                stroke="#2563eb" 
                strokeWidth={2}
                name="Requests/sec"
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Pod Distribution */}
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Pod Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={podData}
                cx="50%"
                cy="50%"
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
                label={({ name, value }) => `${name}: ${value}`}
              >
                {podData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
          <div className="mt-4 space-y-2">
            {podData.map((pod, index) => (
              <div key={index} className="flex items-center space-x-2 text-sm">
                <div 
                  className="w-3 h-3 rounded-full" 
                  style={{ backgroundColor: pod.color }}
                ></div>
                <span className="text-gray-600">{pod.name}</span>
                <span className="font-medium">{pod.value} pod{pod.value !== 1 ? 's' : ''}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Performance Comparison */}
      <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">LLM-D vs Standard K8s Performance</h3>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={comparisonData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="metric" />
            <YAxis />
            <Tooltip 
              formatter={(value, name) => [
                name === 'improvement' ? `+${value}%` : value,
                name === 'standard' ? 'Standard K8s' : name === 'llmD' ? 'LLM-D' : 'Improvement'
              ]}
            />
            <Legend />
            <Bar dataKey="standard" fill="#94a3b8" name="Standard K8s" />
            <Bar dataKey="llmD" fill="#2563eb" name="LLM-D" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* System Status Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h4 className="text-sm font-medium text-gray-900 mb-3">Prefill/Decode Status</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">P/D Disaggregation</span>
              <span className="px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">Enabled</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Prefill Threshold</span>
              <span className="text-sm text-gray-900">10 tokens</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Cache Transfer</span>
              <span className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full">NixlConnector</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h4 className="text-sm font-medium text-gray-900 mb-3">Cache Configuration</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Prefix Caching</span>
              <span className="px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">Enabled</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Hash Algorithm</span>
              <span className="text-sm text-gray-900">Builtin</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Cache Efficiency</span>
              <span className="text-sm font-medium text-llm-green">{metrics.cacheHitRate.toFixed(1)}%</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h4 className="text-sm font-medium text-gray-900 mb-3">Model Information</h4>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Model</span>
              <span className="text-sm text-gray-900">Llama-3.2-1B</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Framework</span>
              <span className="text-sm text-gray-900">vLLM</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Deployment</span>
              <span className="text-sm text-gray-900">llm-d namespace</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default MetricsDashboard;

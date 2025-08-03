import React, { useState, useEffect } from 'react';
import { 
  Server, 
  CheckCircle, 
  AlertCircle, 
  XCircle, 
  Cpu, 
  MemoryStick, 
  HardDrive, 
  Network,
  RefreshCw,
  Eye,
  Terminal
} from 'lucide-react';

const SystemStatus = () => {
  const [pods, setPods] = useState([
    {
      name: 'llama-3-2-1b-prefill-b66bcc88-5zkt7',
      type: 'Prefill',
      status: 'Running',
      ready: '1/1',
      age: '15m',
      node: 'ip-10-0-1-27.ec2.internal',
      ip: '10.129.6.197',
      cpu: '25%',
      memory: '2.1Gi',
      gpu: 'N/A'
    },
    {
      name: 'llama-3-2-1b-decode-67c74fdb5b-dbh7p',
      type: 'Decode',
      status: 'Running',
      ready: '2/2',
      age: '15m',
      node: 'ip-10-0-49-229.ec2.internal',
      ip: '10.130.6.188',
      cpu: '45%',
      memory: '3.8Gi',
      gpu: '1 GPU'
    },
    {
      name: 'llama-3-2-1b-decode-v2-9b59f7f76-lbz5j',
      type: 'Decode',
      status: 'Running',
      ready: '2/2',
      age: '49m',
      node: 'ip-10-0-79-200.ec2.internal',
      ip: '10.128.6.245',
      cpu: '38%',
      memory: '3.2Gi',
      gpu: '1 GPU'
    },
    {
      name: 'llama-3-2-1b-epp-8d46bf5c5-9zfpr',
      type: 'EPP',
      status: 'Running',
      ready: '1/1',
      age: '15m',
      node: 'ip-10-0-1-27.ec2.internal',
      ip: '10.128.4.146',
      cpu: '12%',
      memory: '512Mi',
      gpu: 'N/A'
    }
  ]);

  const [services, setServices] = useState([
    {
      name: 'llama-3-2-1b-service-prefill',
      type: 'ClusterIP',
      clusterIP: 'None',
      ports: '5557/TCP,8000/TCP',
      age: '15m',
      status: 'Active'
    },
    {
      name: 'llama-3-2-1b-service-decode',
      type: 'ClusterIP',
      clusterIP: 'None',
      ports: '5557/TCP,8000/TCP',
      age: '15m',
      status: 'Active'
    },
    {
      name: 'llama-3-2-1b-epp-service',
      type: 'NodePort',
      clusterIP: '172.30.238.105',
      ports: '9002:31893/TCP,9003:31291/TCP,9090:31850/TCP',
      age: '15m',
      status: 'Active'
    }
  ]);

  const [systemMetrics, setSystemMetrics] = useState({
    totalPods: 4,
    runningPods: 4,
    totalServices: 3,
    activeServices: 3,
    cacheHitRate: 16.0,
    totalRequests: 2002,
    avgResponseTime: 1250,
    errorRate: 0.1
  });

  const [lastUpdated, setLastUpdated] = useState(new Date());

  const getStatusIcon = (status) => {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'pending':
        return <AlertCircle className="h-4 w-4 text-yellow-500" />;
      case 'failed':
      case 'error':
        return <XCircle className="h-4 w-4 text-red-500" />;
      default:
        return <AlertCircle className="h-4 w-4 text-gray-500" />;
    }
  };

  const getStatusColor = (status) => {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
        return 'text-green-700 bg-green-100';
      case 'pending':
        return 'text-yellow-700 bg-yellow-100';
      case 'failed':
      case 'error':
        return 'text-red-700 bg-red-100';
      default:
        return 'text-gray-700 bg-gray-100';
    }
  };

  const refreshStatus = () => {
    // Simulate some variation in metrics
    setSystemMetrics(prev => ({
      ...prev,
      cacheHitRate: 14 + Math.random() * 6,
      totalRequests: prev.totalRequests + Math.floor(Math.random() * 10),
      avgResponseTime: 1000 + Math.random() * 500,
      errorRate: Math.random() * 0.5
    }));
    setLastUpdated(new Date());
  };

  useEffect(() => {
    const interval = setInterval(refreshStatus, 30000); // Update every 30 seconds
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-gray-900">System Status</h2>
          <div className="flex items-center space-x-4">
            <span className="text-sm text-gray-600">
              Last updated: {lastUpdated.toLocaleTimeString()}
            </span>
            <button
              onClick={refreshStatus}
              className="flex items-center space-x-2 text-sm text-llm-blue hover:text-blue-700 font-medium"
            >
              <RefreshCw className="h-4 w-4" />
              <span>Refresh</span>
            </button>
          </div>
        </div>
        <p className="text-gray-600">
          Monitor the health and performance of your LLM-D distributed inference infrastructure.
        </p>
      </div>

      {/* System Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Pods</p>
              <p className="text-2xl font-bold text-gray-900">{systemMetrics.totalPods}</p>
            </div>
            <Server className="h-8 w-8 text-llm-blue" />
          </div>
          <p className="text-xs text-gray-500 mt-2">
            {systemMetrics.runningPods} running
          </p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Services</p>
              <p className="text-2xl font-bold text-gray-900">{systemMetrics.totalServices}</p>
            </div>
            <Network className="h-8 w-8 text-llm-green" />
          </div>
          <p className="text-xs text-gray-500 mt-2">
            {systemMetrics.activeServices} active
          </p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Cache Hit Rate</p>
              <p className="text-2xl font-bold text-gray-900">{systemMetrics.cacheHitRate.toFixed(1)}%</p>
            </div>
            <HardDrive className="h-8 w-8 text-llm-purple" />
          </div>
          <p className="text-xs text-gray-500 mt-2">
            {systemMetrics.totalRequests} total requests
          </p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Error Rate</p>
              <p className="text-2xl font-bold text-gray-900">{systemMetrics.errorRate.toFixed(2)}%</p>
            </div>
            <AlertCircle className="h-8 w-8 text-llm-orange" />
          </div>
          <div className="flex items-center mt-2">
            <div className="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
            <p className="text-xs text-gray-500">System healthy</p>
          </div>
        </div>
      </div>

      {/* Pods Status */}
      <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Pod Status</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ready
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Resources
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Age
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {pods.map((pod, index) => (
                <tr key={index} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      {getStatusIcon(pod.status)}
                      <div className="ml-3">
                        <div className="text-sm font-medium text-gray-900">
                          {pod.name.length > 30 ? pod.name.substring(0, 30) + '...' : pod.name}
                        </div>
                        <div className="text-sm text-gray-500">{pod.ip}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      pod.type === 'Prefill' ? 'bg-green-100 text-green-800' :
                      pod.type === 'Decode' ? 'bg-blue-100 text-blue-800' :
                      'bg-purple-100 text-purple-800'
                    }`}>
                      {pod.type}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(pod.status)}`}>
                      {pod.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {pod.ready}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <div className="space-y-1">
                      <div className="flex items-center space-x-1">
                        <Cpu className="h-3 w-3" />
                        <span>{pod.cpu}</span>
                      </div>
                      <div className="flex items-center space-x-1">
                        <MemoryStick className="h-3 w-3" />
                        <span>{pod.memory}</span>
                      </div>
                      {pod.gpu !== 'N/A' && (
                        <div className="flex items-center space-x-1">
                          <HardDrive className="h-3 w-3" />
                          <span>{pod.gpu}</span>
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {pod.age}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <div className="flex space-x-2">
                      <button className="text-llm-blue hover:text-blue-700">
                        <Eye className="h-4 w-4" />
                      </button>
                      <button className="text-gray-600 hover:text-gray-900">
                        <Terminal className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Services Status */}
      <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Service Status</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Cluster IP
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ports
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Age
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {services.map((service, index) => (
                <tr key={index} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <Network className="h-4 w-4 text-gray-400 mr-3" />
                      <div className="text-sm font-medium text-gray-900">
                        {service.name}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      service.type === 'NodePort' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'
                    }`}>
                      {service.type}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {service.clusterIP}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {service.ports}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      {getStatusIcon(service.status)}
                      <span className={`ml-2 inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(service.status)}`}>
                        {service.status}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {service.age}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Configuration Summary */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Configuration</h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center py-2 border-b border-gray-100">
              <span className="text-sm text-gray-600">Model</span>
              <span className="text-sm font-medium text-gray-900">meta-llama/Llama-3.2-1B</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-100">
              <span className="text-sm text-gray-600">Namespace</span>
              <span className="text-sm font-medium text-gray-900">llm-d</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-100">
              <span className="text-sm text-gray-600">P/D Disaggregation</span>
              <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                Enabled
              </span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-100">
              <span className="text-sm text-gray-600">Prefix Caching</span>
              <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                Enabled
              </span>
            </div>
            <div className="flex justify-between items-center py-2">
              <span className="text-sm text-gray-600">Cache Algorithm</span>
              <span className="text-sm font-medium text-gray-900">SHA256</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Resource Allocation</h3>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm text-gray-600">GPU Utilization</span>
                <span className="text-sm font-medium text-gray-900">78%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className="bg-llm-blue h-2 rounded-full" style={{ width: '78%' }}></div>
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm text-gray-600">Memory Usage</span>
                <span className="text-sm font-medium text-gray-900">65%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className="bg-llm-green h-2 rounded-full" style={{ width: '65%' }}></div>
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm text-gray-600">CPU Usage</span>
                <span className="text-sm font-medium text-gray-900">42%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className="bg-llm-purple h-2 rounded-full" style={{ width: '42%' }}></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SystemStatus;

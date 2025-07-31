import React, { useState, useEffect, useRef } from 'react';
import { Send, Loader2, Zap, Clock, Database, Copy, RotateCcw } from 'lucide-react';
import axios from 'axios';

const InferencePlayground = () => {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [requestHistory, setRequestHistory] = useState([]);
  const [selectedModel, setSelectedModel] = useState('meta-llama/Llama-3.2-1B');
  const [temperature, setTemperature] = useState(0.7);
  const [maxTokens, setMaxTokens] = useState(150);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const responseRef = useRef(null);

  // Sample prompts for quick testing
  const samplePrompts = [
    "Explain artificial intelligence in simple terms.",
    "Write a short story about a robot learning to paint.",
    "What are the benefits of renewable energy?",
    "Describe the process of photosynthesis.",
    "How does machine learning work?"
  ];

  // Shared prefixes for cache testing
  const cachePrefixes = [
    "Explain the concept of machine learning. Machine learning is",
    "Tell me about space exploration. Space exploration is",
    "Describe quantum computing. Quantum computing is"
  ];

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!prompt.trim() || isLoading) return;

    setIsLoading(true);
    const startTime = Date.now();

    try {
      // Use the decode service directly for now (since EPP had auth issues)
      const endpoint = `${window.BACKEND_URL}/api/v1/completions`;
      
      const requestData = {
        model: selectedModel,
        prompt: prompt,
        max_tokens: maxTokens,
        temperature: temperature,
        stream: false
      };

      const response = await axios.post(endpoint, requestData, {
        timeout: 30000,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      const endTime = Date.now();
      const latency = endTime - startTime;

      const completion = response.data.choices?.[0]?.text || 'No response generated';
      setResponse(completion);

      // Add to history
      const historyEntry = {
        id: Date.now(),
        prompt: prompt,
        response: completion,
        latency,
        timestamp: new Date().toLocaleTimeString(),
        model: selectedModel,
        temperature,
        maxTokens
      };

      setRequestHistory(prev => [historyEntry, ...prev.slice(0, 9)]); // Keep last 10

    } catch (error) {
      console.error('Inference error:', error);
      let errorMessage = 'Failed to get response from model';
      
      if (error.response?.status === 404) {
        errorMessage = 'Model endpoint not found. Check if the service is running.';
      } else if (error.response?.status >= 500) {
        errorMessage = 'Server error. The model service may be unavailable.';
      } else if (error.code === 'ECONNABORTED') {
        errorMessage = 'Request timeout. The model may be processing a large request.';
      }
      
      setResponse(`Error: ${errorMessage}`);
    } finally {
      setIsLoading(false);
    }
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
  };

  const clearHistory = () => {
    setRequestHistory([]);
  };

  useEffect(() => {
    if (responseRef.current) {
      responseRef.current.scrollTop = responseRef.current.scrollHeight;
    }
  }, [response]);

  return (
    <div className="space-y-6">
      {/* Header */}
        <div className="bg-gray-800 rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold text-white">Inference Playground</h2>
            <div className="flex items-center space-x-2 text-sm text-blue-400">
              <span>Interactive Model Testing</span>
            </div>
          </div>
          <p className="text-gray-300">
            Test the LLM-D distributed inference system with custom prompts. 
            Try the cache-optimized prefixes to see improved performance!
          </p>
        </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Input Section */}
        <div className="lg:col-span-2 space-y-6">
          {/* Quick Actions */}
          <div className="bg-gray-900 rounded-lg shadow-md p-4">
            <h3 className="text-sm font-medium text-white mb-3">Quick Start</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mb-4">
              <div>
                <p className="text-xs text-gray-400 mb-2">Sample Prompts:</p>
                <div className="space-y-1">
                  {samplePrompts.slice(0, 3).map((sample, idx) => (
                    <button
                      key={idx}
                      onClick={() => setPrompt(sample)}
                      className="w-full text-left text-xs p-2 rounded border border-gray-600 bg-gray-800 text-gray-200 hover:border-blue-500 hover:bg-gray-700 transition-colors"
                    >
                      {sample.length > 40 ? sample.substring(0, 40) + '...' : sample}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-2">Cache-Optimized Prefixes:</p>
                <div className="space-y-1">
                  {cachePrefixes.map((prefix, idx) => (
                    <button
                      key={idx}
                      onClick={() => setPrompt(prefix + ' ')}
                      className="w-full text-left text-xs p-2 rounded border border-green-600/30 bg-green-900/20 text-green-200 hover:border-green-500 hover:bg-green-800/30 transition-colors"
                    >
                      {prefix.length > 40 ? prefix.substring(0, 40) + '...' : prefix}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Main Input Form */}
          <form onSubmit={handleSubmit} className="bg-gray-900 rounded-lg shadow-md p-6">
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-white mb-2">
                  Your Prompt
                </label>
                <textarea
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  placeholder="Enter your prompt here... (try one of the cache-optimized prefixes for better performance)"
                  className="w-full h-32 p-3 border border-gray-600 bg-gray-800 text-white rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none placeholder-gray-400"
                  disabled={isLoading}
                />
              </div>

              {/* Settings Toggle */}
              <div className="flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => setShowAdvanced(!showAdvanced)}
                  className="text-sm text-blue-400 hover:text-blue-300 font-medium"
                >
                  {showAdvanced ? 'Hide' : 'Show'} Advanced Settings
                </button>
                <button
                  type="submit"
                  disabled={!prompt.trim() || isLoading}
                  className="flex items-center space-x-2 bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Generating...</span>
                    </>
                  ) : (
                    <>
                      <Send className="h-4 w-4" />
                      <span>Generate</span>
                    </>
                  )}
                </button>
              </div>

              {/* Advanced Settings */}
              {showAdvanced && (
                <div className="grid grid-cols-2 gap-4 p-4 bg-gray-800 rounded-lg">
                  <div>
                    <label className="block text-sm font-medium text-white mb-1">
                      Temperature: {temperature}
                    </label>
                    <input
                      type="range"
                      min="0"
                      max="1"
                      step="0.1"
                      value={temperature}
                      onChange={(e) => setTemperature(parseFloat(e.target.value))}
                      className="w-full"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-white mb-1">
                      Max Tokens: {maxTokens}
                    </label>
                    <input
                      type="range"
                      min="50"
                      max="500"
                      step="25"
                      value={maxTokens}
                      onChange={(e) => setMaxTokens(parseInt(e.target.value))}
                      className="w-full"
                    />
                  </div>
                </div>
              )}
            </div>
          </form>

          {/* Response Section */}
          <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-gray-900">Response</h3>
              {response && (
                <button
                  onClick={() => copyToClipboard(response)}
                  className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900"
                >
                  <Copy className="h-4 w-4" />
                  <span>Copy</span>
                </button>
              )}
            </div>
            <div
              ref={responseRef}
              className="min-h-[200px] max-h-[400px] p-4 bg-slate-50 rounded-lg overflow-y-auto custom-scrollbar"
            >
              {isLoading ? (
                <div className="flex items-center justify-center h-32">
                  <div className="flex items-center space-x-3 text-gray-600">
                    <Loader2 className="h-6 w-6 animate-spin text-llm-blue" />
                    <span>Processing your request...</span>
                  </div>
                </div>
              ) : response ? (
                <p className="text-gray-900 whitespace-pre-wrap leading-relaxed">
                  {response}
                </p>
              ) : (
                <p className="text-gray-500 italic">
                  Your model response will appear here...
                </p>
              )}
            </div>
          </div>
        </div>

        {/* History Sidebar */}
        <div className="space-y-6">
          <div className="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-gray-900">Request History</h3>
              {requestHistory.length > 0 && (
                <button
                  onClick={clearHistory}
                  className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900"
                >
                  <RotateCcw className="h-4 w-4" />
                  <span>Clear</span>
                </button>
              )}
            </div>
            
            <div className="space-y-3 max-h-96 overflow-y-auto custom-scrollbar">
              {requestHistory.length === 0 ? (
                <p className="text-gray-500 text-sm italic">No requests yet</p>
              ) : (
                requestHistory.map((entry) => (
                  <div
                    key={entry.id}
                    className="p-3 border border-slate-200 rounded-lg hover:border-slate-300 cursor-pointer"
                    onClick={() => setPrompt(entry.prompt)}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs text-gray-600">{entry.timestamp}</span>
                      <div className="flex items-center space-x-1 text-xs text-gray-600">
                        <Clock className="h-3 w-3" />
                        <span>{entry.latency}ms</span>
                      </div>
                    </div>
                    <p className="text-sm text-gray-900 mb-2 line-clamp-2">
                      {entry.prompt.length > 60 ? entry.prompt.substring(0, 60) + '...' : entry.prompt}
                    </p>
                    <p className="text-xs text-gray-600 line-clamp-2">
                      {entry.response.length > 80 ? entry.response.substring(0, 80) + '...' : entry.response}
                    </p>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Performance Hints */}
          <div className="bg-gradient-to-br from-green-50 to-emerald-50 rounded-lg border border-green-200 p-4">
            <div className="flex items-center space-x-2 mb-2">
              <Database className="h-4 w-4 text-green-600" />
              <h4 className="text-sm font-medium text-green-900">Cache Optimization Tips</h4>
            </div>
            <ul className="text-xs text-green-800 space-y-1">
              <li>• Use the green cache-optimized prefixes for better performance</li>
              <li>• Repeat similar prompts to see cache hits in action</li>
              <li>• Check the metrics tab to monitor cache hit rates</li>
              <li>• Try different prompt lengths to test P/D disaggregation</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};

export default InferencePlayground;

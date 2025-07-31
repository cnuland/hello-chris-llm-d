const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const http = require('http');
const https = require('https');

const app = express();
const PORT = process.env.PORT || 3001;

// Configuration
const config = {
  // In Kubernetes, this will be the service URL
  LLM_SERVICE_URL: process.env.LLM_SERVICE_URL || 'http://llama-3-2-1b-service-decode.llm-d.svc.cluster.local:8000',
  EPP_SERVICE_URL: process.env.EPP_SERVICE_URL || 'http://llama-3-2-1b-epp-service.llm-d.svc.cluster.local:9002',
  PROMETHEUS_URL: process.env.PROMETHEUS_URL || 'http://prometheus.llm-d-monitoring.svc.cluster.local:9090'
};

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'", "ws:", "wss:"]
    }
  }
}));

app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ['http://llm-d-frontend-route-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com', 'https://llm-d-frontend-route-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com'] 
    : ['http://localhost:3000'],
  credentials: true
}));

app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    services: {
      llm_service: config.LLM_SERVICE_URL,
      epp_service: config.EPP_SERVICE_URL,
      prometheus: config.PROMETHEUS_URL
    }
  });
});

// API routes
app.get('/api/status', (req, res) => {
  res.json({
    status: 'operational',
    services: {
      prefill: { status: 'healthy', pods: 1 },
      decode: { status: 'healthy', pods: 2 },
      epp: { status: 'healthy', pods: 1 }
    },
    metrics: {
      cache_hit_rate: 16.0,
      total_requests: 2002,
      active_connections: 0
    }
  });
});

// Native HTTP proxy to LLM service for completions
app.post('/api/v1/completions', async (req, res) => {
  const startTime = Date.now();
  console.log('Received completions request:', req.method, req.path);
  
  try {
    const url = new URL(config.LLM_SERVICE_URL);
    const requestData = JSON.stringify(req.body);
    
    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: '/v1/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestData),
        'User-Agent': 'LLM-D-Backend/1.0.0'
      },
      timeout: 30000
    };
    
    console.log('Forwarding to:', `${url.protocol}//${url.hostname}:${options.port}${options.path}`);
    
    const client = url.protocol === 'https:' ? https : http;
    
    const proxyReq = client.request(options, (proxyRes) => {
      console.log('LLM service response:', proxyRes.statusCode, `(${Date.now() - startTime}ms)`);
      
      // Set response headers
      res.status(proxyRes.statusCode);
      
      // Copy headers from the LLM service response
      Object.keys(proxyRes.headers).forEach(key => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, proxyRes.headers[key]);
        }
      });
      
      // Pipe the response
      proxyRes.pipe(res);
    });
    
    proxyReq.on('error', (err) => {
      console.error('LLM service request error:', err.message);
      if (!res.headersSent) {
        res.status(502).json({
          error: 'Service unavailable',
          message: 'Unable to connect to LLM service',
          details: err.message,
          target: config.LLM_SERVICE_URL
        });
      }
    });
    
    proxyReq.on('timeout', () => {
      console.error('LLM service request timeout');
      proxyReq.destroy();
      if (!res.headersSent) {
        res.status(504).json({
          error: 'Request timeout',
          message: 'LLM service did not respond in time',
          timeout: '30 seconds'
        });
      }
    });
    
    // Send the request body
    proxyReq.write(requestData);
    proxyReq.end();
    
  } catch (error) {
    console.error('Error setting up LLM service request:', error.message);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to process request',
      details: error.message
    });
  }
});

// EPP service endpoint (placeholder)
app.post('/api/v1/epp', (req, res) => {
  res.status(501).json({
    error: 'Not implemented',
    message: 'EPP service endpoint not yet implemented'
  });
});

// Metrics endpoint (placeholder)
app.get('/api/metrics', (req, res) => {
  res.status(501).json({
    error: 'Not implemented',
    message: 'Metrics endpoint not yet implemented'
  });
});

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../../frontend/build')));
  
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../../frontend/build', 'index.html'));
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 LLM-D Backend API Server running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 LLM Service URL: ${config.LLM_SERVICE_URL}`);
  console.log(`🔗 EPP Service URL: ${config.EPP_SERVICE_URL}`);
  console.log(`📈 Prometheus URL: ${config.PROMETHEUS_URL}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

module.exports = app;

import React, { useState, useEffect } from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Container,
  Grid,
  Card,
  CardContent,
  Tab,
  Tabs,
  Box,
  ThemeProvider,
  createTheme,
  CssBaseline,
  Alert,
  Chip,
  LinearProgress,
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  Memory as MemoryIcon,
  Speed as SpeedIcon,
  Cloud as CloudIcon,
  Settings as SettingsIcon,
} from '@mui/icons-material';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Toaster } from 'react-hot-toast';

import MetricsDashboard from './components/MetricsDashboard';
import InferencePlayground from './components/InferencePlayground';
import SchedulerVisualization from './components/SchedulerVisualization';
import DemoScenarios from './components/DemoScenarios';
import SystemOverview from './components/SystemOverview';
import { useWebSocket } from './hooks/useWebSocket';
import { useMetrics } from './hooks/useMetrics';
import './App.css';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#2196f3',
    },
    secondary: {
      main: '#f50057',
    },
    background: {
      default: '#0a0e1a',
      paper: '#1a1d2e',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
    h4: {
      fontWeight: 600,
    },
    h6: {
      fontWeight: 500,
    },
  },
  components: {
    MuiCard: {
      styleOverrides: {
        root: {
          backgroundImage: 'linear-gradient(135deg, #1a1d2e 0%, #16213e 100%)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          backgroundImage: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        },
      },
    },
  },
});

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`demo-tabpanel-${index}`}
      aria-labelledby={`demo-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

function a11yProps(index: number) {
  return {
    id: `demo-tab-${index}`,
    'aria-controls': `demo-tabpanel-${index}`,
  };
}

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchInterval: 5000, // Refetch every 5 seconds
      staleTime: 1000,
    },
  },
});

function App() {
  const [tabValue, setTabValue] = useState(0);
  const { isConnected, lastMessage, sendMessage } = useWebSocket('ws://localhost:8000/ws/metrics');
  const { 
    instances, 
    schedulerMetrics, 
    recentRequests, 
    summary,
    isLoading: metricsLoading 
  } = useMetrics();

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  const connectionStatus = isConnected ? 'Connected' : 'Disconnected';
  const connectionColor = isConnected ? 'success' : 'error';

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <div className="App">
          <AppBar position="static" elevation={0}>
            <Toolbar>
              <CloudIcon sx={{ mr: 2 }} />
              <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
                llm-d Demo: Kubernetes-Native Distributed LLM Inference
              </Typography>
              <Chip
                label={`WebSocket: ${connectionStatus}`}
                color={connectionColor as 'success' | 'error'}
                size="small"
                sx={{ mr: 2 }}
              />
              <Chip
                label={`Instances: ${summary?.total_instances || 0}`}
                color="primary"
                size="small"
                sx={{ mr: 1 }}
              />
              <Chip
                label={`Healthy: ${summary?.healthy_instances || 0}`}
                color="success"
                size="small"
              />
            </Toolbar>
            {metricsLoading && <LinearProgress />}
          </AppBar>

          <Container maxWidth={false} sx={{ mt: 2, mb: 2 }}>
            <Grid container spacing={2} sx={{ mb: 3 }}>
              <Grid item xs={12}>
                <SystemOverview 
                  summary={summary}
                  schedulerMetrics={schedulerMetrics}
                  instances={instances}
                />
              </Grid>
            </Grid>

            <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 2 }}>
              <Tabs
                value={tabValue}
                onChange={handleTabChange}
                aria-label="demo tabs"
                variant="scrollable"
                scrollButtons="auto"
              >
                <Tab
                  icon={<DashboardIcon />}
                  label="Live Dashboard"
                  {...a11yProps(0)}
                />
                <Tab
                  icon={<SpeedIcon />}
                  label="Inference Playground"
                  {...a11yProps(1)}
                />
                <Tab
                  icon={<MemoryIcon />}
                  label="Scheduler Visualization"
                  {...a11yProps(2)}
                />
                <Tab
                  icon={<SettingsIcon />}
                  label="Demo Scenarios"
                  {...a11yProps(3)}
                />
              </Tabs>
            </Box>

            <TabPanel value={tabValue} index={0}>
              <MetricsDashboard
                instances={instances}
                schedulerMetrics={schedulerMetrics}
                recentRequests={recentRequests}
                summary={summary}
                isConnected={isConnected}
              />
            </TabPanel>

            <TabPanel value={tabValue} index={1}>
              <InferencePlayground
                instances={instances}
                onRequestSubmit={(request) => {
                  console.log('Submitting inference request:', request);
                }}
              />
            </TabPanel>

            <TabPanel value={tabValue} index={2}>
              <SchedulerVisualization
                schedulerMetrics={schedulerMetrics}
                instances={instances}
                recentRequests={recentRequests}
              />
            </TabPanel>

            <TabPanel value={tabValue} index={3}>
              <DemoScenarios />
            </TabPanel>
          </Container>

          <Toaster
            position="bottom-right"
            toastOptions={{
              duration: 4000,
              style: {
                background: '#1a1d2e',
                color: '#fff',
                border: '1px solid rgba(255, 255, 255, 0.1)',
              },
            }}
          />
        </div>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App; 
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

import servicesRouter from './routes/services.js';
import cleanersRouter from './routes/cleaners.js';
import ordersRouter from './routes/orders.js';
import authRouter from './routes/auth.js';
import qualityReportsRouter from './routes/quality-reports.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// 1. Middleware Global
app.use(cors());
app.use(express.json());

// 2. Health Check Endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Resik.in Backend REST API is running',
    data: {
      status: 'UP',
      environment: process.env.NODE_ENV || 'development',
      timestamp: new Date().toISOString()
    }
  });
});

// 3. Mount Modular Routers
app.use('/api/services', servicesRouter);
app.use('/api/cleaners', cleanersRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/auth', authRouter);
app.use('/api/quality-reports', qualityReportsRouter);

// 4. Central 404 Not Found Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan`,
    error: 'ENDPOINT_NOT_FOUND'
  });
});

// 5. Central JSON Error Handler (Mencegah HTML Stack Leak)
app.use((err, req, res, next) => {
  const statusCode = err.status || err.statusCode || 500;
  console.error(`[SERVER ERROR] ${req.method} ${req.url}:`, err.message || err);

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Terjadi kesalahan internal pada server',
    error: err.code || 'INTERNAL_SERVER_ERROR'
  });
});

import { fileURLToPath } from 'url';

// 6. Start Server hanya jika file dieksekusi langsung (bukan saat di-import oleh test)
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  app.listen(PORT, () => {
    console.log(`[Resik.in] REST API Server running on port ${PORT}`);
    console.log(`[Resik.in] Health Check: http://localhost:${PORT}/api/health`);
    console.log(`[Resik.in] Services: http://localhost:${PORT}/api/services`);
  });
}

export default app;

import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
app.use(express.json());

app.get('/health', (_req: Request, res: Response) => res.json({ status: 'ok' }));

app.use((req: Request, _res: Response, next: NextFunction) => {
    const err: any = new Error('Not Found');
    err.status = 404;
    next(err);
});

app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || 500;
    res.status(status).json({ error: err.message || 'Internal Server Error' });
});

const port = Number(process.env.PORT) || 3000;
const server = http.createServer(app);

async function start() {
    await new Promise<void>((resolve) => server.listen(port, resolve));
    console.log(`Server listening on port ${port}`);
}

start();

const shutdown = (signal: string) => {
    console.log(`Received ${signal}, shutting down`);
    server.close((err?: Error) => {
        if (err) {
            console.error('Error during server close', err);
            process.exit(1);
        }
        process.exit(0);
    });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

export { app, server };
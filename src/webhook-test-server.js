const http = require('http');
const url = require('url');

const PORT = 3000;
const HOST = 'localhost';

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const path = parsedUrl.pathname;
    const method = req.method;

    console.log(`[${new Date().toISOString()}] ${method} ${path}`);

    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    if (path === '/health' && method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            service: 'webhook-test-server',
            uptime: process.uptime()
        }));
    } else if (path === '/webhook' && method === 'POST') {
        let body = '';
        
        req.on('data', chunk => {
            body += chunk.toString();
        });
        
        req.on('end', () => {
            console.log('Webhook received:', body);
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                message: 'Webhook received successfully',
                timestamp: new Date().toISOString(),
                received_data: body ? JSON.parse(body) : null
            }));
        });
    } else if (path === '/' && method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`
            <html>
            <head><title>Webhook Test Server</title></head>
            <body>
                <h1>Webhook Test Server</h1>
                <p>Server is running on port ${PORT}</p>
                <h2>Available Endpoints:</h2>
                <ul>
                    <li><code>GET /health</code> - Health check endpoint</li>
                    <li><code>POST /webhook</code> - Webhook receiver endpoint</li>
                </ul>
                <p>External URL: <a href="https://webhook.yeonsik.kim">https://webhook.yeonsik.kim</a></p>
            </body>
            </html>
        `);
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            error: 'Not Found',
            path: path,
            method: method
        }));
    }
});

server.listen(PORT, HOST, () => {
    console.log(`Webhook test server running at http://${HOST}:${PORT}/`);
    console.log(`External URL: https://webhook.yeonsik.kim`);
    console.log('\nAvailable endpoints:');
    console.log('  GET  /        - Homepage');
    console.log('  GET  /health  - Health check');
    console.log('  POST /webhook - Webhook receiver');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
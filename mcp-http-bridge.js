#!/usr/bin/env node

// Simple bridge that forwards MCP requests to HTTP server
const net = require('net');

class MCPBridge {
  constructor() {
    this.setupStdio();
  }

  setupStdio() {
    process.stdin.on('data', async (data) => {
      try {
        const request = JSON.parse(data.toString().trim());
        const response = await this.forwardToHTTP(request);
        process.stdout.write(JSON.stringify(response) + '\n');
      } catch (error) {
        const errorResponse = {
          jsonrpc: "2.0",
          error: { code: -32603, message: error.message },
          id: null
        };
        process.stdout.write(JSON.stringify(errorResponse) + '\n');
      }
    });
  }

  async forwardToHTTP(request) {
    const fetch = (await import('node-fetch')).default;
    
    try {
      const response = await fetch('http://localhost:27272', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request)
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      // If HTTP server is down, return an error
      return {
        jsonrpc: "2.0",
        error: { 
          code: -32603, 
          message: `MCP Play app not running: ${error.message}` 
        },
        id: request.id || null
      };
    }
  }
}

new MCPBridge();
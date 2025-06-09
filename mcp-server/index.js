#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class MCPPianoServer {
  constructor() {
    this.server = new Server(
      {
        name: 'mcp-piano-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.sequencesDir = path.join(__dirname, '..', 'MCP Play');
    this.setupToolHandlers();
    
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'play_sequence',
          description: 'Play a music sequence directly from JSON data',
          inputSchema: {
            type: 'object',
            properties: {
              sequence: {
                type: 'object',
                description: 'Music sequence to play',
                properties: {
                  version: { 
                    type: 'number', 
                    description: 'Schema version (always use 1)' 
                  },
                  tempo: { 
                    type: 'number', 
                    description: 'BPM (beats per minute), typically 60-200' 
                  },
                  instrument: { 
                    type: 'string', 
                    description: 'Instrument (use "acoustic_grand_piano")' 
                  },
                  events: {
                    type: 'array',
                    description: 'Array of musical events',
                    items: {
                      type: 'object',
                      properties: {
                        time: { 
                          type: 'number', 
                          description: 'Start time in beats (0.0, 1.0, 2.5, etc.)' 
                        },
                        pitches: { 
                          type: 'array', 
                          description: 'MIDI numbers (60-127) or note names like "C4", "F#3"',
                          items: { 
                            oneOf: [
                              { type: 'number' }, 
                              { type: 'string' }
                            ] 
                          }
                        },
                        duration: { 
                          type: 'number', 
                          description: 'Length in beats (1.0 = quarter note, 0.5 = eighth note)' 
                        },
                        velocity: { 
                          type: 'number', 
                          description: 'Volume 0-127 (optional, defaults to 100)' 
                        }
                      },
                      required: ['time', 'pitches', 'duration']
                    }
                  }
                },
                required: ['version', 'tempo', 'instrument', 'events']
              },
            },
            required: ['sequence'],
          },
        },
        {
          name: 'stop',
          description: 'Stop any currently playing music',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'play_sequence':
            return await this.playSequence(args.sequence);
          
          case 'stop':
            return await this.stop();
          
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async playSequence(sequence) {
    try {
      const jsonString = JSON.stringify(sequence);
      const jsonSize = Buffer.byteLength(jsonString, 'utf8');
      
      if (jsonSize < 2000) {
        // Small sequence - pass directly in URL
        const encodedJson = encodeURIComponent(jsonString);
        const url = `mcpplay://play?json=${encodedJson}`;
        await this.openURL(url);
      } else {
        // Large sequence - write to file and reference by name
        const timestamp = Date.now();
        const tempFileName = `temp_sequence_${timestamp}`;
        const tempFilePath = path.join(this.sequencesDir, `${tempFileName}.json`);
        
        await fs.writeFile(tempFilePath, JSON.stringify(sequence, null, 2));
        
        const url = `mcpplay://play?sequence=${tempFileName}`;
        await this.openURL(url);
      }
      
      return {
        content: [
          {
            type: 'text',
            text: `Playing music sequence at ${sequence.tempo} BPM with ${sequence.events.length} events`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to play sequence: ${error.message}`);
    }
  }

  async stop() {
    try {
      const url = 'mcpplay://stop';
      await this.openURL(url);
      
      return {
        content: [
          {
            type: 'text',
            text: 'Stopped playback',
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to stop playback: ${error.message}`);
    }
  }

  async openURL(url) {
    return new Promise((resolve, reject) => {
      console.error(`Opening URL: ${url}`);
      const process = spawn('open', [url], { stdio: ['ignore', 'pipe', 'pipe'] });
      
      let stderr = '';
      process.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      process.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          console.error(`open command failed with code ${code}, stderr: ${stderr}`);
          reject(new Error(`Failed to open URL (code ${code}): ${url}`));
        }
      });
      
      process.on('error', (error) => {
        console.error(`spawn error: ${error}`);
        reject(new Error(`Failed to spawn open command: ${error.message}`));
      });
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('MCP Piano Server running on stdio');
  }
}

const server = new MCPPianoServer();
server.run().catch(console.error);
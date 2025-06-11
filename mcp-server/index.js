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
              version: { 
                type: 'number', 
                description: 'Schema version (always use 1)'
              },
              title: {
                type: 'string',
                description: 'Optional title for the sequence'
              },
              tempo: {
                type: 'number',
                description: 'BPM (beats per minute), typically 60-200'
              },
              tracks: {
                type: 'array',
                description: 'Array of track objects',
                items: {
                  type: 'object',
                  properties: {
                    instrument: {
                      type: 'string',
                      description: 'Instrument name (e.g., "acoustic_grand_piano", "string_ensemble_1")'
                    },
                    name: {
                      type: 'string',
                      description: 'Optional track name or description'
                    },
                    events: {
                      type: 'array',
                      description: 'Array of musical events for this track',
                      items: {
                        type: 'object',
                        properties: {
                          time: {
                            type: 'number',
                            description: 'Start time in beats (0.0, 1.0, 2.5, etc.)'
                          },
                          pitches: {
                            type: 'array',
                            description: 'MIDI numbers (0-127) or note names like "C4", "F#3"',
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
                  required: ['instrument', 'events']
                }
              }
            },
            required: ['version', 'tempo', 'tracks'],
          },
        },
        {
          name: 'list_instruments',
          description: 'List all available instruments organized by category',
          inputSchema: {
            type: 'object',
            properties: {},
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
            return await this.playSequence(args);
          
          case 'list_instruments':
            return await this.listInstruments();
          
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
      // Validate sequence structure
      if (!sequence || typeof sequence !== 'object') {
        throw new Error('Invalid sequence: must be an object');
      }
      
      if (typeof sequence.tempo !== 'number') {
        throw new Error('Invalid sequence: tempo must be a number');
      }
      
      if (!Array.isArray(sequence.tracks)) {
        throw new Error('Invalid sequence: tracks must be an array');
      }
      
      if (sequence.tracks.length === 0) {
        throw new Error('Invalid sequence: must have at least one track');
      }
      
      // Get valid instrument names for validation
      const validInstruments = this.getValidInstrumentNames();
      
      // Validate each track
      for (let i = 0; i < sequence.tracks.length; i++) {
        const track = sequence.tracks[i];
        if (!track || typeof track !== 'object') {
          throw new Error(`Invalid track ${i}: must be an object`);
        }
        
        if (typeof track.instrument !== 'string') {
          throw new Error(`Invalid track ${i}: instrument must be a string`);
        }
        
        if (!validInstruments.includes(track.instrument)) {
          throw new Error(`Invalid track ${i}: instrument "${track.instrument}" is not available. Use list_instruments tool to see valid options.`);
        }
        
        if (!Array.isArray(track.events)) {
          throw new Error(`Invalid track ${i}: events must be an array`);
        }
      }
      
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
        // Ensure temp_sequences subfolder exists
        const tempDir = path.join(this.sequencesDir, 'temp_sequences');
        await fs.mkdir(tempDir, { recursive: true });
        const tempFilePath = path.join(tempDir, `${tempFileName}.json`);

        await fs.writeFile(tempFilePath, JSON.stringify(sequence, null, 2));

        const url = `mcpplay://play?sequence=${tempFileName}`;
        await this.openURL(url);
      }
      
      // Summarize total events and tracks
      let totalEvents = 0;
      let trackCount = 0;
      if (sequence && Array.isArray(sequence.tracks)) {
        trackCount = sequence.tracks.length;
        totalEvents = sequence.tracks.reduce((sum, t) => {
          return sum + (t && Array.isArray(t.events) ? t.events.length : 0);
        }, 0);
      } else if (sequence && Array.isArray(sequence.events)) {
        // Legacy format support
        trackCount = 1;
        totalEvents = sequence.events.length;
      }
      const summary = `Playing music sequence at ${sequence.tempo} BPM with ${totalEvents} event${totalEvents === 1 ? '' : 's'}` +
                      (trackCount > 1 ? ` across ${trackCount} tracks` : '');
      return {
        content: [
          {
            type: 'text',
            text: summary,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to play sequence: ${error.message}`);
    }
  }

  getInstrumentsData() {
    return {
      "Piano": [
        { name: "acoustic_grand_piano", display: "Acoustic Grand Piano" },
        { name: "bright_acoustic_piano", display: "Bright Acoustic Piano" },
        { name: "electric_grand_piano", display: "Electric Grand Piano" },
        { name: "honky_tonk_piano", display: "Honky Tonk Piano" },
        { name: "electric_piano_1", display: "Electric Piano 1" },
        { name: "electric_piano_2", display: "Electric Piano 2" },
        { name: "harpsichord", display: "Harpsichord" },
        { name: "clavinet", display: "Clavinet" }
      ],
      "Percussion": [
        { name: "celesta", display: "Celesta" },
        { name: "glockenspiel", display: "Glockenspiel" },
        { name: "music_box", display: "Music Box" },
        { name: "vibraphone", display: "Vibraphone" },
        { name: "marimba", display: "Marimba" },
        { name: "xylophone", display: "Xylophone" },
        { name: "tubular_bells", display: "Tubular Bells" },
        { name: "dulcimer", display: "Dulcimer" }
      ],
      "Organ": [
        { name: "drawbar_organ", display: "Drawbar Organ" },
        { name: "percussive_organ", display: "Percussive Organ" },
        { name: "rock_organ", display: "Rock Organ" },
        { name: "church_organ", display: "Church Organ" },
        { name: "reed_organ", display: "Reed Organ" },
        { name: "accordion", display: "Accordion" },
        { name: "harmonica", display: "Harmonica" },
        { name: "tango_accordion", display: "Tango Accordion" }
      ],
      "Guitar": [
        { name: "acoustic_guitar_nylon", display: "Acoustic Guitar (Nylon)" },
        { name: "acoustic_guitar_steel", display: "Acoustic Guitar (Steel)" },
        { name: "electric_guitar_jazz", display: "Electric Guitar (Jazz)" },
        { name: "electric_guitar_clean", display: "Electric Guitar (Clean)" },
        { name: "electric_guitar_muted", display: "Electric Guitar (Muted)" },
        { name: "overdriven_guitar", display: "Overdriven Guitar" },
        { name: "distortion_guitar", display: "Distortion Guitar" },
        { name: "guitar_harmonics", display: "Guitar Harmonics" }
      ],
      "Bass": [
        { name: "acoustic_bass", display: "Acoustic Bass" },
        { name: "electric_bass_finger", display: "Electric Bass (Finger)" },
        { name: "electric_bass_pick", display: "Electric Bass (Pick)" },
        { name: "fretless_bass", display: "Fretless Bass" },
        { name: "slap_bass_1", display: "Slap Bass 1" },
        { name: "slap_bass_2", display: "Slap Bass 2" },
        { name: "synth_bass_1", display: "Synth Bass 1" },
        { name: "synth_bass_2", display: "Synth Bass 2" }
      ],
      "Strings": [
        { name: "violin", display: "Violin" },
        { name: "viola", display: "Viola" },
        { name: "cello", display: "Cello" },
        { name: "contrabass", display: "Contrabass" },
        { name: "tremolo_strings", display: "Tremolo Strings" },
        { name: "pizzicato_strings", display: "Pizzicato Strings" },
        { name: "orchestral_harp", display: "Orchestral Harp" },
        { name: "timpani", display: "Timpani" },
        { name: "string_ensemble_1", display: "String Ensemble 1" },
        { name: "string_ensemble_2", display: "String Ensemble 2" },
        { name: "synth_strings_1", display: "Synth Strings 1" },
        { name: "synth_strings_2", display: "Synth Strings 2" }
      ],
      "Brass": [
        { name: "trumpet", display: "Trumpet" },
        { name: "trombone", display: "Trombone" },
        { name: "tuba", display: "Tuba" },
        { name: "muted_trumpet", display: "Muted Trumpet" },
        { name: "french_horn", display: "French Horn" },
        { name: "brass_section", display: "Brass Section" },
        { name: "synth_brass_1", display: "Synth Brass 1" },
        { name: "synth_brass_2", display: "Synth Brass 2" }
      ],
      "Woodwinds": [
        { name: "soprano_sax", display: "Soprano Sax" },
        { name: "alto_sax", display: "Alto Sax" },
        { name: "tenor_sax", display: "Tenor Sax" },
        { name: "baritone_sax", display: "Baritone Sax" },
        { name: "oboe", display: "Oboe" },
        { name: "english_horn", display: "English Horn" },
        { name: "bassoon", display: "Bassoon" },
        { name: "clarinet", display: "Clarinet" },
        { name: "piccolo", display: "Piccolo" },
        { name: "flute", display: "Flute" },
        { name: "recorder", display: "Recorder" },
        { name: "pan_flute", display: "Pan Flute" },
        { name: "blown_bottle", display: "Blown Bottle" },
        { name: "shakuhachi", display: "Shakuhachi" },
        { name: "whistle", display: "Whistle" },
        { name: "ocarina", display: "Ocarina" }
      ],
      "Choir": [
        { name: "choir_aahs", display: "Choir Aahs" },
        { name: "voice_oohs", display: "Voice Oohs" },
        { name: "synth_voice", display: "Synth Voice" },
        { name: "orchestra_hit", display: "Orchestra Hit" }
      ]
    };
  }

  getValidInstrumentNames() {
    const instruments = this.getInstrumentsData();
    // Extract all instrument names
    const allInstruments = [];
    for (const categoryInstruments of Object.values(instruments)) {
      for (const instrument of categoryInstruments) {
        allInstruments.push(instrument.name);
      }
    }
    return allInstruments;
  }

  async listInstruments() {
    const instruments = this.getInstrumentsData();

    let output = "Available Instruments:\n\n";
    
    for (const [category, categoryInstruments] of Object.entries(instruments)) {
      output += `**${category}:**\n`;
      for (const instrument of categoryInstruments) {
        output += `- ${instrument.name} (${instrument.display})\n`;
      }
      output += "\n";
    }
    
    output += "Use the instrument 'name' (left side) in your track definitions.";

    return {
      content: [
        {
          type: 'text',
          text: output,
        },
      ],
    };
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
      
      // Check if MCP Play app is already running
      const checkProcess = spawn('pgrep', ['-f', 'MCP Play'], { stdio: ['ignore', 'pipe', 'pipe'] });
      
      checkProcess.on('close', (code) => {
        let openArgs;
        if (code === 0) {
          // App is running - send URL to existing instance without launching new one
          openArgs = ['-g', url]; // -g flag prevents app activation/launching
          console.error('App already running, sending URL to existing instance');
        } else {
          // App not running - use normal open which will launch it
          openArgs = [url];
          console.error('App not running, launching app');
        }
        
        const openProcess = spawn('open', openArgs, { stdio: ['ignore', 'pipe', 'pipe'] });
        
        let stderr = '';
        openProcess.stderr.on('data', (data) => {
          stderr += data.toString();
        });
        
        openProcess.on('close', (openCode) => {
          if (openCode === 0) {
            resolve();
          } else {
            console.error(`open command failed with code ${openCode}, stderr: ${stderr}`);
            reject(new Error(`Failed to open URL (code ${openCode}): ${url}`));
          }
        });
        
        openProcess.on('error', (error) => {
          console.error(`spawn error: ${error}`);
          reject(new Error(`Failed to spawn open command: ${error.message}`));
        });
      });
      
      checkProcess.on('error', (error) => {
        console.error(`pgrep error: ${error}, falling back to normal open`);
        // Fall back to normal open if pgrep fails
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
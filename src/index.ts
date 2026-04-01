#!/usr/bin/env node

import { Command } from 'commander';
import * as fs from 'fs-extra';
import * as path from 'path';
import inquirer from 'inquirer';
import * as https from 'https';
import * as http from 'http';

const CONFIG_PATH = path.join(process.env.HOME || '', '.config', 'submit-to-cli', 'config.json');
const DEFAULT_BASE_URL = 'https://aidirs.org';

interface Config {
  AIDIRS_TOKEN: string;
  AIDIRS_BASE_URL: string;
}

async function loadConfig(): Promise<Config> {
  if (!(await fs.pathExists(CONFIG_PATH))) {
    throw new Error(`Not logged in. Run 'submit-to-cli login' first.`);
  }
  const config = await fs.readJson(CONFIG_PATH);
  if (!config.AIDIRS_TOKEN) {
    throw new Error(`AIDIRS_TOKEN not found in config. Run 'submit-to-cli login' first.`);
  }
  return config;
}

async function httpPost(baseUrl: string, token: string, endpoint: string, body: object): Promise<unknown> {
  const url = new URL(endpoint, baseUrl);
  const isHttps = url.protocol === 'https:';
  const httpMod = isHttps ? https : http;

  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = httpMod.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'Authorization': `Bearer ${token}`,
      },
    }, (res) => {
      let body = '';
      res.on('data', (chunk: string) => { body += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          resolve({ status: res.statusCode, data: json });
        } catch {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function login() {
  console.log('Logging in to aidirs.org...\n');
  const inq = (inquirer as any).createPromptModule();
  const answers = await inq([
    {
      type: 'input',
      name: 'AIDIRS_TOKEN',
      message: 'Enter your AIDIRS_TOKEN:',
      validate: (input: string) => input.trim().length > 0 ? true : 'Token cannot be empty',
    },
    {
      type: 'input',
      name: 'AIDIRS_BASE_URL',
      message: 'Enter the API base URL:',
      default: DEFAULT_BASE_URL,
      validate: (input: string) => {
        try {
          new URL(input);
          return true;
        } catch {
          return 'Please enter a valid URL';
        }
      },
    },
  ]);

  const config: Config = {
    AIDIRS_TOKEN: String(answers.AIDIRS_TOKEN).trim(),
    AIDIRS_BASE_URL: String(answers.AIDIRS_BASE_URL).trim().replace(/\/$/, ''),
  };

  await fs.ensureFile(CONFIG_PATH);
  await fs.writeJson(CONFIG_PATH, config, { spaces: 2 });
  console.log(`\n✅ Login saved to ${CONFIG_PATH}`);
}

async function submit(url: string) {
  const config = await loadConfig();
  console.log(`Submitting ${url} to ${config.AIDIRS_BASE_URL}...`);
  try {
    const result = await httpPost(config.AIDIRS_BASE_URL, config.AIDIRS_TOKEN, '/api/submit', { link: url }) as any;
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
  } catch (err: any) {
    console.error(`❌ Error: ${err.message}`);
    process.exit(1);
  }
}

async function fetch(url: string) {
  const config = await loadConfig();
  console.log(`Fetching preview for ${url} from ${config.AIDIRS_BASE_URL}...`);
  try {
    const result = await httpPost(config.AIDIRS_BASE_URL, config.AIDIRS_TOKEN, '/api/fetch-website', { link: url }) as any;
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
  } catch (err: any) {
    console.error(`❌ Error: ${err.message}`);
    process.exit(1);
  }
}

const program = new Command();

program
  .name('submit-to-cli')
  .description('CLI tool for submitting URLs to aidirs.org')
  .version('1.0.0');

program
  .command('login')
  .description('Login and save API token')
  .action(login);

program
  .command('submit <url>')
  .description('Submit a URL to aidirs')
  .action(submit);

program
  .command('fetch <url>')
  .description('Preview a URL without creating a record')
  .action(fetch);

program.parse(process.argv);

// Show help if no command provided
if (process.argv.length === 2) {
  program.help();
}

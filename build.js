#!/usr/bin/env node

const fs = require('fs').promises;
const path = require('path');
const { execSync, spawn } = require('child_process');
const archiver = require('archiver');
const FormData = require('form-data');
const https = require('https');

const CONFIG = {
    PROJECT_NAME: 'GrouperPlus',
    BUILD_DIR: 'build',
    
    // CurseForge API configuration
    API_TOKEN: process.env.CURSEFORGE_API_TOKEN,
    PROJECT_ID: process.env.CURSEFORGE_PROJECT_ID,
    BASE_URL: 'https://wow.curseforge.com',
    UPLOAD_ENDPOINT: '/api/projects/{projectId}/upload-file',
    GAME_VERSIONS_ENDPOINT: '/api/game/versions',
    WOW_GAME_ID: 1,
    RELEASE_TYPE: 'release',
    CHANGELOG_TYPE: 'markdown',
    
    // Files to copy
    COPY_PATTERNS: [
        { pattern: 'libs', type: 'directory' },
        { pattern: 'modules', type: 'directory' },
        { pattern: 'textures', type: 'directory', optional: true },
        { pattern: '*.lua', type: 'glob' },
        { pattern: '*.toc', type: 'glob' },
        { pattern: 'CHANGELOG.md', type: 'file', optional: true },
        { pattern: 'README.md', type: 'file', optional: true }
    ],
    
    // Files to exclude from build
    EXCLUDE_PATTERNS: [
        '*.sh', '*.js', '*.json', '.gitignore', 'CLAUDE.md',
        'node_modules', 'build', '.DS_Store'
    ]
};

class Logger {
    static info(message, ...args) {
        console.log(`ℹ️  ${message}`, ...args);
    }
    
    static success(message, ...args) {
        console.log(`✅ ${message}`, ...args);
    }
    
    static warn(message, ...args) {
        console.log(`⚠️  ${message}`, ...args);
    }
    
    static error(message, ...args) {
        console.error(`❌ ${message}`, ...args);
    }
    
    static step(message, ...args) {
        console.log(`🔨 ${message}`, ...args);
    }
    
    static rocket(message, ...args) {
        console.log(`🚀 ${message}`, ...args);
    }
}

class TOCParser {
    constructor(tocPath) {
        this.tocPath = tocPath;
        this.metadata = null;
    }
    
    async parse() {
        try {
            const tocContent = await fs.readFile(this.tocPath, 'utf8');
            this.metadata = {};
            
            const lines = tocContent.split('\n');
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed.startsWith('## ')) {
                    const [key, ...valueParts] = trimmed.substring(3).split(':');
                    if (valueParts.length > 0) {
                        this.metadata[key.trim()] = valueParts.join(':').trim();
                    }
                }
            }
            
            return this.metadata;
        } catch (error) {
            throw new Error(`Failed to read TOC file: ${error.message}`);
        }
    }
    
    get version() {
        return this.metadata?.Version || 'unknown';
    }
    
    get title() {
        return this.metadata?.Title || CONFIG.PROJECT_NAME;
    }
    
    get interface() {
        return this.metadata?.Interface;
    }
}

class FileOperations {
    static async pathExists(filePath) {
        try {
            await fs.access(filePath);
            return true;
        } catch {
            return false;
        }
    }
    
    static async copyPath(src, dest) {
        const stat = await fs.lstat(src);
        
        if (stat.isDirectory()) {
            await this.copyDirectory(src, dest);
        } else {
            await this.ensureDirectoryExists(path.dirname(dest));
            await fs.copyFile(src, dest);
        }
    }
    
    static async copyDirectory(src, dest) {
        await this.ensureDirectoryExists(dest);
        const entries = await fs.readdir(src, { withFileTypes: true });
        
        for (const entry of entries) {
            const srcPath = path.join(src, entry.name);
            const destPath = path.join(dest, entry.name);
            
            if (entry.isDirectory()) {
                await this.copyDirectory(srcPath, destPath);
            } else {
                await fs.copyFile(srcPath, destPath);
            }
        }
    }
    
    static async ensureDirectoryExists(dirPath) {
        try {
            await fs.mkdir(dirPath, { recursive: true });
        } catch (error) {
            if (error.code !== 'EEXIST') throw error;
        }
    }
    
    static async removeDirectory(dirPath) {
        try {
            await fs.rm(dirPath, { recursive: true, force: true });
        } catch (error) {
            // Ignore if directory doesn't exist
            if (error.code !== 'ENOENT') throw error;
        }
    }
    
    static async findFiles(pattern, directory = '.') {
        const { glob } = await import('glob');
        return glob(pattern, { cwd: directory });
    }
    
    static async createZipArchive(sourceDir, outputPath) {
        return new Promise((resolve, reject) => {
            const output = require('fs').createWriteStream(outputPath);
            const archive = archiver('zip', { zlib: { level: 9 } });
            
            output.on('close', () => resolve(archive.pointer()));
            archive.on('error', reject);
            
            archive.pipe(output);
            archive.directory(sourceDir, false);
            archive.finalize();
        });
    }
    
    static async removeFile(filePath) {
        try {
            await fs.unlink(filePath);
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
        }
    }
    
    static async removeDSStoreFiles(directory) {
        const dsStoreFiles = await this.findFiles('**/.DS_Store', directory);
        for (const file of dsStoreFiles) {
            await this.removeFile(path.join(directory, file));
        }
    }
}

class PrerequisiteValidator {
    static async validate(requireDeploy = false) {
        Logger.step('Checking prerequisites...');
        
        // Check Node.js
        try {
            const nodeVersion = execSync('node --version', { encoding: 'utf8' }).trim();
            Logger.info(`Node.js version: ${nodeVersion}`);
        } catch {
            throw new Error('Node.js is required but not installed');
        }
        
        // Check npm
        try {
            const npmVersion = execSync('npm --version', { encoding: 'utf8' }).trim();
            Logger.info(`npm version: ${npmVersion}`);
        } catch {
            throw new Error('npm is required but not installed');
        }
        
        if (requireDeploy) {
            // Check environment variables for deployment
            if (!CONFIG.API_TOKEN) {
                throw new Error('CURSEFORGE_API_TOKEN environment variable is required\n💡 Set it with: export CURSEFORGE_API_TOKEN=your_token_here');
            }
            
            if (!CONFIG.PROJECT_ID) {
                throw new Error('CURSEFORGE_PROJECT_ID environment variable is required\n💡 Set it with: export CURSEFORGE_PROJECT_ID=your_project_id_here');
            }
            
            Logger.info(`CurseForge Project ID: ${CONFIG.PROJECT_ID}`);
        }
        
        // Install dependencies if needed
        if (!await FileOperations.pathExists('node_modules')) {
            Logger.step('Installing dependencies...');
            execSync('npm install', { stdio: 'inherit' });
        }
    }
}

class BuildPipeline {
    constructor() {
        this.tocParser = null;
        this.packageDir = null;
        this.archivePath = null;
    }
    
    async build() {
        Logger.rocket('Starting build process...');
        
        // Parse TOC file
        const tocFiles = await FileOperations.findFiles('*.toc');
        if (tocFiles.length === 0) {
            throw new Error('No TOC file found');
        }
        
        this.tocParser = new TOCParser(tocFiles[0]);
        await this.tocParser.parse();
        
        Logger.info(`Building ${CONFIG.PROJECT_NAME} v${this.tocParser.version}`);
        
        // Setup directories
        this.packageDir = path.join(CONFIG.BUILD_DIR, CONFIG.PROJECT_NAME);
        await FileOperations.removeDirectory(CONFIG.BUILD_DIR);
        await FileOperations.ensureDirectoryExists(this.packageDir);
        
        // Copy files
        Logger.step('Copying addon files...');
        await this.copyAddonFiles();
        
        // Cleanup development files
        Logger.step('Cleaning up development files...');
        await this.cleanupDevelopmentFiles();
        
        // Remove .DS_Store files
        Logger.step('Removing .DS_Store files...');
        await FileOperations.removeDSStoreFiles(this.packageDir);
        
        // Create archive
        Logger.step('Creating archive...');
        const archiveName = `${CONFIG.PROJECT_NAME}-v${this.tocParser.version}.zip`;
        this.archivePath = path.join(CONFIG.BUILD_DIR, archiveName);
        
        const archiveSize = await FileOperations.createZipArchive(this.packageDir, this.archivePath);
        
        Logger.success(`Build complete! Archive created at: ${this.archivePath}`);
        Logger.info(`Archive size: ${(archiveSize / 1024 / 1024).toFixed(2)} MB`);
        
        return {
            archivePath: this.archivePath,
            version: this.tocParser.version,
            tocParser: this.tocParser
        };
    }
    
    async copyAddonFiles() {
        for (const copyPattern of CONFIG.COPY_PATTERNS) {
            try {
                if (copyPattern.type === 'directory') {
                    if (await FileOperations.pathExists(copyPattern.pattern)) {
                        await FileOperations.copyPath(copyPattern.pattern, path.join(this.packageDir, copyPattern.pattern));
                    } else if (!copyPattern.optional) {
                        throw new Error(`Required directory not found: ${copyPattern.pattern}`);
                    } else {
                        Logger.warn(`Optional directory not found, skipping: ${copyPattern.pattern}`);
                    }
                } else if (copyPattern.type === 'glob') {
                    const files = await FileOperations.findFiles(copyPattern.pattern);
                    for (const file of files) {
                        await FileOperations.copyPath(file, path.join(this.packageDir, file));
                    }
                } else if (copyPattern.type === 'file') {
                    if (await FileOperations.pathExists(copyPattern.pattern)) {
                        await FileOperations.copyPath(copyPattern.pattern, path.join(this.packageDir, copyPattern.pattern));
                    } else if (!copyPattern.optional) {
                        throw new Error(`Required file not found: ${copyPattern.pattern}`);
                    } else {
                        Logger.warn(`Optional file not found, skipping: ${copyPattern.pattern}`);
                    }
                }
            } catch (error) {
                if (!copyPattern.optional) throw error;
                Logger.warn(`Failed to copy optional ${copyPattern.type}: ${copyPattern.pattern}`);
            }
        }
    }
    
    async cleanupDevelopmentFiles() {
        for (const pattern of CONFIG.EXCLUDE_PATTERNS) {
            try {
                if (pattern === 'node_modules' || pattern === 'build') {
                    await FileOperations.removeDirectory(path.join(this.packageDir, pattern));
                } else {
                    const files = await FileOperations.findFiles(pattern, this.packageDir);
                    for (const file of files) {
                        await FileOperations.removeFile(path.join(this.packageDir, file));
                    }
                }
            } catch (error) {
                // Silently ignore cleanup errors
            }
        }
    }
}

class CurseForgeDeployer {
    constructor(buildResult) {
        this.buildResult = buildResult;
    }
    
    getGameVersions() {
        const interfaceVersionMap = {
            '110200': [13433], // The War Within (11.2.0)
            '110107': [13203], // The War Within (11.1.7)
            '110105': [12918], // The War Within (11.1.5)
            '110007': [12215], // The War Within (11.0.7)
            '110005': [11926], // The War Within (11.0.5)
            '110002': [11596], // The War Within (11.0.2)
            '110000': [11274], // The War Within (11.0.0)
        };
        
        const interfaceVersion = this.buildResult.tocParser.interface;
        
        if (interfaceVersionMap[interfaceVersion]) {
            return interfaceVersionMap[interfaceVersion];
        }
        
        Logger.warn(`Unknown interface version: ${interfaceVersion}, using latest`);
        return [13433]; // Default to latest
    }
    
    async generateChangelog() {
        try {
            const changelogPath = path.join(__dirname, 'CHANGELOG.md');
            
            if (await FileOperations.pathExists(changelogPath)) {
                const changelog = await fs.readFile(changelogPath, 'utf8');
                const lines = changelog.split('\n');
                const changes = [];
                let inLatestVersion = false;
                
                for (const line of lines) {
                    if (line.startsWith('## ') && !inLatestVersion) {
                        inLatestVersion = true;
                        continue;
                    } else if (line.startsWith('## ') && inLatestVersion) {
                        break;
                    }
                    
                    if (inLatestVersion && line.trim()) {
                        changes.push(line);
                    }
                }
                
                return changes.join('\n') || 'New release with improvements and bug fixes.';
            }
        } catch (error) {
            Logger.warn('Could not read changelog, using fallback');
        }
        
        return `Release version ${this.buildResult.version}\n\nSee README.md for detailed feature information.`;
    }
    
    async deploy() {
        Logger.rocket('Deploying to CurseForge...');
        Logger.info(`Project ID: ${CONFIG.PROJECT_ID}`);
        Logger.info(`Package: ${this.buildResult.archivePath}`);
        
        const gameVersions = this.getGameVersions();
        const changelog = await this.generateChangelog();
        
        const metadata = {
            changelog: changelog,
            changelogType: CONFIG.CHANGELOG_TYPE,
            displayName: `${this.buildResult.tocParser.title} v${this.buildResult.version}`,
            gameVersions: gameVersions,
            releaseType: CONFIG.RELEASE_TYPE
        };
        
        Logger.info('Upload metadata:', JSON.stringify(metadata, null, 2));
        
        const form = new FormData();
        form.append('metadata', JSON.stringify(metadata));
        form.append('file', await fs.readFile(this.buildResult.archivePath), {
            filename: `${CONFIG.PROJECT_NAME}.zip`,
            contentType: 'application/zip'
        });
        
        const result = await this.makeApiRequest('POST', CONFIG.UPLOAD_ENDPOINT.replace('{projectId}', CONFIG.PROJECT_ID), form);
        
        Logger.success('Upload successful!');
        Logger.info(`File ID: ${result.id}`);
        Logger.info('Download URL will be available after approval');
        
        return result;
    }
    
    async makeApiRequest(method, endpoint, data) {
        return new Promise((resolve, reject) => {
            const url = CONFIG.BASE_URL + endpoint;
            const options = {
                method: method,
                headers: {
                    'X-Api-Token': CONFIG.API_TOKEN,
                    ...data.getHeaders?.() || {}
                }
            };
            
            const req = https.request(url, options, (res) => {
                let responseData = '';
                
                res.on('data', (chunk) => {
                    responseData += chunk;
                });
                
                res.on('end', () => {
                    try {
                        const parsedData = JSON.parse(responseData);
                        
                        if (res.statusCode >= 200 && res.statusCode < 300) {
                            resolve(parsedData);
                        } else {
                            reject(new Error(`API request failed: ${res.statusCode} - ${parsedData.errorMessage || responseData}`));
                        }
                    } catch (error) {
                        if (res.statusCode >= 200 && res.statusCode < 300) {
                            resolve(responseData);
                        } else {
                            reject(new Error(`API request failed: ${res.statusCode} - ${responseData}`));
                        }
                    }
                });
            });
            
            req.on('error', (error) => {
                reject(error);
            });
            
            if (data && typeof data.pipe === 'function') {
                data.pipe(req);
            } else {
                req.end();
            }
        });
    }
}

class CLI {
    static showUsage() {
        console.log(`
GrouperPlus Build & Deploy Tool

Usage:
  node build.js build              Build addon package only
  node build.js deploy             Build and deploy to CurseForge
  node build.js --help            Show this help message

Environment Variables (for deploy):
  CURSEFORGE_API_TOKEN            Your CurseForge API token
  CURSEFORGE_PROJECT_ID          Your CurseForge project ID

Examples:
  node build.js build
  node build.js deploy
        `);
    }
    
    static async run() {
        const args = process.argv.slice(2);
        const command = args[0];
        
        if (!command || command === '--help' || command === '-h') {
            this.showUsage();
            return;
        }
        
        try {
            if (command === 'build') {
                await this.runBuild();
            } else if (command === 'deploy') {
                await this.runDeploy();
            } else {
                Logger.error(`Unknown command: ${command}`);
                this.showUsage();
                process.exit(1);
            }
        } catch (error) {
            Logger.error(`Operation failed: ${error.message}`);
            process.exit(1);
        }
    }
    
    static async runBuild() {
        await PrerequisiteValidator.validate(false);
        const buildPipeline = new BuildPipeline();
        const buildResult = await buildPipeline.build();
        
        Logger.success('Build pipeline completed successfully!');
        return buildResult;
    }
    
    static async runDeploy() {
        await PrerequisiteValidator.validate(true);
        const buildResult = await this.runBuild();
        
        const deployer = new CurseForgeDeployer(buildResult);
        await deployer.deploy();
        
        Logger.success('Deployment pipeline completed successfully!');
        Logger.info('');
        Logger.info('📋 Next steps:');
        Logger.info('1. Check your CurseForge project page for the uploaded file');
        Logger.info('2. The file will need approval before it\'s publicly available');
        Logger.info('3. Update any project descriptions or screenshots as needed');
    }
}

// Execute CLI if run directly
if (require.main === module) {
    CLI.run().catch((error) => {
        Logger.error('Unexpected error:', error.message);
        process.exit(1);
    });
}

module.exports = { BuildPipeline, CurseForgeDeployer, TOCParser, CLI };
#!/usr/bin/env node

/**
 * GrouperPlus CurseForge Deployment Script
 * Uploads the addon to CurseForge using their Upload API
 */

const fs = require('fs').promises;
const path = require('path');
const FormData = require('form-data');
const https = require('https');

// Configuration
const CONFIG = {
    // These should be set as environment variables
    API_TOKEN: process.env.CURSEFORGE_API_TOKEN,
    PROJECT_ID: process.env.CURSEFORGE_PROJECT_ID,
    
    // Build configuration
    BUILD_DIR: 'build',
    PACKAGE_NAME: 'GrouperPlus.zip',
    
    // API endpoints
    BASE_URL: 'https://wow.curseforge.com',
    UPLOAD_ENDPOINT: '/api/projects/{projectId}/upload-file',
    GAME_VERSIONS_ENDPOINT: '/api/game/versions',
    
    // Game version mapping for WoW
    WOW_GAME_ID: 1, // World of Warcraft
    
    // Default metadata
    RELEASE_TYPE: 'release', // 'alpha', 'beta', 'release'
    CHANGELOG_TYPE: 'markdown'
};

class CurseForgeDeployer {
    constructor() {
        this.validateConfig();
    }

    validateConfig() {
        if (!CONFIG.API_TOKEN) {
            throw new Error('CURSEFORGE_API_TOKEN environment variable is required');
        }
        if (!CONFIG.PROJECT_ID) {
            throw new Error('CURSEFORGE_PROJECT_ID environment variable is required');
        }
    }

    async readTocFile() {
        try {
            const tocPath = path.join(__dirname, 'GrouperPlus.toc');
            const tocContent = await fs.readFile(tocPath, 'utf8');
            
            const metadata = {};
            const lines = tocContent.split('\n');
            
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed.startsWith('## ')) {
                    const [key, ...valueParts] = trimmed.substring(3).split(':');
                    if (valueParts.length > 0) {
                        metadata[key.trim()] = valueParts.join(':').trim();
                    }
                }
            }
            
            return metadata;
        } catch (error) {
            console.error('Error reading TOC file:', error.message);
            throw error;
        }
    }

    async getGameVersions() {
        // For WoW addons, we need to map the Interface version to CurseForge game versions
        // This is a simplified mapping - you may need to update this based on current WoW versions
        const interfaceVersionMap = {
            '110107': [13203], // The War Within (11.1.7)
            '110105': [12918], // The War Within (11.1.5)
            '110007': [12215], // The War Within (11.0.7)
            '110005': [11926], // The War Within (11.0.5)
            '110002': [11596], // The War Within (11.0.2)
            '110000': [11274], // The War Within (11.0.0)
        };

        const tocMetadata = await this.readTocFile();
        const interfaceVersion = tocMetadata.Interface;
        
        if (interfaceVersionMap[interfaceVersion]) {
            return interfaceVersionMap[interfaceVersion];
        }
        
        console.warn(`Unknown interface version: ${interfaceVersion}, using latest`);
        return [13203]; // Default to latest (11.1.7)
    }

    async generateChangelog() {
        try {
            // Try to read from CHANGELOG.md if it exists
            const changelogPath = path.join(__dirname, 'CHANGELOG.md');
            try {
                const changelog = await fs.readFile(changelogPath, 'utf8');
                // Extract the latest version's changes
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
            } catch (error) {
                // Fallback to generic changelog
                const tocMetadata = await this.readTocFile();
                return `Release version ${tocMetadata.Version}\n\nSee README.md for detailed feature information.`;
            }
        } catch (error) {
            return 'New release with improvements and bug fixes.';
        }
    }

    async uploadToCourseFrge() {
        const tocMetadata = await this.readTocFile();
        const gameVersions = await this.getGameVersions();
        const changelog = await this.generateChangelog();
        
        // Use versioned package name
        const packageName = `GrouperPlus-v${tocMetadata.Version}.zip`;
        const packagePath = path.join(__dirname, CONFIG.BUILD_DIR, packageName);
        
        // Check if package exists
        try {
            await fs.access(packagePath);
        } catch (error) {
            throw new Error(`Package not found at ${packagePath}. Run build script first.`);
        }

        const metadata = {
            changelog: changelog,
            changelogType: CONFIG.CHANGELOG_TYPE,
            displayName: `${tocMetadata.Title} v${tocMetadata.Version}`,
            gameVersions: gameVersions,
            releaseType: CONFIG.RELEASE_TYPE
        };

        console.log('Upload metadata:', JSON.stringify(metadata, null, 2));

        const form = new FormData();
        form.append('metadata', JSON.stringify(metadata));
        form.append('file', await fs.readFile(packagePath), {
            filename: CONFIG.PACKAGE_NAME,
            contentType: 'application/zip'
        });

        return this.makeApiRequest('POST', CONFIG.UPLOAD_ENDPOINT.replace('{projectId}', CONFIG.PROJECT_ID), form);
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

    async deploy() {
        try {
            console.log('Starting CurseForge deployment...');
            
            const result = await this.uploadToCourseFrge();
            
            console.log('✅ Upload successful!');
            console.log('File ID:', result.id);
            console.log('Download URL will be available after approval');
            
            return result;
        } catch (error) {
            console.error('❌ Deployment failed:', error.message);
            throw error;
        }
    }
}

// CLI execution
if (require.main === module) {
    const deployer = new CurseForgeDeployer();
    
    deployer.deploy()
        .then((result) => {
            console.log('Deployment completed successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('Deployment failed:', error.message);
            process.exit(1);
        });
}

module.exports = CurseForgeDeployer;
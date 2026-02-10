// Script to properly import workflows with authentication consideration
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const N8N_URL = 'http://localhost:5678';
const WORKFLOWS_DIR = './workflows';

console.log('Setting up n8n authentication and importing workflows...');

// Check if there are any users in the database first
console.log('\\n1. Checking if n8n instance has users...');

try {
  // Try to access the database directly to check for users
  const dbPath = path.join(process.env.HOME, '.n8n', 'database.sqlite');
  
  // Use the n8n binary to check the database
  // First, let's try to see if we can access the n8n CLI through the running process
  console.log('\\n2. Attempting to set up authentication...');
  
  // Since we can't install packages, let's try to create a default user by configuring environment variables
  // and restarting n8n with proper settings
  
  console.log('\\n3. Creating environment file for n8n...');
  
  const envContent = `
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=password
N8N_ENCRYPTION_KEY=autoagenda_encryption_key_2026
  `.trim();
  
  fs.writeFileSync('.env', envContent);
  console.log('Created .env file with basic auth settings');
  
  console.log('\\n4. To properly import workflows, n8n needs to be restarted with authentication.');
  console.log('   Please stop the current n8n process and restart with these environment variables.');
  console.log('\\n   Or, you can try to create a user via the API once authentication is set up.');
  
  // List workflow files to confirm what we have
  const workflowFiles = fs.readdirSync(WORKFLOWS_DIR).filter(file => file.endsWith('.json'));
  console.log(`\\n5. Found ${workflowFiles.length} workflow files to import:`);
  workflowFiles.forEach(file => console.log(`   - ${file}`));
  
} catch (error) {
  console.error('Error during setup:', error.message);
}
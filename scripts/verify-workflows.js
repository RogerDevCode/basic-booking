const fs = require('fs');
const path = require('path');

// Read all workflow files
const workflowsDir = path.join(__dirname, '../workflows');
const workflowFiles = fs.readdirSync(workflowsDir);

console.log(`Analyzing ${workflowFiles.length} workflow files...\n`);

// Define the correct versions based on SOT-N8N-2.4.6.md
const requiredVersions = {
  'n8n-nodes-base.webhook': { maxVersion: 1, description: 'Webhook v1 only (v2+ introduces unsupported responseMode)' },
  'n8n-nodes-base.postgresdb': { maxVersion: 2.4, description: 'Postgres v2.4 (v2.5 has regression with falsey values)' },
  'n8n-nodes-base.switch': { maxVersion: 3, description: 'Switch v3 only (v3.4 has incompatible options)' },
  'n8n-nodes-base.code': { maxVersion: 2, description: 'Code v2 only (v3.4 blocks env vars)' },
  'n8n-nodes-base.executeWorkflow': { maxVersion: 1, description: 'Execute Workflow v1 only' },
  'n8n-nodes-base.respondToWebhook': { maxVersion: 1, description: 'Respond to Webhook v1 only (v2 has compatibility issues)' }
};

// Track compatibility issues
const compatibilityIssues = [];
const nodeVersionStats = {};

for (const file of workflowFiles) {
  if (file.endsWith('.json')) {
    console.log(`\n--- Analyzing ${file} ---`);
    
    try {
      const filePath = path.join(workflowsDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      
      // Handle potential control characters in JSON
      const cleanContent = content.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
      const workflow = JSON.parse(cleanContent);
      
      // Check workflow properties
      console.log(`Name: ${workflow.name || 'Unknown'}`);
      console.log(`Active: ${workflow.active ? 'Yes' : 'No'}`);
      
      // Check nodes
      if (workflow.nodes) {
        console.log(`Nodes count: ${workflow.nodes.length}`);
        
        for (const node of workflow.nodes) {
          const nodeType = node.type;
          const nodeVersion = node.typeVersion;
          
          // Track stats for all node types
          if (!nodeVersionStats[nodeType]) {
            nodeVersionStats[nodeType] = {};
          }
          if (!nodeVersionStats[nodeType][nodeVersion]) {
            nodeVersionStats[nodeType][nodeVersion] = 0;
          }
          nodeVersionStats[nodeType][nodeVersion]++;
          
          // Check if this node has specific version requirements
          if (requiredVersions[nodeType]) {
            const req = requiredVersions[nodeType];
            
            if (typeof nodeVersion === 'number') {
              if (nodeVersion > req.maxVersion) {
                compatibilityIssues.push({
                  file: file,
                  node: node.name,
                  type: nodeType,
                  version: nodeVersion,
                  requiredMax: req.maxVersion,
                  description: req.description
                });
                
                console.log(`  ❌ ${node.name} (${nodeType}): v${nodeVersion} exceeds max v${req.maxVersion} - ${req.description}`);
              } else {
                console.log(`  ✅ ${node.name} (${nodeType}): v${nodeVersion} OK`);
              }
            } else {
              // Missing version - could be an issue
              compatibilityIssues.push({
                file: file,
                node: node.name,
                type: nodeType,
                version: 'missing',
                requiredMax: req.maxVersion,
                description: `${req.description} - Version not specified`
              });
              
              console.log(`  ⚠️  ${node.name} (${nodeType}): Version not specified - should be ≤ v${req.maxVersion}`);
            }
          } else {
            // For nodes not in our specific requirements, just log them
            console.log(`  ℹ️  ${node.name} (${nodeType}): v${nodeVersion || 'unknown'}`);
          }
        }
      }
      
      // Check connections
      if (workflow.connections) {
        console.log(`Connections: ${Object.keys(workflow.connections).length}`);
      }
      
    } catch (error) {
      console.error(`❌ Error parsing ${file}:`, error.message);
      compatibilityIssues.push({
        file: file,
        error: error.message,
        description: 'Could not parse workflow file'
      });
    }
  }
}

// Print summary statistics
console.log('\n\n=== NODE VERSION SUMMARY ===');
for (const [nodeType, versions] of Object.entries(nodeVersionStats)) {
  console.log(`${nodeType}:`);
  for (const [version, count] of Object.entries(versions)) {
    console.log(`  v${version}: ${count} occurrences`);
  }
}

// Print compatibility issues
console.log('\n\n=== COMPATIBILITY ISSUES ===');
if (compatibilityIssues.length === 0) {
  console.log('✅ No compatibility issues found!');
} else {
  console.log(`⚠️  Found ${compatibilityIssues.length} compatibility issue(s):\n`);
  
  compatibilityIssues.forEach((issue, index) => {
    console.log(`${index + 1}. File: ${issue.file}`);
    console.log(`   Node: ${issue.node}`);
    console.log(`   Type: ${issue.type}`);
    console.log(`   Current Version: ${issue.version}`);
    console.log(`   Required Max Version: ${issue.requiredMax}`);
    console.log(`   Description: ${issue.description}`);
    console.log('');
  });
}

// Check for version compatibility with n8n 2.6.3
console.log('\n=== n8n v2.6.3 COMPATIBILITY ASSESSMENT ===');
const majorIssues = compatibilityIssues.filter(issue => 
  typeof issue.version === 'number' && issue.version > issue.requiredMax
);

if (majorIssues.length === 0 && compatibilityIssues.length <= 3) { // Allow minor issues
  console.log('✅ Workflows appear to be compatible with n8n v2.6.3');
} else {
  console.log('⚠️  Potential compatibility issues with n8n v2.6.3 detected');
  console.log(`   - ${majorIssues.length} major version violations`);
  console.log(`   - ${compatibilityIssues.length} total issues`);
  console.log('   Consider adjusting node versions according to SOT-N8N-2.4.6.md');
}

module.exports = { compatibilityIssues, nodeVersionStats };
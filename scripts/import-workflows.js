const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const N8N_URL = 'https://n8n.stax.ink';
const WORKFLOWS_DIR = './workflows';

console.log('Starting workflow import process...');
console.log(`n8n server: ${N8N_URL}`);
console.log(`Workflows directory: ${WORKFLOWS_DIR}`);
console.log('');

// Get all JSON workflow files
const workflowFiles = fs.readdirSync(WORKFLOWS_DIR).filter(file => file.endsWith('.json'));

console.log(`Found ${workflowFiles.length} workflow files:`);
workflowFiles.forEach(file => console.log(`  - ${file}`));
console.log('');

// Function to import a single workflow
async function importWorkflow(filePath) {
  try {
    // Read the workflow file
    const workflowData = fs.readFileSync(filePath, 'utf8');
    const workflow = JSON.parse(workflowData);
    
    console.log(`Importing workflow: ${workflow.name || path.basename(filePath)}`);
    
    // Write workflow data to a temporary file
    const tempFilePath = `/tmp/temp_workflow_${Date.now()}.json`;
    fs.writeFileSync(tempFilePath, workflowData);
    
    // Use n8n CLI to import the workflow
    // Note: This assumes n8n is installed globally and accessible
    const importCmd = `curl -X POST ${N8N_URL}/rest/workflows -H "Content-Type: application/json" -d @${tempFilePath}`;
    
    // Execute the import command
    const result = execSync(importCmd, { encoding: 'utf-8' });
    
    // Clean up temp file
    fs.unlinkSync(tempFilePath);
    
    console.log(`  ✅ Successfully imported: ${workflow.name || path.basename(filePath)}`);
    return true;
  } catch (error) {
    console.error(`  ❌ Error importing ${filePath}:`, error.message);
    return false;
  }
}

// Alternative function using n8n CLI if available
async function importWithCLI(filePath) {
  try {
    const workflowData = fs.readFileSync(filePath, 'utf8');
    const workflow = JSON.parse(workflowData);
    
    console.log(`Importing workflow via CLI: ${workflow.name || path.basename(filePath)}`);
    
    // Write workflow data to a temporary file
    const tempFilePath = `/tmp/temp_workflow_cli_${Date.now()}.json`;
    fs.writeFileSync(tempFilePath, workflowData);
    
    // Use n8n CLI to import the workflow
    const importCmd = `n8n import:workflow --input="${tempFilePath}"`;
    
    try {
      const result = execSync(importCmd, { encoding: 'utf-8' });
      console.log(`  ✅ Successfully imported via CLI: ${workflow.name || path.basename(filePath)}`);
      
      // Clean up temp file
      fs.unlinkSync(tempFilePath);
      return true;
    } catch (cliError) {
      console.log(`  ℹ️  CLI import failed, trying REST API: ${cliError.message}`);
      
      // Clean up temp file
      fs.unlinkSync(tempFilePath);
      return false;
    }
  } catch (error) {
    console.error(`  ❌ Error preparing CLI import for ${filePath}:`, error.message);
    return false;
  }
}

// Main function to import all workflows
async function importAllWorkflows() {
  console.log('Starting import process...\n');
  
  let successCount = 0;
  let totalCount = workflowFiles.length;
  
  for (const file of workflowFiles) {
    const filePath = path.join(WORKFLOWS_DIR, file);
    
    // Try CLI import first, then fall back to REST API
    let imported = await importWithCLI(filePath);
    if (!imported) {
      // If CLI import failed, try the REST API approach
      imported = await importWorkflow(filePath);
    }
    
    if (imported) {
      successCount++;
    }
    console.log(''); // Add spacing between imports
  }
  
  console.log(`\nImport process completed!`);
  console.log(`Successfully imported: ${successCount}/${totalCount} workflows`);
  
  if (successCount < totalCount) {
    console.log(`\n⚠️  Some workflows failed to import. Check the errors above.`);
    console.log(`💡 You can try importing them manually through the n8n UI.`);
  } else {
    console.log(`🎉 All workflows imported successfully!`);
  }
}

// Run the import process
importAllWorkflows().catch(error => {
  console.error('Fatal error during import process:', error);
  process.exit(1);
});
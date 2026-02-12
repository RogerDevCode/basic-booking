const { execSync } = require('child_process');

// Configuration
const N8N_URL = 'https://n8n.stax.ink';

console.log('Fetching workflow count from n8n server...');
console.log(`n8n server: ${N8N_URL}`);
console.log('');

try {
  // Use curl to get the list of workflows from the n8n API
  const cmd = `curl -s ${N8N_URL}/rest/workflows`;
  const result = execSync(cmd, { encoding: 'utf-8' });
  
  // Parse the response
  const response = JSON.parse(result);
  
  if (response.data && Array.isArray(response.data)) {
    const workflowCount = response.data.length;
    console.log(`Total workflows in n8n server: ${workflowCount}`);
    
    console.log('\nWorkflow names:');
    response.data.forEach((workflow, index) => {
      console.log(`  ${index + 1}. ${workflow.name} (ID: ${workflow.id})`);
    });
  } else {
    console.log('Unexpected response format:', response);
  }
} catch (error) {
  console.error('Error fetching workflows:', error.message);
  
  // If the REST API doesn't work, try using n8n CLI if available
  try {
    console.log('\nTrying with n8n CLI...');
    const cliResult = execSync('n8n workflows:list', { encoding: 'utf-8' });
    console.log(cliResult);
  } catch (cliError) {
    console.error('Also failed with CLI:', cliError.message);
    console.log('\nMake sure the n8n server is running and accessible.');
  }
}
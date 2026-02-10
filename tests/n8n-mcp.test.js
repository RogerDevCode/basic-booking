const fs = require('fs');
const path = require('path');

describe('n8n-mcp Specific Tests', () => {
  test('should have n8n workflows with expected structure', async () => {
    const workflowsDir = path.join(__dirname, '../workflows');
    const workflowFiles = fs.readdirSync(workflowsDir);
    
    // Test a few key workflows to ensure they have the expected structure
    const keyWorkflows = [
      'BB_01_Telegram_Gateway.json',
      'BB_03_Availability_Engine.json',
      'BB_04_Booking_Transaction.json'
    ];
    
    for (const workflowFile of keyWorkflows) {
      if (workflowFiles.includes(workflowFile)) {
        const filePath = path.join(workflowsDir, workflowFile);
        const content = fs.readFileSync(filePath, 'utf8');
        const cleanContent = content.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
        const workflow = JSON.parse(cleanContent);
        
        // Basic assertions for n8n workflow structure
        expect(workflow).toHaveProperty('name');
        expect(typeof workflow.name).toBe('string');
        expect(workflow).toHaveProperty('nodes');
        expect(Array.isArray(workflow.nodes)).toBe(true);
        expect(workflow.nodes.length).toBeGreaterThan(0);
        
        // Check that nodes have required properties
        workflow.nodes.forEach(node => {
          expect(node).toHaveProperty('name');
          expect(node).toHaveProperty('type');
          expect(typeof node.name).toBe('string');
          expect(typeof node.type).toBe('string');
        });
      }
    }
  });
  
  test('should have all required booking system workflows', () => {
    const workflowsDir = path.join(__dirname, '../workflows');
    const workflowFiles = fs.readdirSync(workflowsDir);
    
    const requiredWorkflows = [
      'BB_00_Global_Error_Handler.json',
      'BB_01_Telegram_Gateway.json',
      'BB_02_Security_Firewall.json',
      'BB_03_Availability_Engine.json',
      'BB_04_Booking_Transaction.json',
      'BB_05_Notification_Engine.json',
      'BB_06_Admin_Dashboard.json',
      'BB_07_Notification_Retry_Worker.json',
      'BB_08_JWT_Auth_Helper.json',
      'BB_09_Deep_Link_Redirect.json'
    ];
    
    const missingWorkflows = requiredWorkflows.filter(
      workflow => !workflowFiles.includes(workflow)
    );
    
    if (missingWorkflows.length > 0) {
      console.warn('Missing required workflows:', missingWorkflows);
    }
    
    // All required workflows should be present
    requiredWorkflows.forEach(workflow => {
      expect(workflowFiles).toContain(workflow);
    });
  });
  
  test('should validate n8n workflow credentials references', () => {
    const workflowsDir = path.join(__dirname, '../workflows');
    const workflowFiles = fs.readdirSync(workflowsDir);
    
    // Check if workflows reference credentials properly
    for (const file of workflowFiles) {
      if (file.endsWith('.json')) {
        const filePath = path.join(workflowsDir, file);
        const content = fs.readFileSync(filePath, 'utf8');
        const cleanContent = content.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
        const workflow = JSON.parse(cleanContent);
        
        // Check nodes for credential references
        if (workflow.nodes) {
          workflow.nodes.forEach(node => {
            if (node.credentials) {
              // Ensure credential references have proper structure
              expect(typeof node.credentials).toBe('object');
            }
          });
        }
      }
    }
  });
});

describe('n8n-mcp Environment Tests', () => {
  test('should have credentials directory', () => {
    const credsDir = path.join(__dirname, '../credentials');
    expect(fs.existsSync(credsDir)).toBe(true);
  });
  
  test('should have database directory', () => {
    const dbDir = path.join(__dirname, '../database');
    expect(fs.existsSync(dbDir)).toBe(true);
  });
  
  test('should have configuration files', () => {
    const configFiles = [
      'temp_n8n_db.sqlite',
      '.pgpass'
    ];
    
    configFiles.forEach(file => {
      const filePath = path.join(__dirname, `../${file}`);
      expect(fs.existsSync(filePath)).toBe(true);
    });
  });
});
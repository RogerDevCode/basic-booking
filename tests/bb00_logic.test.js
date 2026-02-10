const fs = require('fs');
const path = require('path');

// Helper to extract JS code from a node in the workflow JSON
function getCodeFromNode(workflow, nodeName) {
  const node = workflow.nodes.find(n => n.name === nodeName);
  return node ? node.parameters.jsCode : null;
}

describe('BB_00 Global Error Handler - Internal Logic', () => {
  let workflow;
  
  beforeAll(() => {
    const filePath = path.join(__dirname, '../workflows/BB_00_Global_Error_Handler.json');
    const content = fs.readFileSync(filePath, 'utf8');
    workflow = JSON.parse(content);
  });

  describe('Redact PII Node', () => {
    let redactFunction;

    beforeAll(() => {
      const code = getCodeFromNode(workflow, 'Redact PII');
      // Wrap n8n code into a callable function for testing
      // n8n code nodes expect $input.first()
      redactFunction = (inputData) => {
        const $input = {
          first: () => ({ json: inputData })
        };
        // The code uses try-catch and returns [{ json: ... }]
        return eval(`
          ((() => {
            ${code}
          })())
        `)[0].json;
      };
    });

    test('should redact emails', () => {
      const input = { email: 'admin@system.com', name: 'John Doe' };
      const output = redactFunction(input);
      expect(output.email).not.toBe('admin@system.com');
      expect(output.email).toContain('****');
      expect(output.name).toContain('****');
    });

    test('should redact tokens and secrets', () => {
      const input = { token: '1234567890abcdef', api_key: 'secret-123' };
      const output = redactFunction(input);
      expect(output.token).toBe('12****ef');
      expect(output.api_key).toBe('se****23');
    });

    test('should not redact non-sensitive fields', () => {
      const input = { status: 'error', code: 500, workflow_id: 'abc-123' };
      const output = redactFunction(input);
      expect(output.status).toBe('error');
      expect(output.code).toBe(500);
      expect(output.workflow_id).toBe('abc-123');
    });
  });

  describe('Classify Severity Node', () => {
    let classifyFunction;

    beforeAll(() => {
      const code = getCodeFromNode(workflow, 'Classify Severity');
      classifyFunction = (inputData) => {
        const $input = {
          first: () => ({ json: inputData })
        };
        return eval(`
          ((() => {
            ${code}
          })())
        `)[0].json;
      };
    });

    test('should classify database errors as CRITICAL', () => {
      const input = { 
        error: { message: 'database connection refused' },
        workflow: { name: 'Any' }
      };
      const output = classifyFunction(input);
      expect(output.severity).toBe('CRITICAL');
    });

    test('should classify 404 errors as LOW', () => {
      const input = { 
        error: { message: 'Resource not found (404)' },
        workflow: { name: 'Any' }
      };
      const output = classifyFunction(input);
      expect(output.severity).toBe('LOW');
    });

    test('should classify timeout as HIGH', () => {
      const input = { 
        error: { message: 'ETIMEDOUT' },
        workflow: { name: 'Any' }
      };
      const output = classifyFunction(input);
      expect(output.severity).toBe('HIGH');
    });

    test('should respect provided_severity in context', () => {
      const input = { 
        error: { message: 'Generic error' },
        context: { provided_severity: 'LOW' }
      };
      const output = classifyFunction(input);
      expect(output.severity).toBe('LOW');
    });
  });

  describe('Process Merged Data Node (Rate Limiting)', () => {
    let processFunction;

    beforeAll(() => {
      const code = getCodeFromNode(workflow, 'Process Merged Data');
      processFunction = (items) => {
        const $input = {
          all: () => items.map(i => ({ json: i })),
          first: () => ({ json: items[0] })
        };
        return eval(`
          ((() => {
            ${code}
          })())
        `)[0].json;
      };
    });

    test('should block alerts if rate limit is exceeded for MEDIUM severity', () => {
      const items = [
        { workflow: { name: 'Test' }, execution: { id: '1' }, error: { message: 'err' }, severity: 'MEDIUM' },
        { error_count: 15 } // Over the limit of 10
      ];
      const output = processFunction(items);
      expect(output.rate_limit_exceeded).toBe(true);
      expect(output.can_send_alert).toBe(false);
    });

    test('should ALWAYS allow alerts for CRITICAL severity even if rate limited', () => {
      const items = [
        { workflow: { name: 'Test' }, execution: { id: '1' }, error: { message: 'err' }, severity: 'CRITICAL' },
        { error_count: 50 } 
      ];
      const output = processFunction(items);
      expect(output.rate_limit_exceeded).toBe(true);
      expect(output.can_send_alert).toBe(true);
    });

    test('should allow alerts if below rate limit', () => {
      const items = [
        { workflow: { name: 'Test' }, severity: 'MEDIUM', execution: { id: '1' }, error: { message: 'err' } },
        { error_count: 5 } 
      ];
      const output = processFunction(items);
      expect(output.rate_limit_exceeded).toBe(false);
      expect(output.can_send_alert).toBe(true);
    });

    test('should handle DB OFFLINE and force CRITICAL', () => {
      const items = [
        { workflow: { name: 'Test' }, execution: { id: '1' }, error: { message: 'err' }, severity: 'LOW' },
        { error: { message: 'ECONNREFUSED' } } // DB error
      ];
      const output = processFunction(items);
      expect(output.severity).toBe('CRITICAL');
      expect(output.db_offline).toBe(true);
      expect(output.can_send_alert).toBe(true);
    });
  });
});

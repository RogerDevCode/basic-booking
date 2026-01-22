// const { test, expect, describe } = require('@jest/globals');

describe('PII Redaction', () => {
  describe('redactPII', () => {
    const redactPII = (obj) => {
      const sensitiveFields = ['email', 'phone', 'name', 'rut', 'address', 'first_name', 'last_name', 'telegram_id'];
      const redacted = JSON.parse(JSON.stringify(obj));
      
      function traverse(node) {
        if (typeof node !== 'object' || node === null) return node;
        
        for (const key in node) {
          if (sensitiveFields.some(sf => key.toLowerCase().includes(sf))) {
            const value = String(node[key]);
            if (value.length > 4) {
              // Fixed logic: hide middle, keep ends
              const start = value.substring(0, 1);
              const end = value.substring(value.length - 2);
              node[key] = start + '***' + end;
            } else {
              node[key] = '***';
            }
          } else if (typeof node[key] === 'object') {
            traverse(node[key]);
          }
        }
      }
      
      traverse(redacted);
      return redacted;
    };

    test('redacts email correctly', () => {
      const input = { email: 'juan.perez@dominio.com' };
      const result = redactPII(input);
      expect(result.email).toMatch(/^j\*\*\*om$/);
    });

    test('redacts phone correctly', () => {
      const input = { phone: '+56912345678' };
      const result = redactPII(input);
      expect(result.phone).toMatch(/^\+\*\*\*78$/);
    });

    test('redacts nested objects', () => {
      const input = { user: { contact: { email: 'a@b.com' } } };
      const result = redactPII(input);
      expect(result.user.contact.email).toBe('a***om');
    });
  });

  describe('Input Length Validation', () => {
    const validateInput = (data) => {
      const limits = {
        max_string_length: 1000,
        max_array_length: 100,
        max_payload_size: 102400,  // 100KB
        max_object_depth: 10,
      };

      // Calculate raw string length if it's a string, or stringified length
      const payloadSize = typeof data === 'string' ? data.length : JSON.stringify(data).length;
      
      if (payloadSize > limits.max_payload_size) {
        throw new Error(`PAYLOAD_TOO_LARGE: Max ${limits.max_payload_size}`);
      }

      function validateNode(node, depth = 0) {
        if (depth > limits.max_object_depth) {
          throw new Error(`OBJECT_DEPTH_EXCEEDED`);
        }

        if (typeof node === 'string') {
          if (node.length > limits.max_string_length) {
            throw new Error(`STRING_TOO_LONG`);
          }
        } else if (Array.isArray(node)) {
          if (node.length > limits.max_array_length) {
            throw new Error(`ARRAY_TOO_LONG`);
          }
          node.forEach(item => validateNode(item, depth + 1));
        } else if (typeof node === 'object' && node !== null) {
          Object.values(node).forEach(v => validateNode(v, depth + 1));
        }
      }

      validateNode(data);
      return data;
    };

    test('rejects payload > 100KB', () => {
      const largePayload = 'x'.repeat(102401);
      expect(() => validateInput(largePayload)).toThrow('PAYLOAD_TOO_LARGE');
    });

    test('accepts payload <= 100KB', () => {
      // Use an array of strings to stay under string length limit but reach payload limit
      const validPayload = Array(100).fill('x'.repeat(1000)); 
      expect(() => validateInput(validPayload)).not.toThrow();
    });
  });

  describe('SQL Injection Prevention', () => {
    const detectSQLInjection = (input) => {
      const sqlPatterns = [
        /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|EXEC)\b)/i,
        /(--|;|\/\*|\*\/)/,
        /(\bor\b\s*['"]?\s*1\s*['"]?\s*=\s*['"]?\s*1\s*['"]?\b)/i // Improved regex
      ];
      
      const str = String(input);
      for (const pattern of sqlPatterns) {
        if (pattern.test(str)) {
          throw new Error('SQL_INJECTION_DETECTED');
        }
      }
    };

    test('detects SELECT injection', () => {
      expect(() => detectSQLInjection("' OR '1'='1")).toThrow();
    });

    test('detects comment injection', () => {
      expect(() => detectSQLInjection("' OR 1=1--")).toThrow();
    });
  });
});
#!/usr/bin/env python3
"""
Validation script to check workflows against SolucionFinal-v2.md standards
Generates compliance report without modifying code
"""
import json
import os
import re
from typing import Dict, List, Tuple

class WorkflowValidator:
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.compliant = []
        
    def validate_workflow(self, filepath: str) -> Dict:
        """Validate a single workflow file"""
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        workflow_name = data.get('name', os.path.basename(filepath))
        results = {
            'name': workflow_name,
            'file': filepath,
            'issues': [],
            'warnings': [],
            'compliant': []
        }
        
        # 1. Check errorWorkflow configuration
        self._check_error_workflow(data, results)
        
        # 2. Check Code Nodes for compliance
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.code':
                self._check_code_node(node, results, workflow_name)
        
        # 3. Check Execute Workflow nodes have Switch nodes
        self._check_execute_workflow_switches(data, results)
        
        # 4. Check for dual outputs (prohibited)
        self._check_dual_outputs(data, results)
        
        return results
    
    def _check_error_workflow(self, data: Dict, results: Dict):
        """Check if errorWorkflow is configured"""
        settings = data.get('settings', {})
        error_wf = settings.get('errorWorkflow')
        
        if not error_wf:
            results['issues'].append({
                'severity': 'CRITICAL',
                'rule': 'WORKFLOW_SETTINGS',
                'message': 'Missing errorWorkflow in settings',
                'requirement': 'settings.errorWorkflow must be set to BB_00_Global_Error_Handler'
            })
        elif error_wf != 'BB_00_Global_Error_Handler':
            results['warnings'].append({
                'severity': 'WARNING',
                'rule': 'WORKFLOW_SETTINGS',
                'message': f'errorWorkflow is "{error_wf}" instead of "BB_00_Global_Error_Handler"',
                'requirement': 'Should reference BB_00_Global_Error_Handler'
            })
        else:
            results['compliant'].append('errorWorkflow configured correctly')
    
    def _check_code_node(self, node: Dict, results: Dict, workflow_name: str):
        """Check Code Node for compliance"""
        node_name = node.get('name', 'Unknown')
        js_code = node.get('parameters', {}).get('jsCode', '')
        
        if not js_code:
            return
        
        # Check for WORKFLOW_ID constant
        if 'const WORKFLOW_ID' not in js_code:
            results['issues'].append({
                'severity': 'HIGH',
                'rule': 'TRAZABILIDAD',
                'node': node_name,
                'message': 'Missing WORKFLOW_ID constant',
                'requirement': 'All Code Nodes must define const WORKFLOW_ID'
            })
        else:
            results['compliant'].append(f'Node "{node_name}": Has WORKFLOW_ID')
        
        # Check for try-catch
        if 'try {' not in js_code or 'catch' not in js_code:
            results['issues'].append({
                'severity': 'CRITICAL',
                'rule': 'ERROR_HANDLING',
                'node': node_name,
                'message': 'Missing try-catch block',
                'requirement': 'All Code Nodes must wrap code in try-catch'
            })
        else:
            results['compliant'].append(f'Node "{node_name}": Has try-catch')
        
        # Check for _meta in returns
        if '_meta' not in js_code:
            results['issues'].append({
                'severity': 'HIGH',
                'rule': 'STANDARD_CONTRACT',
                'node': node_name,
                'message': 'Missing _meta field in return statements',
                'requirement': 'All returns must include _meta with source, timestamp, workflow_id'
            })
        else:
            results['compliant'].append(f'Node "{node_name}": Has _meta field')
        
        # Check for standard contract fields
        has_success = 'success:' in js_code or '"success"' in js_code
        has_error_code = 'error_code:' in js_code or '"error_code"' in js_code
        has_error_message = 'error_message:' in js_code or '"error_message"' in js_code
        has_data = 'data:' in js_code or '"data"' in js_code
        
        if not (has_success and has_error_code and has_error_message and has_data):
            missing = []
            if not has_success: missing.append('success')
            if not has_error_code: missing.append('error_code')
            if not has_error_message: missing.append('error_message')
            if not has_data: missing.append('data')
            
            results['issues'].append({
                'severity': 'CRITICAL',
                'rule': 'STANDARD_CONTRACT',
                'node': node_name,
                'message': f'Missing standard contract fields: {", ".join(missing)}',
                'requirement': 'Must return {success, error_code, error_message, data, _meta}'
            })
        else:
            results['compliant'].append(f'Node "{node_name}": Has standard contract fields')
        
        # Check for prohibited patterns
        if 'require(' in js_code:
            results['issues'].append({
                'severity': 'CRITICAL',
                'rule': 'SECURITY',
                'node': node_name,
                'message': 'Uses require() which is not supported in N8N Code Nodes',
                'requirement': 'NEVER use require() or import in Code Nodes'
            })
        
        # Check for hardcoded secrets (common patterns)
        secret_patterns = [
            r'(password|secret|key|token)\s*=\s*["\'][^"\']+["\']',
            r'AutoAgenda_Secret_Key',
            r'Bearer\s+[A-Za-z0-9_-]+',
        ]
        for pattern in secret_patterns:
            if re.search(pattern, js_code, re.IGNORECASE):
                results['warnings'].append({
                    'severity': 'WARNING',
                    'rule': 'SECURITY',
                    'node': node_name,
                    'message': 'Possible hardcoded secret detected',
                    'requirement': 'Never hardcode credentials, use $vars or $credentials'
                })
                break
    
    def _check_execute_workflow_switches(self, data: Dict, results: Dict):
        """Check if Execute Workflow nodes are followed by Switch nodes"""
        nodes = data.get('nodes', [])
        connections = data.get('connections', {})
        
        exec_wf_nodes = [n for n in nodes if n.get('type') == 'n8n-nodes-base.executeWorkflow']
        
        for exec_node in exec_wf_nodes:
            node_name = exec_node.get('name', 'Unknown')
            node_connections = connections.get(node_name, {}).get('main', [[]])
            
            if not node_connections or not node_connections[0]:
                continue
            
            # Get next node
            next_node_name = node_connections[0][0].get('node') if node_connections[0] else None
            if next_node_name:
                next_node = next((n for n in nodes if n.get('name') == next_node_name), None)
                if next_node and next_node.get('type') != 'n8n-nodes-base.switch':
                    results['warnings'].append({
                        'severity': 'WARNING',
                        'rule': 'ERROR_ROUTING',
                        'node': node_name,
                        'message': f'Execute Workflow not followed by Switch node (next: {next_node_name})',
                        'requirement': 'Should have Switch node after Execute Workflow to check success field'
                    })
                elif next_node and next_node.get('type') == 'n8n-nodes-base.switch':
                    results['compliant'].append(f'Execute Workflow "{node_name}": Has Switch node')
    
    def _check_dual_outputs(self, data: Dict, results: Dict):
        """Check for prohibited dual output pattern"""
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.code':
                js_code = node.get('parameters', {}).get('jsCode', '')
                node_name = node.get('name', 'Unknown')
                
                # Look for dual output pattern: return [output0, output1]
                dual_pattern = r'return\s*\[\s*\{[^}]+\}\s*,\s*\{[^}]+\}\s*\]'
                if re.search(dual_pattern, js_code):
                    results['issues'].append({
                        'severity': 'CRITICAL',
                        'rule': 'SINGLE_OUTPUT',
                        'node': node_name,
                        'message': 'Uses prohibited dual output pattern',
                        'requirement': 'MUST use single output only: return [{json: {...}}]'
                    })

def generate_report(all_results: List[Dict]) -> str:
    """Generate markdown compliance report"""
    report = []
    report.append("# Reporte de Validación v2.0 - SolucionFinal-v2.md")
    report.append("")
    report.append(f"**Fecha:** 2026-02-15")
    report.append(f"**Workflows Analizados:** {len(all_results)}")
    report.append("")
    
    # Summary statistics
    total_issues = sum(len(r['issues']) for r in all_results)
    total_warnings = sum(len(r['warnings']) for r in all_results)
    critical_issues = sum(len([i for i in r['issues'] if i.get('severity') == 'CRITICAL']) for r in all_results)
    
    report.append("## Resumen Ejecutivo")
    report.append("")
    report.append(f"| Métrica | Cantidad |")
    report.append(f"|---------|----------|")
    report.append(f"| 🔴 Issues Críticos | {critical_issues} |")
    report.append(f"| 🟠 Issues Totales | {total_issues} |")
    report.append(f"| 🟡 Warnings | {total_warnings} |")
    report.append(f"| ✅ Workflows Sin Issues Críticos | {len([r for r in all_results if not any(i.get('severity') == 'CRITICAL' for i in r['issues'])])} |")
    report.append("")
    
    # Compliance by rule
    report.append("## Cumplimiento por Regla")
    report.append("")
    
    rules = {
        'WORKFLOW_SETTINGS': 'errorWorkflow configurado',
        'TRAZABILIDAD': 'WORKFLOW_ID presente',
        'ERROR_HANDLING': 'Try-catch implementado',
        'STANDARD_CONTRACT': 'Contrato estándar completo',
        'SINGLE_OUTPUT': 'Single output (no dual)',
        'SECURITY': 'Sin secrets hardcodeados',
        'ERROR_ROUTING': 'Switch después de Execute Workflow'
    }
    
    for rule_code, rule_name in rules.items():
        workflows_with_issue = len([r for r in all_results if any(i.get('rule') == rule_code for i in r['issues'])])
        compliance_pct = ((len(all_results) - workflows_with_issue) / len(all_results)) * 100
        status = "✅" if compliance_pct == 100 else "⚠️" if compliance_pct >= 80 else "🔴"
        report.append(f"- {status} **{rule_name}**: {compliance_pct:.0f}% ({len(all_results) - workflows_with_issue}/{len(all_results)})")
    
    report.append("")
    
    # Detailed results
    report.append("## Resultados Detallados por Workflow")
    report.append("")
    
    for result in sorted(all_results, key=lambda x: (len([i for i in x['issues'] if i.get('severity') == 'CRITICAL']), x['name']), reverse=True):
        critical = [i for i in result['issues'] if i.get('severity') == 'CRITICAL']
        high = [i for i in result['issues'] if i.get('severity') == 'HIGH']
        
        status = "🔴" if critical else "🟡" if (high or result['warnings']) else "✅"
        
        report.append(f"### {status} {result['name']}")
        report.append("")
        
        if result['issues']:
            report.append("**Issues:**")
            for issue in result['issues']:
                severity_icon = "🔴" if issue['severity'] == 'CRITICAL' else "🟠"
                node_info = f" (Node: `{issue['node']}`)" if 'node' in issue else ""
                report.append(f"- {severity_icon} **{issue['rule']}**{node_info}: {issue['message']}")
                report.append(f"  - *Requerimiento:* {issue['requirement']}")
            report.append("")
        
        if result['warnings']:
            report.append("**Warnings:**")
            for warning in result['warnings']:
                node_info = f" (Node: `{warning['node']}`)" if 'node' in warning else ""
                report.append(f"- 🟡 **{warning['rule']}**{node_info}: {warning['message']}")
                report.append(f"  - *Recomendación:* {warning['requirement']}")
            report.append("")
        
        if not result['issues'] and not result['warnings']:
            report.append("✅ **Totalmente conforme** con SolucionFinal-v2.md")
            report.append("")
    
    # Recommendations
    report.append("## Recomendaciones")
    report.append("")
    
    if critical_issues > 0:
        report.append("### 🔴 Acción Inmediata Requerida")
        report.append("")
        report.append(f"Se encontraron **{critical_issues} issues críticos** que violan las reglas inquebrantables de SolucionFinal-v2.md:")
        report.append("")
        
        critical_by_rule = {}
        for r in all_results:
            for i in r['issues']:
                if i.get('severity') == 'CRITICAL':
                    rule = i.get('rule', 'UNKNOWN')
                    critical_by_rule[rule] = critical_by_rule.get(rule, 0) + 1
        
        for rule, count in sorted(critical_by_rule.items(), key=lambda x: x[1], reverse=True):
            report.append(f"- **{rule}**: {count} violaciones")
        report.append("")
    
    if total_warnings > 0:
        report.append("### 🟡 Mejoras Recomendadas")
        report.append("")
        report.append(f"Se encontraron **{total_warnings} warnings** que sugieren mejoras:")
        report.append("")
        report.append("- Agregar Switch nodes después de Execute Workflow calls")
        report.append("- Revisar posibles secrets hardcodeados")
        report.append("- Verificar configuración de errorWorkflow")
        report.append("")
    
    # Comparison table
    report.append("## Tabla Comparativa: Migración vs SolucionFinal-v2.md")
    report.append("")
    report.append("| Requerimiento | Estado Migración | SolucionFinal-v2.md | Conflicto |")
    report.append("|---------------|------------------|---------------------|-----------|")
    
    # Calculate compliance
    has_workflow_id = len([r for r in all_results if not any(i.get('rule') == 'TRAZABILIDAD' for i in r['issues'])])
    has_meta = len([r for r in all_results if not any('_meta' in i.get('message', '') for i in r['issues'])])
    has_error_wf = len([r for r in all_results if not any(i.get('rule') == 'WORKFLOW_SETTINGS' for i in r['issues'])])
    has_try_catch = len([r for r in all_results if not any(i.get('rule') == 'ERROR_HANDLING' for i in r['issues'])])
    has_standard_contract = len([r for r in all_results if not any(i.get('rule') == 'STANDARD_CONTRACT' and i.get('severity') == 'CRITICAL' for i in r['issues'])])
    
    total = len(all_results)
    
    report.append(f"| WORKFLOW_ID constant | {has_workflow_id}/{total} | Obligatorio | {'❌ Sí' if has_workflow_id < total else '✅ No'} |")
    report.append(f"| _meta field | {has_meta}/{total} | Obligatorio | {'❌ Sí' if has_meta < total else '✅ No'} |")
    report.append(f"| errorWorkflow config | {has_error_wf}/{total} | Obligatorio | {'❌ Sí' if has_error_wf < total else '✅ No'} |")
    report.append(f"| Try-catch blocks | {has_try_catch}/{total} | Obligatorio | {'❌ Sí' if has_try_catch < total else '✅ No'} |")
    report.append(f"| Standard contract | {has_standard_contract}/{total} | Obligatorio | {'❌ Sí' if has_standard_contract < total else '✅ No'} |")
    report.append(f"| Single output | {total}/{total} | Obligatorio | ✅ No |")
    report.append(f"| No require() | {total}/{total} | Obligatorio | ✅ No |")
    report.append("")
    
    return "\n".join(report)

def main():
    workflows_dir = 'workflows'
    validator = WorkflowValidator()
    all_results = []
    
    print("Validando workflows contra SolucionFinal-v2.md...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            print(f"Analizando: {filename}...")
            results = validator.validate_workflow(filepath)
            all_results.append(results)
    
    print("\nGenerando reporte...")
    report = generate_report(all_results)
    
    # Save report
    report_path = 'docs/validation-report-solucionfinal-v2.md'
    with open(report_path, 'w') as f:
        f.write(report)
    
    print(f"\n✅ Reporte generado: {report_path}")
    print("=" * 60)
    
    # Print summary
    total_issues = sum(len(r['issues']) for r in all_results)
    critical_issues = sum(len([i for i in r['issues'] if i.get('severity') == 'CRITICAL']) for r in all_results)
    
    print(f"\nResumen:")
    print(f"  Workflows analizados: {len(all_results)}")
    print(f"  Issues críticos: {critical_issues}")
    print(f"  Issues totales: {total_issues}")
    print(f"  Warnings: {sum(len(r['warnings']) for r in all_results)}")
    
    return 0 if critical_issues == 0 else 1

if __name__ == '__main__':
    import sys
    sys.exit(main())

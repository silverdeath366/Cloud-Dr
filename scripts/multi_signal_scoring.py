#!/usr/bin/env python3
"""
Multi-Signal Health Scoring System
Aggregates health signals and determines failover actions
"""

import json
import sys
import logging
from typing import Dict, List, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class HealthScorer:
    """Multi-signal health scoring system"""
    
    # Signal weights
    WEIGHTS = {
        'internal_service': 2,
        'external_monitor': 3,
        'azure_probe': 4,
        'aws_cross_region': 3,
        'rds_lag': 2,
        'eks_nodes': 4,
        'alb_health': 3,
        'cloudwatch_alarm': 5
    }
    
    # Status to weight mapping
    STATUS_WEIGHTS = {
        'ok': 0,
        'degraded': 1,
        'warning': 2,
        'error': 3,
        'critical': 5
    }
    
    def __init__(self):
        self.signals = {}
        self.score = 0
    
    def add_signal(self, name: str, status: str, metadata: Dict = None):
        """Add a health signal"""
        base_weight = self.WEIGHTS.get(name.split('_')[0] if '_' in name else name, 1)
        status_weight = self.STATUS_WEIGHTS.get(status, 2)
        weight = base_weight * status_weight
        
        self.signals[name] = {
            'status': status,
            'weight': weight,
            'metadata': metadata or {}
        }
    
    def calculate_score(self) -> int:
        """Calculate composite health score"""
        total_score = 0
        for signal_name, signal_data in self.signals.items():
            weight = signal_data.get('weight', 0)
            total_score += weight
            logger.info(f"{signal_name}: {signal_data.get('status')} (weight: {weight})")
        
        self.score = total_score
        return self.score
    
    def get_action(self) -> Dict[str, Any]:
        """Determine action based on score"""
        if self.score <= 3:
            return {
                'action': 'none',
                'level': 0,
                'description': 'No action required - system healthy'
            }
        elif self.score <= 7:
            return {
                'action': 'app_self_healing',
                'level': 1,
                'description': 'Trigger application-level self-healing'
            }
        elif self.score <= 10:
            return {
                'action': 'region_failover',
                'level': 2,
                'description': 'Trigger region-level failover within AWS'
            }
        else:
            return {
                'action': 'dr_failover',
                'level': 3,
                'description': 'Trigger DR failover to Azure'
            }
    
    def get_report(self) -> Dict[str, Any]:
        """Generate health report"""
        score = self.calculate_score()
        action = self.get_action()
        
        return {
            'score': score,
            'action': action,
            'signals': self.signals,
            'summary': {
                'total_signals': len(self.signals),
                'healthy_signals': sum(1 for s in self.signals.values() if s['status'] == 'ok'),
                'degraded_signals': sum(1 for s in self.signals.values() if s['status'] == 'degraded'),
                'error_signals': sum(1 for s in self.signals.values() if s['status'] in ['error', 'critical'])
            }
        }

def main():
    """Main function"""
    scorer = HealthScorer()
    
    # Example: Load signals from healthcheck.py output
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            health_data = json.load(f)
            signals = health_data.get('signals', {})
            
            for name, data in signals.items():
                scorer.add_signal(name, data.get('status', 'unknown'), data)
    else:
        # Example signals
        scorer.add_signal('internal_service_a', 'ok')
        scorer.add_signal('internal_service_b', 'degraded')
        scorer.add_signal('external_monitor', 'error')
        scorer.add_signal('rds_lag', 'ok', {'lag_seconds': 2})
        scorer.add_signal('eks_nodes', 'ok')
    
    report = scorer.get_report()
    print(json.dumps(report, indent=2))
    
    # Exit code based on action level
    sys.exit(report['action']['level'])

if __name__ == '__main__':
    main()


#!/usr/bin/env python3
"""
CloudPhoenix Health Check Script
Collects health signals from multiple sources and calculates a composite score
"""

import os
import sys
import json
import time
import logging
import requests
import boto3
from botocore.exceptions import ClientError
import psycopg2
from psycopg2 import pool

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HealthChecker:
    """Multi-signal health checker for CloudPhoenix"""
    
    def __init__(self):
        self.signals = {}
        self.score = 0
        
    def check_internal_service_health(self, service_url):
        """Check internal service health endpoint"""
        try:
            response = requests.get(f"{service_url}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                status = data.get('status', 'unknown')
                checks = data.get('checks', {})
                
                if status == 'healthy':
                    return {'status': 'ok', 'weight': 0}
                elif status == 'degraded':
                    return {'status': 'degraded', 'weight': 2}
                else:
                    return {'status': 'unhealthy', 'weight': 5}
            else:
                return {'status': 'error', 'weight': 5}
        except Exception as e:
            logger.error(f"Internal service health check failed: {e}")
            return {'status': 'error', 'weight': 5}
    
    def check_external_uptime(self, url):
        """Check external uptime monitor"""
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                return {'status': 'ok', 'weight': 0}
            else:
                return {'status': 'error', 'weight': 3}
        except Exception as e:
            logger.error(f"External uptime check failed: {e}")
            return {'status': 'error', 'weight': 3}
    
    def check_azure_probe(self, probe_url):
        """Check Azure probe endpoint"""
        try:
            response = requests.get(probe_url, timeout=10)
            if response.status_code == 200:
                return {'status': 'ok', 'weight': 0}
            else:
                return {'status': 'error', 'weight': 4}
        except Exception as e:
            logger.error(f"Azure probe check failed: {e}")
            return {'status': 'error', 'weight': 4}
    
    def check_aws_cross_region(self, region, service_url):
        """Check AWS cross-region service"""
        try:
            # Use boto3 to check service in another region
            ec2 = boto3.client('ec2', region_name=region)
            ec2.describe_regions()
            
            # Also check service endpoint
            response = requests.get(service_url, timeout=10)
            if response.status_code == 200:
                return {'status': 'ok', 'weight': 0}
            else:
                return {'status': 'degraded', 'weight': 2}
        except Exception as e:
            logger.error(f"AWS cross-region check failed: {e}")
            return {'status': 'error', 'weight': 3}
    
    def check_rds_lag(self, db_host, db_port, db_name, db_user, db_password):
        """Check RDS replication lag"""
        try:
            conn = psycopg2.connect(
                host=db_host,
                port=db_port,
                database=db_name,
                user=db_user,
                password=db_password
            )
            cursor = conn.cursor()
            
            # Check replication lag (PostgreSQL)
            cursor.execute("""
                SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
            """)
            result = cursor.fetchone()
            lag_seconds = result[0] if result[0] else 0
            
            cursor.close()
            conn.close()
            
            if lag_seconds < 5:
                return {'status': 'ok', 'weight': 0, 'lag': lag_seconds}
            elif lag_seconds < 30:
                return {'status': 'degraded', 'weight': 1, 'lag': lag_seconds}
            else:
                return {'status': 'error', 'weight': 3, 'lag': lag_seconds}
        except Exception as e:
            logger.error(f"RDS lag check failed: {e}")
            return {'status': 'error', 'weight': 3}
    
    def check_eks_node_states(self, cluster_name, region):
        """Check EKS node states"""
        try:
            eks = boto3.client('eks', region_name=region)
            response = eks.describe_cluster(name=cluster_name)
            
            # Get node group status
            node_groups = eks.list_nodegroups(clusterName=cluster_name)
            unhealthy_nodes = 0
            
            for ng_name in node_groups.get('nodegroups', []):
                ng_info = eks.describe_nodegroup(
                    clusterName=cluster_name,
                    nodegroupName=ng_name
                )
                status = ng_info['nodegroup']['status']
                if status != 'ACTIVE':
                    unhealthy_nodes += 1
            
            if unhealthy_nodes == 0:
                return {'status': 'ok', 'weight': 0}
            elif unhealthy_nodes == 1:
                return {'status': 'degraded', 'weight': 2}
            else:
                return {'status': 'error', 'weight': 4}
        except Exception as e:
            logger.error(f"EKS node state check failed: {e}")
            return {'status': 'error', 'weight': 4}
    
    def calculate_score(self):
        """Calculate composite health score"""
        total_weight = 0
        for signal_name, signal_data in self.signals.items():
            weight = signal_data.get('weight', 0)
            total_weight += weight
            logger.info(f"Signal {signal_name}: {signal_data.get('status')} (weight: {weight})")
        
        self.score = total_weight
        return self.score
    
    def get_failover_level(self):
        """Determine failover level based on score"""
        if self.score <= 3:
            return "none"
        elif self.score <= 7:
            return "app_self_healing"
        elif self.score <= 10:
            return "region_failover"
        else:
            return "dr_failover"
    
    def run_checks(self, config):
        """Run all health checks"""
        logger.info("Starting health checks...")
        
        # Internal service health
        if 'internal_services' in config:
            for service in config['internal_services']:
                result = self.check_internal_service_health(service['url'])
                self.signals[f"internal_{service['name']}"] = result
        
        # External uptime
        if 'external_monitors' in config:
            for monitor in config['external_monitors']:
                result = self.check_external_uptime(monitor['url'])
                self.signals[f"external_{monitor['name']}"] = result
        
        # Azure probe
        if 'azure_probe' in config:
            result = self.check_azure_probe(config['azure_probe']['url'])
            self.signals['azure_probe'] = result
        
        # AWS cross-region
        if 'aws_cross_region' in config:
            result = self.check_aws_cross_region(
                config['aws_cross_region']['region'],
                config['aws_cross_region']['service_url']
            )
            self.signals['aws_cross_region'] = result
        
        # RDS lag
        if 'rds' in config:
            db_config = config['rds']
            result = self.check_rds_lag(
                db_config['host'],
                db_config['port'],
                db_config['database'],
                db_config['user'],
                db_config['password']
            )
            self.signals['rds_lag'] = result
        
        # EKS node states
        if 'eks' in config:
            result = self.check_eks_node_states(
                config['eks']['cluster_name'],
                config['eks']['region']
            )
            self.signals['eks_nodes'] = result
        
        # Calculate score
        score = self.calculate_score()
        failover_level = self.get_failover_level()
        
        return {
            'score': score,
            'failover_level': failover_level,
            'signals': self.signals,
            'timestamp': time.time()
        }

def main():
    """Main function"""
    # Load configuration
    config_file = os.getenv('HEALTH_CONFIG', '/etc/cloudphoenix/health_config.json')
    
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        logger.warning(f"Config file not found: {config_file}, using defaults")
        config = {
            'internal_services': [
                {'name': 'service-a', 'url': os.getenv('SERVICE_A_URL', 'http://service-a:8080')},
                {'name': 'service-b', 'url': os.getenv('SERVICE_B_URL', 'http://service-b:8080')}
            ],
            'external_monitors': [
                {'name': 'uptime', 'url': os.getenv('UPTIME_URL', 'https://httpbin.org/status/200')}
            ],
            'azure_probe': {
                'url': os.getenv('AZURE_PROBE_URL', '')
            },
            'aws_cross_region': {
                'region': os.getenv('AWS_SECONDARY_REGION', 'us-west-2'),
                'service_url': os.getenv('AWS_SECONDARY_SERVICE_URL', '')
            },
            'rds': {
                'host': os.getenv('DB_HOST', ''),
                'port': os.getenv('DB_PORT', '5432'),
                'database': os.getenv('DB_NAME', 'cloudphoenix'),
                'user': os.getenv('DB_USER', ''),
                'password': os.getenv('DB_PASSWORD', '')
            },
            'eks': {
                'cluster_name': os.getenv('EKS_CLUSTER_NAME', ''),
                'region': os.getenv('AWS_REGION', 'us-east-1')
            }
        }
    
    checker = HealthChecker()
    result = checker.run_checks(config)
    
    # Output result
    print(json.dumps(result, indent=2))
    
    # Exit with appropriate code
    if result['failover_level'] == 'dr_failover':
        sys.exit(2)  # Critical - trigger DR
    elif result['failover_level'] == 'region_failover':
        sys.exit(1)  # Warning - region failover
    else:
        sys.exit(0)  # OK

if __name__ == '__main__':
    main()


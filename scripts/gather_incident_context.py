#!/usr/bin/env python3
"""
CloudPhoenix Incident Context Gatherer
Collects comprehensive context about an incident for LLM analysis:
- AWS service status
- Cloudflare status
- Internal logs and metrics
- Health check results
"""

import os
import sys
import json
import logging
import requests
import boto3
from datetime import datetime, timedelta
from typing import Dict, Any

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IncidentContextGatherer:
    """Gathers comprehensive incident context for LLM analysis"""
    
    def __init__(self):
        self.context = {
            'timestamp': datetime.utcnow().isoformat(),
            'aws_status': {},
            'cloudflare_status': {},
            'health_check_results': {},
            'internal_metrics': {},
            'recent_logs': [],
            'error_patterns': []
        }
    
    def check_aws_status(self) -> Dict[str, Any]:
        """Check AWS service health status"""
        aws_status = {
            'region_health': {},
            'service_status': {},
            'last_updated': None
        }
        
        try:
            # Check AWS Health API (if available)
            # Note: AWS Health API requires AWS Support access
            health_client = boto3.client('health', region_name='us-east-1')
            
            # Get events affecting our account
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=2)
            
            try:
                events = health_client.describe_events(
                    filter={
                        'startTimes': [
                            {'from': start_time, 'to': end_time}
                        ]
                    },
                    maxResults=10
                )
                
                aws_status['recent_events'] = [
                    {
                        'arn': event.get('arn', ''),
                        'service': event.get('service', ''),
                        'eventTypeCode': event.get('eventTypeCode', ''),
                        'statusCode': event.get('statusCode', ''),
                        'startTime': event.get('startTime', '').isoformat() if hasattr(event.get('startTime', ''), 'isoformat') else str(event.get('startTime', '')),
                    }
                    for event in events.get('events', [])
                ]
                
                # Check for open events
                open_events = [e for e in aws_status['recent_events'] if e['statusCode'] == 'open']
                aws_status['has_open_issues'] = len(open_events) > 0
                aws_status['open_event_count'] = len(open_events)
                
            except Exception as e:
                logger.warning(f"AWS Health API not accessible or no permission: {e}")
                aws_status['health_api_error'] = str(e)
            
            # Check EC2 service status via describe operations
            try:
                ec2 = boto3.client('ec2')
                regions = ec2.describe_regions()
                aws_status['regions_accessible'] = len(regions.get('Regions', []))
                
                # Try to describe instances in primary region
                primary_region = os.getenv('AWS_REGION', 'us-east-1')
                ec2_primary = boto3.client('ec2', region_name=primary_region)
                instances = ec2_primary.describe_instances(MaxResults=1)
                aws_status['region_health'][primary_region] = 'operational'
                
            except Exception as e:
                logger.error(f"Failed to check EC2 status: {e}")
                aws_status['region_health'][primary_region] = 'degraded'
                aws_status['ec2_error'] = str(e)
            
            # Check public AWS status page (fallback)
            try:
                # AWS publishes status to status.aws.amazon.com
                # We'll try to fetch it (note: this may require parsing HTML)
                aws_status['status_page_note'] = 'Check https://status.aws.amazon.com/ manually'
            except Exception as e:
                logger.warning(f"Could not fetch AWS status page: {e}")
            
        except Exception as e:
            logger.error(f"Error checking AWS status: {e}")
            aws_status['error'] = str(e)
        
        return aws_status
    
    def check_cloudflare_status(self) -> Dict[str, Any]:
        """Check Cloudflare service health status"""
        cloudflare_status = {
            'api_status': 'unknown',
            'components': [],
            'incidents': [],
            'last_updated': None
        }
        
        try:
            # Cloudflare Status API (public, no auth required)
            status_url = "https://www.cloudflarestatus.com/api/v2/status.json"
            response = requests.get(status_url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                cloudflare_status['api_status'] = data.get('status', {}).get('indicator', 'unknown')
                cloudflare_status['description'] = data.get('status', {}).get('description', '')
                
                # Get components
                components_url = "https://www.cloudflarestatus.com/api/v2/components.json"
                components_response = requests.get(components_url, timeout=10)
                if components_response.status_code == 200:
                    components_data = components_response.json()
                    cloudflare_status['components'] = [
                        {
                            'name': comp.get('name', ''),
                            'status': comp.get('status', ''),
                        }
                        for comp in components_data.get('components', [])
                        if comp.get('status') != 'operational'
                    ]
                
                # Get recent incidents
                incidents_url = "https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json"
                incidents_response = requests.get(incidents_url, timeout=10)
                if incidents_response.status_code == 200:
                    incidents_data = incidents_response.json()
                    cloudflare_status['incidents'] = [
                        {
                            'name': inc.get('name', ''),
                            'status': inc.get('status', ''),
                            'impact': inc.get('impact', ''),
                            'created_at': inc.get('created_at', ''),
                        }
                        for inc in incidents_data.get('incidents', [])
                    ]
                    cloudflare_status['has_active_incidents'] = len(cloudflare_status['incidents']) > 0
                
        except Exception as e:
            logger.error(f"Error checking Cloudflare status: {e}")
            cloudflare_status['error'] = str(e)
            cloudflare_status['api_status'] = 'error'
        
        return cloudflare_status
    
    def gather_health_check_results(self) -> Dict[str, Any]:
        """Gather recent health check results"""
        try:
            # Import and run healthcheck
            import subprocess
            result = subprocess.run(
                [sys.executable, 'scripts/healthcheck.py'],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0 or result.stdout:
                try:
                    health_data = json.loads(result.stdout)
                    return health_data
                except json.JSONDecodeError:
                    logger.warning("Could not parse health check output as JSON")
                    return {'raw_output': result.stdout[:500]}
            else:
                return {'error': 'Health check failed', 'stderr': result.stderr[:500]}
                
        except Exception as e:
            logger.error(f"Error gathering health check results: {e}")
            return {'error': str(e)}
    
    def gather_prometheus_metrics(self) -> Dict[str, Any]:
        """Gather recent metrics from Prometheus"""
        metrics = {
            'error_rate': None,
            'latency_p95': None,
            'availability': None,
            'source': 'prometheus'
        }
        
        try:
            prometheus_url = os.getenv('PROMETHEUS_URL', 'http://prometheus:9090')
            query_url = f"{prometheus_url}/api/v1/query"
            
            # Query error rate
            try:
                error_query = 'rate(http_requests_total{status=~"5.."}[5m])'
                response = requests.get(
                    query_url,
                    params={'query': error_query},
                    timeout=5
                )
                if response.status_code == 200:
                    data = response.json()
                    if data.get('status') == 'success' and data.get('data', {}).get('result'):
                        metrics['error_rate'] = data['data']['result'][0].get('value', [None, None])[1]
            except Exception as e:
                logger.debug(f"Could not query Prometheus error rate: {e}")
            
            # Query latency
            try:
                latency_query = 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))'
                response = requests.get(
                    query_url,
                    params={'query': latency_query},
                    timeout=5
                )
                if response.status_code == 200:
                    data = response.json()
                    if data.get('status') == 'success' and data.get('data', {}).get('result'):
                        metrics['latency_p95'] = data['data']['result'][0].get('value', [None, None])[1]
            except Exception as e:
                logger.debug(f"Could not query Prometheus latency: {e}")
                
        except Exception as e:
            logger.warning(f"Could not gather Prometheus metrics: {e}")
            metrics['error'] = str(e)
        
        return metrics
    
    def gather_recent_logs(self, limit: int = 50) -> list:
        """Gather recent error logs from Loki"""
        logs = []
        
        try:
            loki_url = os.getenv('LOKI_URL', 'http://loki:3100')
            query_url = f"{loki_url}/loki/api/v1/query_range"
            
            # Query recent error logs
            end_time = int(datetime.utcnow().timestamp() * 1e9)  # nanoseconds
            start_time = end_time - (3600 * 1e9)  # last hour
            
            response = requests.get(
                query_url,
                params={
                    'query': '{job=~".+"} |= "error" |= "ERROR" |= "exception"',
                    'start': int(start_time),
                    'end': int(end_time),
                    'limit': limit
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                for stream in data.get('data', {}).get('result', []):
                    for entry in stream.get('values', [])[-10:]:  # Last 10 entries per stream
                        logs.append({
                            'timestamp': entry[0],
                            'message': entry[1][:500]  # Truncate long messages
                        })
        
        except Exception as e:
            logger.warning(f"Could not gather Loki logs: {e}")
            logs.append({'error': str(e)})
        
        return logs[:limit]  # Limit total logs
    
    def gather_all_context(self) -> Dict[str, Any]:
        """Gather all incident context"""
        logger.info("Gathering incident context...")
        
        self.context['aws_status'] = self.check_aws_status()
        self.context['cloudflare_status'] = self.check_cloudflare_status()
        self.context['health_check_results'] = self.gather_health_check_results()
        self.context['internal_metrics'] = self.gather_prometheus_metrics()
        self.context['recent_logs'] = self.gather_recent_logs()
        
        # Analyze patterns
        self._analyze_patterns()
        
        return self.context
    
    def _analyze_patterns(self):
        """Analyze collected data for patterns"""
        patterns = []
        
        # Check if AWS has issues
        aws_issues = (
            self.context['aws_status'].get('has_open_issues', False) or
            'degraded' in str(self.context['aws_status'].get('region_health', {})).lower()
        )
        if aws_issues:
            patterns.append({
                'type': 'aws_infrastructure_issue',
                'confidence': 'high' if self.context['aws_status'].get('has_open_issues') else 'medium',
                'details': 'AWS service health issues detected'
            })
        
        # Check if Cloudflare has issues
        cf_issues = (
            self.context['cloudflare_status'].get('has_active_incidents', False) or
            self.context['cloudflare_status'].get('api_status') in ['major', 'critical']
        )
        if cf_issues:
            patterns.append({
                'type': 'cloudflare_infrastructure_issue',
                'confidence': 'high',
                'details': 'Cloudflare active incidents detected'
            })
        
        # Check internal error patterns
        error_log_count = len([log for log in self.context['recent_logs'] if 'error' in log.get('message', '').lower()])
        if error_log_count > 10:
            patterns.append({
                'type': 'internal_error_spike',
                'confidence': 'medium',
                'details': f'High error log volume: {error_log_count} recent errors'
            })
        
        self.context['error_patterns'] = patterns
    
    def format_for_llm(self) -> str:
        """Format context as prompt for LLM"""
        prompt = f"""# Incident Analysis Request

## Timestamp
{self.context['timestamp']}

## AWS Infrastructure Status
{json.dumps(self.context['aws_status'], indent=2)}

## Cloudflare Infrastructure Status
{json.dumps(self.context['cloudflare_status'], indent=2)}

## Internal Health Check Results
{json.dumps(self.context['health_check_results'], indent=2)}

## Internal Metrics (Prometheus)
{json.dumps(self.context['internal_metrics'], indent=2)}

## Recent Error Logs (Sample)
{json.dumps(self.context['recent_logs'][:10], indent=2)}

## Detected Patterns
{json.dumps(self.context['error_patterns'], indent=2)}

---

## Your Task

Analyze this incident and determine:

1. **Root Cause Category:**
   - "aws_infrastructure" - Problem is with AWS services (EKS, RDS, S3, etc.)
   - "cloudflare_infrastructure" - Problem is with Cloudflare services
   - "internal_bug" - Problem is with our application/infrastructure code
   - "network" - Network connectivity issue
   - "unknown" - Cannot determine with available data

2. **Confidence Level:** high, medium, or low

3. **Evidence:** Brief explanation of why you reached this conclusion

4. **Recommended Action:**
   - "trigger_dr" - Only if it's AWS or Cloudflare infrastructure issue affecting service availability
   - "investigate" - If it's likely an internal bug
   - "monitor" - If unclear or minor issue
   - "wait" - If external service shows resolution in progress

5. **Reasoning:** Detailed explanation

Respond in JSON format:
{{
  "root_cause_category": "...",
  "confidence": "...",
  "evidence": "...",
  "recommended_action": "...",
  "reasoning": "..."
}}
"""
        return prompt


def main():
    """Main function"""
    gatherer = IncidentContextGatherer()
    context = gatherer.gather_all_context()
    
    # Output full context as JSON
    print(json.dumps(context, indent=2, default=str))
    
    # Also output LLM-formatted prompt if requested
    if '--llm-prompt' in sys.argv:
        prompt = gatherer.format_for_llm()
        print("\n" + "="*80)
        print("LLM PROMPT:")
        print("="*80)
        print(prompt)


if __name__ == '__main__':
    main()


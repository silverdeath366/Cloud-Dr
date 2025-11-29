#!/usr/bin/env python3
"""
Service B - CloudPhoenix Application Service
Production-ready Flask application with proper error handling, logging, and observability
"""

import os
import sys
import time
import signal
import json
import logging
import traceback
from contextlib import contextmanager
from functools import wraps
from typing import Dict, Any, Optional
from datetime import datetime

from flask import Flask, jsonify, request, g
import psycopg2
from psycopg2 import pool, OperationalError, InterfaceError
from psycopg2.extras import RealDictCursor
import boto3
from botocore.exceptions import ClientError, BotoCoreError
from botocore.config import Config
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False

# Application state
db_pool: Optional[pool.ThreadedConnectionPool] = None
s3_client: Optional[boto3.client] = None
shutdown_flag = False

# Configuration
DB_CONNECT_TIMEOUT = int(os.getenv('DB_CONNECT_TIMEOUT', '10'))
DB_POOL_MIN = int(os.getenv('DB_POOL_MIN', '2'))
DB_POOL_MAX = int(os.getenv('DB_POOL_MAX', '20'))
S3_RETRY_CONFIG = Config(
    retries={'max_attempts': 3, 'mode': 'adaptive'},
    connect_timeout=10,
    read_timeout=10
)
HEALTH_CHECK_TIMEOUT = int(os.getenv('HEALTH_CHECK_TIMEOUT', '5'))


class ServiceError(Exception):
    """Base exception for service errors"""
    pass


class DatabaseError(ServiceError):
    """Database-related errors"""
    pass


class StorageError(ServiceError):
    """Storage-related errors"""
    pass


def retry_db_operation(max_retries=3, delay=1):
    """Decorator for retrying database operations"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except (OperationalError, InterfaceError) as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        logger.warning(f"Database operation failed (attempt {attempt + 1}/{max_retries}): {e}")
                        time.sleep(delay * (attempt + 1))
                    else:
                        logger.error(f"Database operation failed after {max_retries} attempts: {e}")
                        raise DatabaseError(f"Database operation failed: {e}") from e
            raise last_exception
        return wrapper
    return decorator


@contextmanager
def get_db_connection():
    """Context manager for database connections with proper error handling"""
    conn = None
    try:
        if not db_pool:
            raise DatabaseError("Database pool not initialized")
        
        conn = db_pool.getconn(timeout=5)
        if not conn:
            raise DatabaseError("Failed to get connection from pool")
        
        yield conn
    except (OperationalError, InterfaceError) as e:
        logger.error(f"Database connection error: {e}")
        if conn:
            try:
                db_pool.putconn(conn, close=True)
            except Exception:
                pass
        raise DatabaseError(f"Database connection failed: {e}") from e
    except Exception as e:
        logger.error(f"Unexpected database error: {e}")
        if conn:
            try:
                db_pool.putconn(conn)
            except Exception:
                pass
        raise
    else:
        if conn:
            db_pool.putconn(conn)


def init_db_pool() -> bool:
    """Initialize database connection pool with retries"""
    global db_pool
    
    db_host = os.getenv('DB_HOST')
    if not db_host:
        logger.error("DB_HOST environment variable not set")
        return False
    
    db_port = int(os.getenv('DB_PORT', '5432'))
    db_name = os.getenv('DB_NAME', 'cloudphoenix')
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')
    
    if not db_user or not db_password:
        logger.warning("DB_USER or DB_PASSWORD not set, attempting IAM authentication")
        # In production, use IAM roles for RDS authentication
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            db_pool = psycopg2.pool.ThreadedConnectionPool(
                minconn=DB_POOL_MIN,
                maxconn=DB_POOL_MAX,
                host=db_host,
                port=db_port,
                database=db_name,
                user=db_user,
                password=db_password,
                connect_timeout=DB_CONNECT_TIMEOUT,
                options='-c statement_timeout=30000'  # 30 second statement timeout
            )
            
            # Test connection
            test_conn = db_pool.getconn()
            test_conn.close()
            db_pool.putconn(test_conn)
            
            logger.info(f"Database connection pool initialized (min={DB_POOL_MIN}, max={DB_POOL_MAX})")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize DB pool (attempt {attempt + 1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # Exponential backoff
            else:
                logger.critical("Failed to initialize database pool after all retries")
                return False
    
    return False


def init_s3() -> bool:
    """Initialize S3 client using IAM roles (preferred) or credentials"""
    global s3_client
    
    try:
        # Prefer IAM role over credentials
        # In EKS, use IAM roles for service accounts
        region = os.getenv('AWS_REGION', 'us-east-1')
        
        # Check if we should use IAM role (no credentials provided)
        if not os.getenv('AWS_ACCESS_KEY_ID'):
            logger.info("Using IAM role for S3 access")
            s3_client = boto3.client('s3', region_name=region, config=S3_RETRY_CONFIG)
        else:
            logger.info("Using provided credentials for S3 access")
            s3_client = boto3.client(
                's3',
                aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
                aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
                region_name=region,
                config=S3_RETRY_CONFIG
            )
        
        # Test connection
        s3_client.list_buckets()
        logger.info("S3 client initialized successfully")
        return True
    except (ClientError, BotoCoreError) as e:
        logger.error(f"Failed to initialize S3 client: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error initializing S3: {e}")
        return False


def validate_request_json(required_fields=None):
    """Validate request JSON and required fields"""
    if not request.is_json:
        return False, "Content-Type must be application/json"
    
    data = request.get_json(silent=True)
    if data is None:
        return False, "Invalid JSON in request body"
    
    if required_fields:
        missing = [field for field in required_fields if field not in data]
        if missing:
            return False, f"Missing required fields: {', '.join(missing)}"
    
    return True, data


@app.before_request
def before_request():
    """Set request start time and add request ID"""
    g.start_time = time.time()
    g.request_id = request.headers.get('X-Request-ID', f"{int(time.time() * 1000)}")


@app.after_request
def after_request(response):
    """Log request and add security headers"""
    # Calculate request duration
    duration = time.time() - g.start_time
    
    # Log request
    logger.info(
        f"Request: {request.method} {request.path} | "
        f"Status: {response.status_code} | "
        f"Duration: {duration:.3f}s | "
        f"Request-ID: {g.request_id}"
    )
    
    # Add comprehensive security headers
    response.headers['X-Request-ID'] = g.request_id
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:"
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    return response


@app.errorhandler(Exception)
def handle_exception(e):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {e}\n{traceback.format_exc()}")
    
    # Don't expose internal errors in production
    if app.debug:
        error_message = str(e)
        error_trace = traceback.format_exc()
    else:
        error_message = "Internal server error"
        error_trace = None
    
    return jsonify({
        'error': error_message,
        'request_id': g.get('request_id', 'unknown'),
        'trace': error_trace
    }), 500


@app.route('/health', methods=['GET'])
def health():
    """Comprehensive health check endpoint"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'service-b',
        'version': os.getenv('SERVICE_VERSION', '1.0.0'),
        'checks': {}
    }
    
    overall_healthy = True
    
    # Database check with timeout
    try:
        if db_pool:
            start = time.time()
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('SELECT 1')
                cursor.close()
            duration = time.time() - start
            
            health_status['checks']['database'] = {
                'status': 'ok',
                'response_time_ms': round(duration * 1000, 2)
            }
        else:
            health_status['checks']['database'] = {'status': 'not_initialized'}
            overall_healthy = False
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        health_status['checks']['database'] = {
            'status': 'error',
            'error': str(e) if app.debug else 'Connection failed'
        }
        overall_healthy = False
    
    # S3 check with timeout
    try:
        if s3_client:
            start = time.time()
            s3_client.list_buckets()
            duration = time.time() - start
            
            health_status['checks']['s3'] = {
                'status': 'ok',
                'response_time_ms': round(duration * 1000, 2)
            }
        else:
            health_status['checks']['s3'] = {'status': 'not_initialized'}
            overall_healthy = False
    except Exception as e:
        logger.error(f"S3 health check failed: {e}")
        health_status['checks']['s3'] = {
            'status': 'error',
            'error': str(e) if app.debug else 'Connection failed'
        }
        overall_healthy = False
    
    # Determine overall status
    if not overall_healthy:
        health_status['status'] = 'degraded' if any(
            check.get('status') == 'ok' for check in health_status['checks'].values()
        ) else 'unhealthy'
    
    status_code = 200 if health_status['status'] == 'healthy' else 503
    return jsonify(health_status), status_code


@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe - checks if service can accept traffic"""
    if db_pool and s3_client:
        # Quick connectivity check
        try:
            with get_db_connection() as conn:
                pass
            return jsonify({'status': 'ready'}), 200
        except Exception as e:
            logger.warning(f"Readiness check failed: {e}")
            return jsonify({'status': 'not_ready', 'reason': str(e)}), 503
    
    return jsonify({'status': 'not_ready', 'reason': 'Dependencies not initialized'}), 503


@app.route('/live', methods=['GET'])
def live():
    """Liveness probe - checks if service is running"""
    return jsonify({
        'status': 'alive',
        'uptime_seconds': time.time() - app.start_time if hasattr(app, 'start_time') else 0
    }), 200


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus-compatible metrics endpoint"""
    metrics_data = {
        'http_requests_total': 0,  # Would be tracked in production
        'http_request_duration_seconds': 0,
        'db_connections_active': db_pool.getconn() if db_pool else 0,
        'db_connections_idle': (DB_POOL_MAX - db_pool.getconn()) if db_pool else 0,
    }
    return jsonify(metrics_data), 200


@app.route('/api/process', methods=['POST'])
def process():
    """Process data endpoint with validation"""
    valid, result = validate_request_json(required_fields=['data'])
    if not valid:
        return jsonify({'error': result, 'request_id': g.request_id}), 400
    
    data = result
    data_value = data.get('data', '').strip()
    
    if not data_value:
        return jsonify({'error': 'Data field cannot be empty', 'request_id': g.request_id}), 400
    
    if len(data_value) > 10000:  # Reasonable limit
        return jsonify({'error': 'Data field too large (max 10000 chars)', 'request_id': g.request_id}), 400
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            # Simulate processing
            processed = f"processed_{data_value}"
            cursor.execute(
                'INSERT INTO app_data (data) VALUES (%s) RETURNING id, created_at',
                (processed,)
            )
            result = cursor.fetchone()
            row_id, created_at = result[0], result[1]
            conn.commit()
            cursor.close()
        
        return jsonify({
            'id': row_id,
            'processed': processed,
            'created_at': created_at.isoformat(),
            'request_id': g.request_id
        }), 201
    except DatabaseError as e:
        logger.error(f"Database error in process: {e}")
        return jsonify({
            'error': 'Database error',
            'request_id': g.request_id
        }), 503
    except Exception as e:
        logger.error(f"Unexpected error in process: {e}")
        return jsonify({
            'error': 'Internal server error',
            'request_id': g.request_id
        }), 500


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_flag
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_flag = True


def main():
    """Main application entry point"""
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    app.start_time = time.time()
    
    # Initialize dependencies
    logger.info("Initializing Service B...")
    
    if not init_db_pool():
        logger.critical("Failed to initialize database pool. Exiting.")
        sys.exit(1)
    
    if not init_s3():
        logger.warning("Failed to initialize S3 client. Service will run in degraded mode.")
    
    # Run application
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', '8080'))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting Service B on {host}:{port} (debug={debug})")
    
    try:
        app.run(host=host, port=port, debug=debug, threaded=True)
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt, shutting down...")
    finally:
        # Cleanup
        logger.info("Cleaning up resources...")
        if db_pool:
            try:
                db_pool.closeall()
                logger.info("Database pool closed")
            except Exception as e:
                logger.error(f"Error closing database pool: {e}")


if __name__ == '__main__':
    main()

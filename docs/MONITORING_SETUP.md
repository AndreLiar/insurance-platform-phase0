# Monitoring Setup Guide - Docker Grafana & Prometheus

## Quick Start

1. **Start Monitoring Stack**
   ```bash
   docker-compose -f docker-compose.monitoring.yml up -d
   ```

2. **Access Dashboards**
   - Grafana: http://localhost:3000 (admin/admin123)
   - Prometheus: http://localhost:9090
   - SQL Server Exporter: http://localhost:4000/metrics

3. **Start API with Metrics**
   ```bash
   cd api
   dotnet run
   ```

4. **Verify Metrics Collection**
   - API metrics: http://localhost:5000/metrics
   - Test API: http://localhost:5000/healthz

## What's Monitored

### Application Metrics
- **HTTP Requests**: Rate, duration, status codes
- **API Endpoints**: Response times, error rates
- **Database Queries**: RLS policy performance
- **Authentication**: Login success/failure rates

### Database Metrics
- **Connections**: Active connections, connection pool
- **Performance**: Query execution times, deadlocks
- **Security**: RLS violations, cross-tenant attempts
- **Business Logic**: User operations, role assignments

### Infrastructure Metrics
- **System Resources**: CPU, memory, disk usage
- **Network**: Request/response patterns
- **Availability**: Service health checks

## Dashboard Features

### Insurance Platform Dashboard
- **API Request Rate**: Real-time request volume
- **Database Connections**: Active SQL connections
- **User Account Operations**: CRUD operations on users
- **RLS Policy Performance**: Query performance with tenant isolation
- **Outbox Event Status**: Event processing pipeline
- **Cross-Tenant Access Attempts**: Security violations

## Custom Metrics

The API exposes custom metrics for business logic:

```csharp
// Example custom counters (add to Program.cs if needed)
private static readonly Counter UserOperations = Metrics
    .CreateCounter("user_operations_total", "Total user operations", "operation", "tenant");

private static readonly Histogram QueryDuration = Metrics
    .CreateHistogram("database_query_duration_seconds", "Database query duration");
```

## Alerting Setup (Optional)

Add to `prometheus.yml` for basic alerting:

```yaml
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

Create `monitoring/alerts.yml`:
```yaml
groups:
- name: insurance-api
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High error rate detected
      
  - alert: DatabaseConnectionsHigh
    expr: mssql_connections > 50
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: High database connections
```

## Production Considerations

1. **Data Retention**
   - Prometheus: 200h (configured)
   - Grafana: Persistent volumes
   - Consider long-term storage solutions

2. **Security**
   - Enable authentication on Grafana
   - Secure Prometheus endpoints
   - Use HTTPS in production

3. **Scaling**
   - Prometheus federation for multiple services
   - Grafana clustering
   - Remote storage backends

## Troubleshooting

### Common Issues

**Metrics not appearing:**
```bash
# Check API metrics endpoint
curl http://localhost:5000/metrics

# Check Prometheus targets
# Go to http://localhost:9090/targets
```

**Grafana dashboard empty:**
```bash
# Verify Prometheus datasource
# Grafana → Configuration → Data Sources → Test

# Check Prometheus query
# Example: up{job="insurance-api"}
```

**SQL Server exporter failing:**
```bash
# Check container logs
docker logs sqlserver-exporter

# Verify connection string in docker-compose.monitoring.yml
```

### Log Analysis

**View container logs:**
```bash
docker-compose -f docker-compose.monitoring.yml logs -f grafana
docker-compose -f docker-compose.monitoring.yml logs -f prometheus
```

**Reset monitoring data:**
```bash
docker-compose -f docker-compose.monitoring.yml down -v
docker-compose -f docker-compose.monitoring.yml up -d
```

## Next Steps

1. **Custom Dashboards**: Create tenant-specific views
2. **Alerting**: Set up notifications for critical issues
3. **Business Metrics**: Track insurance-specific KPIs
4. **Log Aggregation**: Add ELK stack for centralized logging
5. **APM**: Consider Application Performance Monitoring tools
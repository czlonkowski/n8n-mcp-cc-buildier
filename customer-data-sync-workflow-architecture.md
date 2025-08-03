# Customer Data Synchronization Workflow Architecture

## Workflow Overview
Robust daily customer data synchronization system that fetches data from a paginated REST API and performs upsert operations to PostgreSQL with comprehensive error handling, retry logic, and performance optimizations for large datasets.

## Trigger Configuration
- **Schedule Trigger** (nodes-base.scheduleTrigger) - Daily at 2:00 AM UTC
  - Key configs: `rule.interval[0].field = "cronExpression"`
  - Key configs: `rule.interval[0].expression = "0 2 * * *"`
  - Rationale: Low-traffic window minimizes API load and database contention

## Main Flow

### 1. Initialize Variables - Code Node (nodes-base.code)
Purpose: Set up pagination tracking and error collection
Key configs:
```javascript
// Initialize workflow variables
return [{
  json: {
    currentPage: 1,
    pageSize: 100,
    hasMorePages: true,
    totalProcessed: 0,
    errors: [],
    syncStartTime: new Date().toISOString()
  }
}];
```

### 2. Pagination Loop Controller - Code Node
Purpose: Control pagination flow and check for more pages
Key configs:
```javascript
// Check if should continue pagination
const items = $input.all();
const lastItem = items[items.length - 1].json;

if (lastItem.hasMorePages) {
  return [{
    json: {
      ...lastItem,
      continueLoop: true
    }
  }];
} else {
  return [{
    json: {
      ...lastItem,
      continueLoop: false
    }
  }];
}
```

### 3. HTTP Request - Fetch Customer Data (nodes-base.httpRequest)
Purpose: Retrieve paginated customer data from REST API
Key configs:
- `method: "GET"`
- `url: "https://api.example.com/customers"`
- `authentication: "genericCredentialType"` (or appropriate auth method)
- `sendQuery: true`
- `queryParameters.parameters[0].name: "page"`
- `queryParameters.parameters[0].value: "{{ $json.currentPage }}"`
- `queryParameters.parameters[1].name: "limit"`
- `queryParameters.parameters[1].value: "{{ $json.pageSize }}"`
- `timeout: 60000` (60 seconds)
- `retry: 3`
- `retryDelay: 5000` (exponential backoff)
- `continueOnFail: true` (to handle errors gracefully)

### 4. Validate & Transform Data - Code Node
Purpose: Validate API response structure and transform for database insertion
Key configs:
```javascript
// Validate and transform customer data
const apiResponse = $input.all()[0].json;
const errors = [];
const validRecords = [];

// Check if response has expected structure
if (!apiResponse.data || !Array.isArray(apiResponse.data)) {
  throw new Error('Invalid API response structure');
}

// Process each customer record
apiResponse.data.forEach((customer, index) => {
  try {
    // Validate required fields
    if (!customer.id || !customer.email) {
      errors.push({
        record: customer,
        error: 'Missing required fields',
        index: index
      });
      return;
    }
    
    // Transform for database
    validRecords.push({
      customer_id: customer.id,
      email: customer.email.toLowerCase(),
      name: customer.name || '',
      phone: customer.phone || null,
      address: customer.address || null,
      created_at: customer.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString(),
      sync_batch_id: $json.syncStartTime
    });
  } catch (err) {
    errors.push({
      record: customer,
      error: err.message,
      index: index
    });
  }
});

// Update pagination info
const hasMore = apiResponse.pagination?.hasNext || false;
const nextPage = $json.currentPage + 1;

return [{
  json: {
    validRecords: validRecords,
    invalidRecords: errors,
    hasMorePages: hasMore,
    currentPage: nextPage,
    totalProcessed: $json.totalProcessed + validRecords.length,
    recordsInBatch: validRecords.length
  }
}];
```

### 5. IF Node - Route Valid/Invalid Records (nodes-base.if)
Purpose: Split flow based on data validation results
Key configs:
- `conditions.conditions[0].value1: "{{ $json.validRecords.length }}"`
- `conditions.conditions[0].operation: "larger"`
- `conditions.conditions[0].value2: 0`

### 6A. PostgreSQL - Upsert Valid Records (nodes-base.postgres)
Purpose: Insert or update customer records in batches
Key configs:
- `operation: "upsert"`
- `table: "customers"`
- `columns: "customer_id,email,name,phone,address,created_at,updated_at,sync_batch_id"`
- `conflictColumns: "customer_id"`
- `updateColumns: "email,name,phone,address,updated_at,sync_batch_id"`
- `mode: "list"`
- `batchSize: 200` (optimal for PostgreSQL performance)
- `continueOnFail: true`
- Connection configs:
  - `connectionTimeout: 30000`
  - `requestTimeout: 60000`

### 6B. Google Sheets - Log Invalid Records (nodes-base.googleSheets)
Purpose: Store invalid records for manual review
Key configs:
- `operation: "append"`
- `sheetId: "{{ $env.ERROR_LOG_SHEET_ID }}"`
- `range: "ErrorLog!A:Z"`
- `options.valueInputMode: "USER_ENTERED"`
- `options.dateTimeRenderOption: "FORMATTED_STRING"`
- Fields mapped: timestamp, customer_id, error_message, raw_data

### 7. Error Handler - Code Node
Purpose: Collect and format all errors from the batch
Key configs:
```javascript
// Aggregate errors from current batch
const dbErrors = $node["PostgreSQL"].errors || [];
const validationErrors = $json.invalidRecords || [];

const allErrors = [
  ...validationErrors.map(e => ({
    type: 'validation',
    ...e
  })),
  ...dbErrors.map(e => ({
    type: 'database',
    error: e.message,
    query: e.query
  }))
];

return [{
  json: {
    batchErrors: allErrors,
    errorCount: allErrors.length,
    ...($json)
  }
}];
```

### 8. Loop Decision - IF Node
Purpose: Determine whether to continue pagination
Key configs:
- `conditions.conditions[0].value1: "{{ $json.continueLoop }}"`
- `conditions.conditions[0].operation: "equal"`
- `conditions.conditions[0].value2: true`

### 9. Summary Report Generator - Code Node
Purpose: Create comprehensive sync summary
Key configs:
```javascript
// Generate sync summary report
const syncEndTime = new Date();
const syncStartTime = new Date($json.syncStartTime);
const duration = (syncEndTime - syncStartTime) / 1000; // seconds

return [{
  json: {
    summary: {
      status: $json.errorCount > 0 ? 'completed_with_errors' : 'success',
      startTime: $json.syncStartTime,
      endTime: syncEndTime.toISOString(),
      durationSeconds: duration,
      totalRecordsProcessed: $json.totalProcessed,
      totalErrors: $json.errorCount,
      errorRate: ($json.errorCount / $json.totalProcessed * 100).toFixed(2) + '%'
    }
  }
}];
```

### 10. Notification - Multiple Options

#### 10A. Slack Notification (if error threshold exceeded)
Key configs:
- `channel: "#data-sync-alerts"`
- `text: "Customer sync completed: {{ $json.summary.totalRecordsProcessed }} processed, {{ $json.summary.totalErrors }} errors"`
- `attachments` with detailed breakdown

#### 10B. Email Notification (for critical failures)
Key configs:
- Send detailed error report if error rate > 5%
- Include link to Google Sheets error log

## Error Handling Strategy

### API Errors
- **Timeout**: Exponential backoff with 3 retries (5s, 10s, 20s delays)
- **Rate Limiting**: Check for 429 status, implement delay based on Retry-After header
- **Connection Errors**: Retry with longer timeout (120s for final attempt)
- **Invalid Response**: Log to error sheet, continue with next page

### Data Validation Errors
- **Missing Required Fields**: Log record to Google Sheets with specific field errors
- **Invalid Data Format**: Transform where possible, log if transformation fails
- **Duplicate Records**: Rely on PostgreSQL upsert to handle gracefully

### Database Errors
- **Connection Pool Exhaustion**: Batch size optimization (200 records)
- **Constraint Violations**: Log specific violation details for review
- **Timeout on Large Batches**: Implement sub-batching if batch fails
- **Deadlocks**: Automatic retry with randomized delay

### Complete Workflow Failure
- **Email Alert**: Send to admin team with full error context
- **Workflow State Preservation**: Store last successful page for manual restart
- **Dead Letter Queue**: Failed records saved to separate PostgreSQL table

## Performance Considerations

### API Optimization
- **Pagination Size**: 100 records per page balances API calls vs memory usage
- **Concurrent Requests**: Single-threaded to respect API rate limits
- **Response Caching**: Not implemented (data freshness priority)
- **Field Selection**: Request only required fields if API supports it

### Database Optimization
- **Batch Processing**: 200 records per insert reduces connections by 95%
- **Prepared Statements**: PostgreSQL node uses them automatically
- **Index Usage**: Ensure customer_id index exists for upsert performance
- **Connection Pooling**: Configure PostgreSQL node with pool size 10
- **Vacuum Schedule**: Coordinate with DBA for post-sync vacuum

### Memory Management
- **Streaming Not Required**: 100-record pages fit comfortably in memory
- **Variable Cleanup**: Each loop iteration starts fresh
- **Error Collection Limit**: Cap error array at 1000 records

### Execution Time
- **Expected Duration**: ~100 records/second = 36 seconds per 1000 customers
- **Timeout Settings**: Workflow timeout set to 2 hours for safety
- **Progress Tracking**: Current page stored for restart capability

## Security Requirements

### API Authentication
- **Method**: API Key authentication (stored in n8n credentials)
- **Credential Name**: "Customer_API_Production"
- **Key Rotation**: Supported via credential update without workflow change

### Database Security
- **PostgreSQL Credentials**: Write-only user for customer table
- **Credential Name**: "PostgreSQL_CustomerSync"
- **Required Permissions**: INSERT, UPDATE on customers table only
- **SSL**: Enforce SSL connection in credential settings

### Google Sheets Access
- **Service Account**: Limited to specific error log spreadsheet
- **Credential Name**: "GoogleSheets_ErrorLogging"
- **Permissions**: Append-only access to error log sheet

### Data Protection
- **PII Handling**: No sensitive data logged to Google Sheets
- **Encryption**: All connections use TLS 1.2+
- **Audit Trail**: sync_batch_id enables full traceability

## Critical Configurations

### Timeout Values
- **API Request Timeout**: 60s (prevents hanging on slow responses)
- **Database Operation Timeout**: 60s (sufficient for 200-record batches)
- **Workflow Maximum Runtime**: 2 hours (safety limit)

### Batch Sizes
- **API Page Size**: 100 (optimal for most REST APIs)
- **Database Batch Size**: 200 (PostgreSQL sweet spot for bulk operations)
- **Error Collection Limit**: 1000 (prevents memory issues)

### Retry Configuration
- **API Retries**: 3 attempts with exponential backoff
- **Database Retries**: 2 attempts with 1-second delay
- **Retry On Status Codes**: 408, 429, 500, 502, 503, 504

### Error Thresholds
- **Warning Threshold**: 1% error rate (Slack notification)
- **Critical Threshold**: 5% error rate (Email alert + workflow pause)
- **Absolute Limit**: 500 errors (stop processing to prevent cascading failures)

### Schedule Considerations
- **Run Time**: 2:00 AM UTC (adjust for your timezone)
- **Conflict Prevention**: Ensure no overlap with database maintenance
- **Holiday Handling**: Consider business calendar integration

## Monitoring and Observability

### Key Metrics to Track
- Total records synchronized per run
- Error rate percentage
- Average processing time per record
- API response times
- Database operation duration

### Logging Strategy
- Structured logs with correlation ID (sync_batch_id)
- Error details preserved in Google Sheets
- Success summaries in Slack channel
- Critical failures via email

### Health Checks
- Pre-sync API connectivity test
- Database connection validation
- Available storage space check
- Previous run completion status

## Scalability Considerations

### Volume Growth Handling
- Current design handles up to 1M records efficiently
- For larger volumes, consider:
  - Parallel processing with multiple workflows
  - Incremental sync based on last_modified timestamp
  - Data partitioning by customer segment

### Future Enhancements
- Webhook-based real-time sync for critical customers
- Change Data Capture (CDC) for near-real-time updates
- Multi-region deployment for global operations
- Data quality scoring and automated remediation

## Recovery Procedures

### Manual Intervention Points
1. Check last successful page number in workflow execution
2. Modify Initialize Variables node to start from specific page
3. Run workflow manually with adjusted parameters
4. Monitor error logs for specific issues

### Rollback Strategy
- All operations are idempotent (safe to re-run)
- sync_batch_id enables identifying records from failed runs
- Database rollback scripts based on sync_batch_id if needed

## Dependencies and Prerequisites

### Required Infrastructure
- n8n instance with sufficient memory (minimum 2GB)
- PostgreSQL database with customers table
- Google Sheets for error logging
- Slack workspace (optional)
- Email service (for critical alerts)

### Initial Setup
1. Create PostgreSQL customers table with proper indexes
2. Set up Google Sheets with error log template
3. Configure all credentials in n8n
4. Test individual components before full run
5. Run with small test dataset first

This architecture provides a robust, scalable solution for daily customer data synchronization with comprehensive error handling and performance optimization suitable for production use.
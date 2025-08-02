# n8n Agent Team Communication Protocol

This document defines the standardized communication protocol for all n8n workflow agents to ensure seamless collaboration and consistent information exchange.

## Agent Communication Standards

### 1. Handoff Protocol

When passing work between agents, use this format:

```yaml
handoff:
  from_agent: [sender_agent_name]
  to_agent: [receiver_agent_name]
  task_id: [unique_identifier]
  context:
    workflow_id: [if applicable]
    workflow_name: [human readable name]
    current_state: [draft|built|deployed|error]
    previous_actions: [list of completed steps]
  task:
    type: [design|build|deploy|debug|enhance]
    description: [clear task description]
    requirements: [specific requirements]
    constraints: [any limitations]
  deliverables:
    expected: [what should be produced]
    format: [architecture|json|status|diagnosis]
  priority: [high|medium|low]
  deadline: [if applicable]
```

### 2. Status Updates

Agents should provide status updates in this format:

```yaml
status_update:
  agent: [agent_name]
  task_id: [unique_identifier]
  status: [in_progress|completed|blocked|failed]
  progress_percentage: [0-100]
  details:
    completed: [what was done]
    current: [what's being worked on]
    next: [what's planned next]
  issues:
    - description: [issue description]
      severity: [critical|high|medium|low]
      resolution: [proposed solution]
  metrics:
    time_elapsed: [in seconds]
    operations_performed: [count]
    success_rate: [percentage]
```

### 3. Error Reporting

When reporting errors, use:

```yaml
error_report:
  agent: [agent_name]
  task_id: [unique_identifier]
  error_type: [timeout|auth|data|config|system]
  severity: [critical|high|medium|low]
  details:
    message: [error message]
    node: [affected node if applicable]
    timestamp: [when it occurred]
    frequency: [once|intermittent|constant]
  diagnosis:
    root_cause: [identified cause]
    impact: [what's affected]
    data_sample: [relevant data if needed]
  recommendation:
    immediate_action: [quick fix]
    long_term_solution: [permanent fix]
    requires_agent: [which agent should handle]
```

### 4. Workflow Metadata

All agents should maintain consistent workflow metadata:

```yaml
workflow_metadata:
  id: [workflow_id]
  name: [workflow_name]
  version: [version_number]
  created_by: [agent_name]
  created_at: [timestamp]
  modified_by: [agent_name]
  modified_at: [timestamp]
  tags:
    - [relevant tags]
  metrics:
    nodes: [count]
    complexity: [simple|moderate|complex]
    integrations: [list of external services]
    estimated_execution_time: [seconds]
  dependencies:
    credentials: [required credentials]
    external_services: [APIs, databases]
    data_sources: [where data comes from]
```

## Shared Data Formats

### 1. Node Configuration Summary

When sharing node information:

```yaml
node_summary:
  id: [node_id]
  type: [node_type]
  name: [display_name]
  configuration:
    key_settings: [only important settings]
    credentials: [credential_name]
    error_handling: [approach]
  connections:
    inputs: [source_nodes]
    outputs: [target_nodes]
  validation_status: [passed|failed|warnings]
```

### 2. Performance Metrics

For performance-related communications:

```yaml
performance_metrics:
  workflow_id: [workflow_id]
  execution_time:
    average: [seconds]
    min: [seconds]
    max: [seconds]
  success_rate: [percentage]
  resource_usage:
    memory: [MB]
    api_calls: [count]
  bottlenecks:
    - node: [node_name]
      issue: [description]
      impact: [seconds or percentage]
```

### 3. Architecture Summary

For architectural designs:

```yaml
architecture_summary:
  pattern: [api|webhook|etl|event-driven|custom]
  components:
    trigger:
      type: [trigger_type]
      configuration: [key settings]
    processing:
      - step: [description]
        nodes: [node_types]
        purpose: [why needed]
    output:
      destination: [where data goes]
      format: [data format]
  error_handling:
    strategy: [approach]
    fallback: [what happens on failure]
  scalability:
    expected_volume: [records/hour]
    limitations: [any constraints]
```

## Agent-Specific Protocols

### Context Manager Protocol
- Must capture all agent interactions
- Provides context in 3 tiers (quick/full/archived)
- Updates memory after each significant change

### Architect Protocol
- Always provides implementation-ready designs
- Includes specific node configurations
- Documents design decisions and rationale

### Builder Protocol
- Validates all configurations before delivery
- Includes comprehensive error handling
- Provides deployment-ready JSON

### Deployer Protocol
- Reports deployment status clearly
- Monitors first 5 executions minimum
- Provides actionable next steps

### Debugger Protocol
- Diagnoses root cause, not just symptoms
- Provides metrics showing improvement
- Documents patterns for future reference

## Collaboration Rules

1. **Context First**: Always check with Context Manager before starting complex tasks
2. **Design Review**: Architect reviews all workflows >20 nodes
3. **Validation Required**: Builder must validate before passing to Deployer
4. **Error Escalation**: Debugger can request Architect for redesign
5. **Learning Loop**: All agents report patterns to Context Manager

## Performance Tracking

Each agent interaction should be tracked:

```yaml
interaction_metric:
  session_id: [unique_session]
  agents_involved: [list]
  total_time: [seconds]
  handoffs: [count]
  success: [boolean]
  workflow_produced: [workflow_id if applicable]
  patterns_identified: [reusable patterns]
```

## Best Practices

1. **Be Explicit**: Never assume context - always provide it
2. **Use Standards**: Follow the formats defined above
3. **Track Everything**: Metrics help improve team performance
4. **Share Patterns**: Successful solutions should be documented
5. **Fail Gracefully**: Always provide next steps on failure

## Version History

- v1.0: Initial protocol establishment
- Last Updated: [Current Date]
- Maintained By: n8n-master-orchestrator

---

All agents must adhere to this protocol to ensure effective team collaboration.
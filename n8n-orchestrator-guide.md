# n8n Master Orchestrator Quick Guide

## 🚀 Quick Start

To use your n8n agent team, invoke the **n8n-master-orchestrator** agent. It will coordinate all other agents automatically.

```
Use agent: n8n-master-orchestrator
```

## 📋 Common Tasks

### Create a New Workflow
```
"I need a workflow that [describe what you want]"
```
The orchestrator will:
1. Use Context Manager to check existing patterns
2. Engage Architect to design the solution
3. Have Builder implement it
4. Deploy via Deployer
5. Store patterns for future use

### Debug a Failing Workflow
```
"My workflow [name/id] is failing with [error]"
```
The orchestrator will:
1. Retrieve context about the workflow
2. Send Debugger to diagnose and fix
3. Redeploy the fixed version
4. Update pattern library

### Enhance an Existing Workflow
```
"Add [feature] to my [workflow name]"
```
The orchestrator will:
1. Load current workflow state
2. Design enhancements with Architect
3. Implement changes via Builder
4. Test with Debugger
5. Deploy updates

## 🤖 Your Agent Team

| Agent | Speciality | When Used |
|-------|------------|-----------|
| **n8n-master-orchestrator** | Team coordination | Always your entry point |
| **n8n-context-manager** | Memory & state | Automatically manages context |
| **n8n-workflow-architect** | Design & planning | Creates blueprints |
| **n8n-workflow-builder** | Implementation | Builds actual workflows |
| **n8n-workflow-deployer** | Production deployment | Deploys & monitors |
| **n8n-workflow-debugger** | Problem solving | Fixes issues |

## 💡 Example Requests

### Simple Automation
```
"Create a workflow that sends a Slack message every morning at 9 AM"
```

### Data Sync
```
"Build a workflow to sync Salesforce contacts to PostgreSQL daily"
```

### Webhook Processing
```
"I need to process Stripe webhooks and update our inventory"
```

### Complex Integration
```
"Design a system that monitors multiple APIs and sends alerts based on conditions"
```

## 📊 What Happens Behind the Scenes

1. **Orchestrator** analyzes your request
2. **Context Manager** provides relevant history
3. **Architect** designs the solution
4. **Builder** implements with best practices
5. **Deployer** puts it into production
6. **Debugger** ensures it runs smoothly
7. **Context Manager** stores learnings

## ✅ Best Practices

1. **Be Specific** - The more details you provide, the better the result
2. **Mention Constraints** - Rate limits, performance needs, error handling
3. **Provide Examples** - Sample data or expected outcomes help
4. **Trust the Process** - Let the orchestrator manage the team

## 🔧 Advanced Usage

### Multi-Workflow Projects
```
"Create a complete customer onboarding system with email automation, CRM updates, and reporting"
```

### Performance Optimization
```
"My workflow takes 45 seconds to run - make it faster"
```

### Migration Projects
```
"Convert my Zapier automation to n8n"
```

## 📈 Performance Metrics

The team tracks:
- **Success Rate**: >90% first-deployment success
- **Speed**: <30 min from request to production
- **Quality**: Comprehensive error handling
- **Learning**: Patterns reused across projects

## 🆘 Troubleshooting

If something isn't working:
1. The orchestrator will automatically engage the debugger
2. You'll receive clear status updates
3. Solutions are applied and tested
4. Patterns are updated to prevent recurrence

## 🎯 Tips for Success

1. **Start Simple** - Test with basic workflows first
2. **Iterate** - Enhance workflows over time
3. **Ask Questions** - The team explains their work
4. **Review Results** - Verify workflows meet your needs

---

Remember: You only need to talk to the **n8n-master-orchestrator**. It handles all team coordination, ensuring your workflows are built right the first time.
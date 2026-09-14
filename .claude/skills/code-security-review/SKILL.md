---
name: code-security-review
description: >
  Performs a comprehensive code security review of the entire codebase against the
  AIRE Security Baseline rules (SECURITY-01 through SECURITY-16). Checks all 16 rules
  covering encryption, logging, security headers, input validation, SSRF, file uploads,
  access control, CSRF, JWT security, network config, credential management, session integrity,
  supply chain, XML/XXE hardening, alerting, error handling, and cryptographic standards.
  Categorizes findings by severity (Critical/Blocker, High, Medium, Low) and generates
  a dated markdown report in reports/code-security-reviews/.
when_to_use: >
  Trigger when the user says: "security review", "security audit", "OWASP scan",
  "find vulnerabilities", "check for security issues", "code security check",
  "security bugs", "secure code review", "run security baseline", "check security rules".
allowed-tools: Read Grep Glob Bash Write
---

# Code Security Review

Load and execute the agent instructions from:

```
aire-workflow/agents/code-security-review-agent.md
```

Read that file completely and follow every step defined in it.

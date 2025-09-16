# CSOC Logging Automation Framework

This repository contains Azure automation scripts, custom policies, and least-privilege role definitions designed to enforce diagnostic logging standards across multiple subscriptions. It supports scalable deployment via management group-level policies and centralized remediation using a single Automation Account.

## Key Features
- PowerShell runbooks for diagnostic enablement and storage firewall configuration
- Custom Azure Policies for blob logging, lifecycle management, and resource auditing
- Least-privilege custom role for automation identity
- Git-structured for onboarding, reuse, and auditability

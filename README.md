\# CSOC Logging Automation Framework



This repository contains Azure automation scripts, policies, and role definitions for enforcing centralized diagnostic logging across multiple subscriptions. Designed for scalable deployment via management group-level policies and a single automation account.



\## Structure

\- `runbooks/`: PowerShell scripts for remediation and network hardening

\- `policies/`: Custom Azure Policy definitions

\- `roles/`: Least-privilege custom role for automation identity

\- `templates/`: ARM templates used in policy deployments

\- `docs/`: Architecture, onboarding, and naming standards




Working Agreement:
Clinic Copilot Project
1. Purpose

This Working Agreement defines how the Clinic Copilot team collaborates, develops, reviews, and delivers work.
The goal is to ensure:

Clear ownership

Predictable delivery

High code quality

Smooth onboarding for new contributors

This agreement applies to all team members working on the Clinic Copilot repository.

2. Team Members & Roles
Name	Primary Focus	Responsibilities
Jawad	Tech Lead / Backend & AI Orchestration	Architecture, Spring Boot, Spring AI, schema validation, final reviews
Arafath	AI Engineer	MedASR integration, audio processing, diarization
Hasnath	AI Engineer	MedGemma prompts, JSON compliance, guardrails

All team members are encouraged to understand the full system, but ownership areas help reduce overlap and conflicts.

3. Communication & Standups
Daily Standup
Frequency: Daily (or per working day during sprint)
Duration: 10–15 minutes
Format:
What I worked on yesterday
What I will work on today
Any blockers

Asynchronous Updates
Jira ticket comments are the source of truth
GitHub Pull Requests are used for technical discussions

4. Sprint & Jira Process
Sprint Length
1–2 weeks (Sprint 1 = foundation sprint)
Jira Rules
Every piece of work must have a Jira ticket
One ticket = one feature branch

Tickets must include:
Description
Acceptance criteria
Definition of Done

5. Git & Branching Strategy
Branch Types
Branch	Purpose
main	Stable, production-ready, demo-ready code
develop	Active sprint integration branch
feature/*	Individual ticket work
Branch Naming Convention
feature/<JIRA-ID>-short-description


Examples:

feature/E1-medasr-transcription
feature/E2-soap-schema-v1

6. Commit Message Guidelines
Format
<JIRA-ID>: Short, clear description


Examples:

E1: Implement MedASR transcription endpoint
E2: Add strict JSON schema validation for SOAP

Rules

Commits should be small and focused
Avoid “WIP” commits on shared branches

7. Pull Request (PR) Process
When to Open a PR
Ticket work is complete
Code compiles / runs locally
Acceptance criteria are met
PR Target
All feature branches → develop
develop → main only at sprint/milestone completion

PR Checklist

 Code builds successfully

 No hardcoded secrets or PHI

 Logging is PHI-safe

 JSON schemas validated (if applicable)

 Jira ticket linked in PR title or description

Reviews

At least 1 approval required

Tech Lead has final merge responsibility

8. Definition of Done (DoD)

A Jira ticket is considered Done when:

Code is merged into develop

Acceptance criteria are met

No breaking changes introduced

Relevant documentation updated (if required)

Basic testing performed (manual or automated)

9. Coding & Quality Standards
General

Follow existing project structure

Prefer clarity over cleverness

Write readable, maintainable code

AI-Specific

No free-text AI outputs in production paths

All AI outputs must be structured (JSON)

Missing information must be flagged, not inferred

Evidence citation required where applicable

10. Security & Privacy Guidelines

Never commit real patient data (PHI)

Use mock/sample data only

Avoid logging transcripts by default

Follow offline-first assumptions

Treat all AI outputs as drafts

11. Documentation Expectations

Major design changes require an ADR

API changes must update API_CONTRACTS.md

Schema changes must update JSON_SCHEMA_V1.md

HLD/LLD updates required for architectural changes

12. Conflict Resolution

Raise concerns early in standup or PR

Discuss technical disagreements with data and trade-offs

Tech Lead makes final decision if consensus is not reached

13. Continuous Improvement

This Working Agreement is a living document.

Suggestions for improvement are welcome

Changes require team discussion and agreement

14. Acknowledgement

By contributing to this repository, all team members agree to follow this Working Agreement to maintain a professional, respectful, and high-quality engineering environment.


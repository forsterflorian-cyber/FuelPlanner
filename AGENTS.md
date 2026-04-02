\# AGENTS.md - Garmin / Connect IQ Projects



\## Project context



This repository contains a Garmin Connect IQ app, data field, widget, or watch app. Priorities are stability, correctness, low memory pressure, low allocation behavior in hot paths, clear lifecycle handling, and practical on-device usability.



Do not add new features unless explicitly requested.



\## Core rules



\- Stability and device safety come first.

\- Optimize for correctness under real device lifecycle conditions:

&#x20; - start

&#x20; - pause

&#x20; - resume

&#x20; - lap

&#x20; - app reload

&#x20; - sensor gaps

&#x20; - invalid data

\- Keep runtime allocations low, especially in hot paths and draw/update loops.

\- Prefer simple, robust logic over elegant but fragile abstractions.



\## Device and performance rules



\- Default main validation target is FR955 unless another device is explicitly requested.

\- Consider compatibility with somewhat older supported Garmin devices when possible, but do not distort the architecture just to support very old devices.

\- Be alert to memory limits, font/resource size issues, and argument-count/platform quirks on older devices.

\- Avoid unnecessary object churn inside update, compute, or draw paths.



\## Connect IQ implementation rules



\- Respect Connect IQ lifecycle and Toybox constraints.

\- Treat background services, temporal events, glance/widget/update timing, and app state restoration as risk areas.

\- Do not assume simulator behavior always equals device behavior.

\- Distinguish clearly between:

&#x20; - compile success

&#x20; - simulator success

&#x20; - on-device validation



\## UX rules



\- UI must remain readable on target screens.

\- Favor resolution-relative layout where possible.

\- Avoid fixed pixel assumptions unless device-specific by design.

\- Ensure states are understandable on-watch:

&#x20; - loading

&#x20; - waiting

&#x20; - invalid

&#x20; - provisional

&#x20; - active

&#x20; - paused

\- Compact clarity is more important than visual ornament.



\## Validation rules



\- After changes, state separately:

&#x20; - compile status

&#x20; - simulator status

&#x20; - device validation status

\- Never imply on-device validation if it did not happen.

\- If a behavior is inferred rather than observed, say so.



\## Review focus



When reviewing code, prioritize:

1\. lifecycle correctness

2\. memory and allocation behavior

3\. stale state / cache invalidation risks

4\. simulator vs device mismatch risk

5\. readability and usefulness of on-watch UI



\## Preferred response style



\- Be exact and implementation-oriented.

\- Explain runtime behavior in operational terms.

\- When diagnosing, separate:

&#x20; - root cause

&#x20; - trigger path

&#x20; - observed effect

&#x20; - fix

&#x20; - remaining uncertainty

\- Avoid broad refactors unless the current structure is the cause of instability.


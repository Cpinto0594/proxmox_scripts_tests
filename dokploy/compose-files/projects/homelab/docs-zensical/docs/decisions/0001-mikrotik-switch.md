# 0001 — MikroTik CRS310 as core switch
**Date:** TODO · **Status:** Accepted

## Context
Needed managed switching with VLANs and 2.5G for the nodes and NAS.

## Options considered
TRENDnet TEG-3102WS (bought first), MikroTik CRS310-8G+2S+IN, others researched.

## Decision
MikroTik CRS310-8G+2S+IN. The TRENDnet arrived defective.

## Consequences
Inter-VLAN routing handled on the MikroTik. RouterOS config should be exported to this repo.

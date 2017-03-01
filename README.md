AWS Edge Cases
==============

A repo of tests against edge cases in AWS.  Meant to be used alongside [aws-forensics](github.com/witoff/aws-forensics).

## Utils

### 1. Escalation via Versioned Policies

1. Hide administrative access in an older version of a managed policy
2. Launch a lambda function that will escalate and exfil keys when a certain
condition is met.

### 2. (In Progress)

Other edge cases under development!

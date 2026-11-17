# Owned command timeout cleanup

Prerequisite for #52/#55/#57: killing only the outer process group leaves nested
Foundation `Process` groups running. A synthetic compiled Swift supervisor proved
the sleeping child remained active after the original timeout.

`OwnedProcessTree` freezes each parent before enumerating its children, checks
PID ancestry and start-time identity, terminates descendants before parents and
boundedly confirms absent/zombie states. Foundation reaps the direct child; an
unrelated grandchild cannot be reaped with `waitpid`. No process names, commands
or system-wide process listing are collected. No negative group signal is used.

SW-05 scoped interoperability: synchronous libproc calls use lifetime-scoped
typed buffers, validate sizes/counts and bound enumeration/cleanup. These SDK
interfaces are tool-only, not shipping app integrations; unknown/denied states
throw `CommandCleanupFailure`, never a successful cleanup result. See Apple's
[libproc implementation](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.c)
for the child-list PID-count contract. This is supervision of structured owned
commands, not containment of hostile daemons that deliberately abandon ancestry.

Callers must retain a workspace when cleanup is uncertain, rather than delete
files under potentially active processes. Fault probes, manifest inspection and
authority checks use the temporary workspace's retention wrapper. TestGate keeps
diagnostics and records `cleanup_uncertain`; the native runner keeps derived data
when a command throws. The forthcoming push gate will retain failed verification
attempts. CPU/latency warning budgets are unchanged.

The regression fixture records its child's start identity before a timeout or
supervisor exit; cleanup cannot signal a recycled PID. The first 3-second run
reproduced the old leak. A later fixture failed to become ready and was not counted
as a successful cleanup measurement; the bounded regression now allows 10 seconds
for startup/work and requires the actual child/group marker. No UI/performance
budget was relaxed. Separate tests cover an exited supervisor, preserved failure
diagnostics and mismatched process identities. Full checks/CI are recorded in the PR.

# Performance evidence

Define the user-visible workload and metric before optimization: latency distribution, frame responsiveness, throughput, peak memory, CPU, energy or I/O as appropriate. State the supported environment, data size and accepted budget; an absent budget is a decision to obtain, not a number to invent.

Record baseline and candidate revisions under comparable hardware, build mode, fixtures and instrumentation. Separate cold/warm paths, allow appropriate warmup, repeat measurements and report sample size, spread and competing system load. Do not claim a percentage improvement from one run or compare a debug baseline with a release candidate. Profiling identifies where time/resources go; a benchmark alone does not explain the cause.

Exercise correctness alongside performance so dropped work, stale output, hidden errors or skipped authorization cannot count as speedups. For asynchronous applications include cancellation and bounded growth over time. Use load/soak work only when its resource effects and target are authorized; never generate production load by default. Retain enough sanitized commands, configuration and results to reproduce the comparison.

Report measured change, uncertainty, tradeoffs and remaining bottlenecks. Distinguish measured regression from noise and proposed budget from enforced gate. A smaller source diff, lower token use or more merged PRs does not establish faster software.

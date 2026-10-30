# Closed-popover footprint baseline

## Follow-up measurement on 2026-10-30

Measured the temporary Release build above, outside the debugger, PID 14266.
The user confirmed the popover closed, then manually opened it for a delayed
short capture. Desktop automation timed out; visibility is user-controlled,
not independently verified. Other normal desktop workloads remained running.
The planned five-minute open capture was shortened at the user’s request to
avoid blocking normal computer use. Successful quota display was not confirmed.

Method: Python orchestration of system `ps -axo pid=,ppid=,time=,rss=,comm=`
every approximately 250 ms; retain only app and direct-child records. CPU is
the difference in cumulative app CPU seconds divided by wall seconds, multiplied
by 100 (one fully occupied core = 100%). `ps` CPU time has 0.01-second
resolution. RSS is KiB. Sampling itself adds system load and can miss short
child peaks. Raw captures and collector are in
`/private/tmp/codex-meter-baseline/` (temporary storage).

| Condition | Duration | App CPU | App RSS |
| --- | ---: | ---: | ---: |
| Closed, after an additional two-minute warmup | 299.92 s / 1,181 records | 0.654% overall | 95.89–96.06 MiB |
| Closed, excluding observed child activity plus two seconds on each side | 275.08 s | 0.611% | same capture |
| Open, short comparison | 14.96 s / 60 records | 0.668% | 96.30–96.39 MiB |

Closed capture Unix timestamps: 1793358990.497–1793359290.418.
Open capture: 1793359917.647–1793359932.611. Open collection began after a
20-second delay for the user to open the popover; no child was observed.
Five children were observed during the closed capture (PIDs 14595, 14856,
15117, 15392, 15647), consistent with the 60-second cadence. Their observed
first-to-last spans were 0.76–1.01 seconds (not exact lifetimes), sampled
maximum RSS ranged 82.44–89.94 MiB, and last observed cumulative CPU times
were 0.33–0.38 seconds (lower bounds on total CPU). No child physical footprint
or reliable simultaneous physical-memory peak was collected.

A separate post-closed `footprint` snapshot reported 24,085,368 bytes
(22.97 MiB) physical footprint, lifetime peak 28,525,432 bytes (27.20 MiB).
These are distinct from RSS and from the process sampling window.
`closed-footprint.txt` retains the output. A separate ten-second, 10 ms stack
capture is `closed-sample.txt`; most main-thread samples wait for events,
with some NSHostingView.layout / ViewGraph update / AttributeGraph work.
These wall-clock stack samples do not establish CPU attribution or prove a
particular timer or renderer is responsible. No open-state stack capture was
collected. The earlier initial sample was before controlled warmup.

A final closed-return capture (`closed-return.jsonl`) recorded 29.96 seconds
without an observed child, averaging 0.634% CPU. This is consistent with the
earlier closed baseline. The temporary build was stopped and the installed app
restored and verified as PID 16227.

The physical footprint snapshot is below 50 MB, but idle CPU remains above
0.1%. The short open comparison provides no convincing visibility effect;
it cannot characterize minute-scale open refresh behavior. Investigate
recurring hidden UI work next, using timer/render counters or a focused trace,
before keeping an optimization. Item 1 remains partially complete because the
open comparison is short and attribution and child memory remain incomplete.
No production code or polling cadence changed.

## Earlier attempt on 2026-10-30 (incomplete)

No controlled comparison was collected in this attempt; item 1 remains open.
The old numbers in `TODO.md` remain uncontrolled and are not a substitute for
this capture.

The environment was macOS 27.2 (26B123), arm64, Xcode 27.1 (27A9275), Codex
CLI 0.166.0, AC power, and commit `bdcb24c378df709f2f6328eb5bd2390c5a07b1fd`.
The working tree had pre-existing changes to `.gitignore` and this untracked
document. A Release build succeeded outside the sandbox with the command below;
Xcode reported an unrelated out-of-date CoreSimulator service. The executable
and matching dSYM are under `/private/tmp/codex-meter-footprint-build/Build/Products/Release/`
(dSYM UUID `A7B89440-2BBF-3680-B5CA-48300D6CFE29`, arm64). These temporary
artifacts may be removed by the system and should be rebuilt for a later run.

```sh
xcodebuild -project CodexMeter/CodexMeter.xcodeproj -scheme CodexMeter \
  -configuration Release -derivedDataPath /private/tmp/codex-meter-footprint-build build
```

The sandboxed build failed because the Swift macro plugin returned malformed
responses, and sandboxed process enumeration returned `Operation not permitted`.
The failed build log is at `/private/tmp/codex-meter-footprint-build.log`.
An unsandboxed build succeeded. Process enumeration identified an existing
`~/Applications/CodexMeter.app` instance. After a first overlapping launch, it
was stopped temporarily and the Release instance launched alone at 11:55:22
local time (PID 13630). UI automation timed out selecting both CodexMeter and
SystemUIServer, so popover visibility and successful quota loading could not be
verified and the planned open/closed comparison was not possible. The temporary
instance was stopped and the original installed app relaunched and verified as
PID 13689.

Exploratory readings, not a warmed-up baseline: at approximately 11:55:37,
`ps -p 13630 -o pid,ppid,%cpu,rss,etime,command` reported 0.0% CPU and
84,992 KiB RSS at 15 seconds elapsed. A separate `footprint 13630` reported
16 MB physical footprint and 21 MB peak; these are rounded tool output, not
simultaneous with the `ps` reading. A ten-second `sample 13630 10 10` starting
at 11:56:01 recorded 907 samples per thread, with the main and event threads
waiting in `mach_msg2_trap` and two worker threads in `__workq_kernreturn`.
The raw stack capture is `/private/tmp/codex-meter-baseline-sample.txt` (temporary
storage); its own physical footprint reading was 16.1 MB. It does not establish
CPU usage or rule out periodic work, and profiler overhead is distinct from
lightweight measurements. No child, refresh timing, CPU distribution, or
simultaneous peak was captured. Visibility, workload, and warmup were uncontrolled.

A controlled run needs access to the menu bar to verify and change visibility,
then the five-minute lightweight captures and separate stack captures described
below. No conclusions about the idle target or rendering causes can be drawn
from these exploratory readings.

This is a measurement plan for item 1 in `TODO.md`. Its purpose is to locate
recurring work and establish a comparison point before changing rendering or
polling. The existing 96–98 MiB app RSS and ~1.2% CPU sample did not control
popover visibility and should not be treated as a closed-popover baseline.

## Setup

- Record the date, Mac and chip, macOS and Xcode versions, app commit and build
  configuration, Codex CLI version, power source, and profiling tool versions.
- Run one app instance using an existing Codex login. Record whether usage loads
  successfully, any error state, relevant display/appearance settings, and the
  polling cadence. Avoid logging credentials or raw account responses.
- Quit other unusually active workloads where practical. Record anything that
  cannot be controlled. Keep the same build, machine, settings, and workload for
  later comparisons.
- Launch the app, close the popover, and allow several minutes for startup and
  at least two 60-second refreshes to settle. Identify the app PID and observe
  its short-lived Codex child separately; the child PID may change each poll.

## Capture

1. With the popover closed, record at least five minutes of app CPU and memory,
   including several refresh cycles. Use Instruments (Time Profiler and a
   memory/footprint instrument) or suitable system tools. Note sampling interval
   and how CPU percentages are defined. Mark refresh and child-process activity.
2. Open the popover and repeat for at least five minutes under otherwise similar
   conditions. Leave it open without interacting. Record visible countdown and
   other time-dependent UI activity.
3. For each condition, report app CPU between refreshes separately from CPU
   during refreshes. Capture the child’s CPU, lifetime, and peak memory per
   observed launch, plus a combined peak if the tool can measure it reliably.
   Report app RSS and physical footprint separately, with units and ranges or
   summary statistics. Do not add independently observed peaks as if simultaneous.
4. Capture representative app stacks during recurring between-refresh CPU
   activity in each condition. Use Time Profiler or repeated `sample` captures;
   note capture duration and whether a refresh overlapped. Identify recurring
   call paths and their approximate contribution, without treating correlation
   as proof of a cause.
5. Repeat a short closed-popover capture after closing the popover again. This
   helps distinguish a visibility effect from warmup or measurement drift.

## Record and decide

Save the time windows, raw capture locations, methods, and observations together
with a concise closed/open comparison. Note process IDs, refresh timings, sample
counts, uncertainties, and any failed or incomplete measurements. Compare idle
CPU and memory with the targets in `AGENTS.md`, stating the metric and conditions
rather than claiming the targets are met from RSS alone.

Use the stacks to choose the next investigation: for example, inspect the footer
timer if its work persists while hidden, or count image renders if rendering is a
recurring contributor. If no clear call path emerges, collect a longer or more
representative profile before changing code. This baseline does not itself alter
the app or its 60-second polling cadence.

## Visibility-aware timeline experiment

Release build in `/private/tmp/codex-meter-cpu-build`, PID 16602, same machine
and settings. All three popover TimelineViews now emit no scheduled dates while
the actual panel window is hidden/occluded. AppKit occlusion notifications are
observed with a cancellable main-actor async task. Visible cadence stays 1s
for the footer and 60s for status/expiry; provider polling is unchanged.

After 60 seconds of warmup, `paused-closed.jsonl` captured 119.915 seconds:
0.0751% overall CPU, 0.0358% between refreshes over 111.798 seconds using the
same observed-child +/-2s exclusion. RSS ranged 84,672–84,944 KiB. This compares
with 0.6107% idle in the earlier 299.92-second capture (about 94% lower), but
the follow-up window is shorter. Existing tests finished during warmup before
measurement began. A separate `paused-footprint.txt` snapshot reports
17,023,840 bytes physical footprint (16.24 MiB), lifetime peak 21,545,824 bytes.
These memory readings have different process histories, so they do not prove
a memory saving. A separate stack capture is `paused-sample.txt`.

Release build and existing Xcode test suite passed; the build still reports
the pre-existing AppServerProvider actor-isolation and simulator-version warnings.
The user verified the visible footer advances. After closing,
`paused-after-open.jsonl` recorded 64.792 seconds at 0.0772% overall CPU.
The 59.709 seconds outside observed child activity +/-2s had no measurable
CPU-time increase at ps’s 0.01-second resolution (not proof of zero work).
This checks that pausing resumes after an open/close cycle.

The verified Release build was installed into ~/Applications/CodexMeter.app
and relaunched. The prior installed bundle is backed up at
`/private/tmp/codex-meter-before-cpu-fix.app` (temporary storage).
TODO item 2 is complete; no rendering cache or transport changes were needed.

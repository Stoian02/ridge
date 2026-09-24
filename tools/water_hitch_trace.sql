-- Matched intervals from the all-cars diagnostic, 2026-09-24.
-- Input: runs/m6w-review-data/all-cars.pftrace.gz (decompress first).
-- Full trace is local-only (40 MiB compressed); raw CSVs/SQL output are committed.
-- VkThread tid 1195, utid 7758 in this trace. Do not reuse IDs for another run.
-- Clock anchors: REALTIME minus BOOTTIME = 1789885938447045119 ns.
-- Across all 323 clock snapshots this offset varies by only 417 ns.
-- GDScript per-case anchors from logcat and each frame/tick's end_usec yield
-- the intervals below; JSON clock print precision is about 10 microseconds.

SELECT name,value FROM stats WHERE severity != 'info' AND value > 0;
SELECT COUNT(*) snapshots, MAX(clock_value-ts)-MIN(clock_value-ts) offset_spread_ns
FROM clock_snapshot WHERE clock_name='REALTIME';

WITH windows(label,a,b) AS (VALUES
 ('4x4_frame',370422486102881,370422524705881),
 ('rally_frame',370371801022881,370371834823881),
 ('4x4_slow_tick',370422508801881,370422519219881))
SELECT label,state,ROUND(SUM(MIN(ts+dur,b)-MAX(ts,a))/1e6,3) ms,COUNT(*) spans
FROM windows JOIN thread_state ON ts < b AND ts+dur > a
WHERE utid=7758 GROUP BY label,state;

-- Competing CPU work across each whole-frame interval; this is not a statement
-- that every listed process directly displaced the game on its particular CPU.
WITH windows(label,a,b) AS (VALUES
 ('4x4',370422486102881,370422524705881),
 ('rally',370371801022881,370371834823881)), ranked AS (
 SELECT label,t.name,p.name AS process,s.cpu,s.priority,
 ROUND(SUM(MIN(s.ts+s.dur,b)-MAX(s.ts,a))/1e6,3) ms
 FROM windows JOIN sched s ON s.ts < b AND s.ts+s.dur > a
 JOIN thread t USING(utid) LEFT JOIN process p USING(upid)
 WHERE t.tid != 0 GROUP BY label,t.utid,s.cpu,s.priority)
SELECT * FROM ranked ORDER BY label,ms DESC;

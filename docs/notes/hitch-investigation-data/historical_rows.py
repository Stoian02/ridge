#!/usr/bin/env python3
"""Extract the named historical cases directly from immutable evidence archives.

Run from the repository root. No game/device access or file mutation. The M6A
format records per-frame controller sums but cannot associate individual ticks
to exact process frames; leave that limitation explicit instead of guessing.
"""
import csv
import io
import json
import tarfile


CASES = [
    ("docs/notes/m6a-query-fix-data/phone-course.tar.gz", "1_offroad_4x4_current"),
    ("docs/notes/m6w-completion-data/final-matrix.tar.gz",
     "final_matrix/wave_acceptance_results/final_matrix/rally_r0_o1_m1"),
    ("docs/notes/m6w-completion-data/final-stress-and-lifecycle.tar.gz",
     "final_stress/wave_acceptance_results/final_stress/offroad_4x4_r1_o1_m3"),
    ("docs/notes/m6w-completion-data/final-live.tar.gz",
     "final_live/wave_acceptance_results/final_live/offroad_4x4_r0_o1_m1"),
]


def samples(archive, name):
    return [{key: float(value) for key, value in row.items()}
            for row in csv.DictReader(io.TextIOWrapper(archive.extractfile(name)))]


def main():
    output = []
    for archive_path, case in CASES:
        with tarfile.open(archive_path) as archive:
            frames = samples(archive, case + "_frames.csv")
            assert all(b["process_frame"] == a["process_frame"] + 1
                       for a, b in zip(frames, frames[1:])), "non-consecutive frames"
            tails = [frame for frame in frames if frame["frame_usec"] > 33300]
            matching = []
            if archive_path != CASES[0][0]:
                ids = {frame["process_frame"] for frame in tails}
                matching = [tick for tick in samples(archive, case + "_ticks.csv")
                            if tick["process_frame"] in ids]
                for frame in tails:
                    ticks = [tick for tick in matching if tick["process_frame"] == frame["process_frame"]]
                    assert len(ticks) == frame["physics_ticks"]
                    for component in ("controller", "runtime", "emitter", "coordinator", "wave_query"):
                        key = component + "_usec"
                        assert sum(tick[key] for tick in ticks) == frame[key]
                    assert sum(frame[key + "_usec"] for key in
                               ("controller", "runtime", "emitter", "coordinator", "effects_upper",
                                "audio_upper", "hud", "flat")) == frame["total_upper_usec"]
            output.append({"archive": archive_path, "case": case,
                           "long_frames": tails, "matching_ticks": matching,
                           "individual_tick_association_available": archive_path != CASES[0][0]})
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()

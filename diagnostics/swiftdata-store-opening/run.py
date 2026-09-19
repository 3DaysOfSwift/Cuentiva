#!/usr/bin/env python3
"""Run bounded, fresh-process SwiftData diagnostics; clean stores even after a crash."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["parallel", "serial"], default="parallel")
    parser.add_argument("--rounds", type=int, default=20)
    parser.add_argument("--stores", type=int, default=32)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 100 or not 1 <= args.stores <= 128:
        parser.error("rounds must be 1–100; stores must be 1–128")

    output = Path(tempfile.mkdtemp(prefix="cuentiva-store-opening-"))
    executable = output / "StoreOpeningRepro"
    source = Path(__file__).with_name("StoreOpeningRepro.swift")
    command = ["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
               "-module-cache-path", str(output / "modules"),
               "-Xfrontend", "-disable-sandbox", str(source), "-o", str(executable)]
    compiled = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (output / "compile.log").write_text(compiled.stdout + compiled.stderr)
    print(f"Logs: {output}", flush=True)
    if compiled.returncode:
        raise SystemExit(compiled.returncode)

    results = []
    for index in range(1, args.rounds + 1):
        # The parent removes only its own temporary directory after the child exits.
        with tempfile.TemporaryDirectory(prefix="cuentiva-repro-stores-") as stores:
            try:
                run = subprocess.run([str(executable), args.mode, stores, str(args.stores)],
                                     capture_output=True, text=True, timeout=30)
                code, log = run.returncode, run.stdout + run.stderr
            except subprocess.TimeoutExpired as error:
                code, log = 124, f"Timed out after {error.timeout} seconds."
            (output / f"run-{index}.log").write_text(log)
            results.append(code)
            print(f"{args.mode} run {index}: exit {code}", flush=True)
        if code:
            # One crash is sufficient evidence; avoid flooding system crash reports.
            break
    (output / "results.json").write_text(json.dumps({
        "mode": args.mode, "stores_per_run": args.stores,
        "requested_rounds": args.rounds, "exit_codes": results
    }, indent=2) + "\n")
    raise SystemExit(0 if all(code == 0 for code in results) else 1)


if __name__ == "__main__":
    main()

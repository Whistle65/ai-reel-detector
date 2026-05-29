"""Phase 1 accuracy test: run against 20 AI + 20 real Reels.

Usage:
    pip install -r requirements.txt
    HIVE_API_KEY=xxx python test_pipeline.py

Expected: >80% accuracy
"""

import asyncio
import csv
import sys
from pathlib import Path

from analyzer import analyze_reel

# Populate these with real Reel CDN URLs or Instagram page URLs.
# Label: 1 = AI-generated, 0 = real
TEST_SET = [
    # (url, label)
    # AI-generated examples:
    # ("https://www.instagram.com/reel/...", 1),
    # Real examples:
    # ("https://www.instagram.com/reel/...", 0),
]


async def run_tests():
    if not TEST_SET:
        print("ERROR: Fill in TEST_SET with reel URLs before running.")
        sys.exit(1)

    results = []
    for i, (url, label) in enumerate(TEST_SET):
        print(f"[{i+1}/{len(TEST_SET)}] Analyzing… ", end="", flush=True)
        try:
            result = await analyze_reel(url)
            predicted = 1 if result["is_ai"] else 0
            correct = predicted == label
            results.append({
                "url": url[:60],
                "label": label,
                "predicted": predicted,
                "confidence": result["confidence"],
                "correct": correct,
            })
            print(f"conf={result['confidence']:.3f} {'✓' if correct else '✗'}")
        except Exception as e:
            print(f"ERROR: {e}")
            results.append({"url": url[:60], "label": label, "error": str(e), "correct": False})

    correct = sum(1 for r in results if r.get("correct"))
    accuracy = correct / len(results) * 100
    print(f"\nAccuracy: {correct}/{len(results)} = {accuracy:.1f}%")

    out = Path("test_results.csv")
    with open(out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["url", "label", "predicted", "confidence", "correct", "error"])
        writer.writeheader()
        writer.writerows(results)
    print(f"Results written to {out}")

    if accuracy < 80:
        print("WARNING: accuracy below 80% target")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_tests())

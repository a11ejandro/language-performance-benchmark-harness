from math import ceil, sqrt
from typing import List, Dict


def calculate(samples: List[float]) -> Dict[str, float]:
    if not samples:
        return {
            "min": None,
            "max": None,
            "mean": None,
            "median": None,
            "q1": None,
            "q3": None,
            "standard_deviation": None,
        }

    s = sorted(float(x) for x in samples)
    n = len(s)
    min_v = s[0]
    max_v = s[-1]
    mean_v = sum(s) / n

    if n % 2 == 1:
        median_v = s[n // 2]
    else:
        median_v = (s[n // 2 - 1] + s[n // 2]) / 2.0

    def idx(f: float) -> int:
        i = int(ceil(f) - 1)
        if i < 0:
            i = 0
        if i >= n:
            i = n - 1
        return i

    q1_v = s[idx(n / 4.0)]
    q3_v = s[idx(3 * n / 4.0)]

    variance = sum((x - mean_v) ** 2 for x in s) / float(n)
    std_v = sqrt(variance)

    return {
        "min": float(min_v),
        "max": float(max_v),
        "mean": float(mean_v),
        "median": float(median_v),
        "q1": float(q1_v),
        "q3": float(q3_v),
        "standard_deviation": float(std_v),
    }


import os
from pathlib import Path
from dotenv import load_dotenv


def load():
    here = Path(__file__).resolve().parent
    # Load Rails app .env first, then local overrides
    load_dotenv(here.parent.parent / "benchmark_ui" / ".env")
    load_dotenv(here.parent / ".env")


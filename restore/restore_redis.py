"""
restore_redis.py -- Restore Redis keys from a backup JSON file.

Usage:
    python restore_redis.py --backup redis-2026-03-17.json
    python restore_redis.py --backup redis-2026-03-17.json --host localhost --port 6379

The backup file is produced by the nightly-env-backup Claude scheduled task.
"""

import argparse
import json
import sys

try:
    import redis
except ImportError:
    print("ERROR: redis not installed. Run: pip install redis")
    sys.exit(1)


def restore(backup_path: str, host: str, port: int):
    with open(backup_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    r = redis.Redis(host=host, port=port, decode_responses=True)

    try:
        r.ping()
    except Exception as e:
        print(f"ERROR: Cannot connect to Redis at {host}:{port} -- {e}")
        sys.exit(1)

    print(f"Connected to Redis at {host}:{port}")
    print(f"Restoring {len(data)} keys...")

    restored = 0
    skipped = 0

    for key, value in data.items():
        try:
            if isinstance(value, str):
                r.set(key, value)
            elif isinstance(value, (dict, list)):
                r.set(key, json.dumps(value))
            else:
                r.set(key, str(value))
            restored += 1
        except Exception as e:
            print(f"  WARN: Could not restore key '{key}': {e}")
            skipped += 1

    print(f"\nRestored: {restored} keys")
    if skipped:
        print(f"Skipped:  {skipped} keys (see warnings above)")
    print("Redis restore complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Restore Redis from backup")
    parser.add_argument("--backup", required=True, help="Path to redis backup JSON file")
    parser.add_argument("--host", default="localhost", help="Redis host")
    parser.add_argument("--port", type=int, default=6379, help="Redis port")
    args = parser.parse_args()
    restore(args.backup, args.host, args.port)

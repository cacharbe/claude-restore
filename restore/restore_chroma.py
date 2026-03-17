"""
restore_chroma.py -- Restore ChromaDB collections from a backup JSON file.

Usage:
    python restore_chroma.py --backup chroma-2026-03-17.json --host http://localhost:8000

The backup file is produced by the nightly-env-backup Claude scheduled task.
"""

import argparse
import json
import sys

try:
    import chromadb
except ImportError:
    print("ERROR: chromadb not installed. Run: pip install chromadb")
    sys.exit(1)


def restore(backup_path: str, host: str):
    with open(backup_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Parse host/port from URL
    host_clean = host.rstrip("/")
    if ":" in host_clean.split("//")[-1]:
        parts = host_clean.split("//")[-1].split(":")
        chroma_host = parts[0]
        chroma_port = int(parts[1])
    else:
        chroma_host = host_clean.split("//")[-1]
        chroma_port = 8000

    client = chromadb.HttpClient(host=chroma_host, port=chroma_port)

    for collection_name, collection_data in data.items():
        print(f"  Restoring collection: {collection_name}")
        docs = collection_data.get("documents", {})

        # Get or create the collection
        try:
            collection = client.get_collection(name=collection_name)
            print(f"    Collection exists -- adding/updating documents")
        except Exception:
            collection = client.create_collection(name=collection_name)
            print(f"    Created new collection")

        # Extract documents, embeddings, metadatas, ids
        ids = docs.get("ids", [])
        documents = docs.get("documents", [])
        metadatas = docs.get("metadatas", [])

        if not ids:
            print(f"    No documents to restore")
            continue

        # Upsert in batches of 100
        batch_size = 100
        for i in range(0, len(ids), batch_size):
            batch_ids = ids[i:i+batch_size]
            batch_docs = documents[i:i+batch_size] if documents else None
            batch_meta = metadatas[i:i+batch_size] if metadatas else None

            kwargs = {"ids": batch_ids}
            if batch_docs:
                kwargs["documents"] = batch_docs
            if batch_meta:
                kwargs["metadatas"] = batch_meta

            collection.upsert(**kwargs)

        print(f"    Restored {len(ids)} documents")

    print(f"\nChromaDB restore complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Restore ChromaDB from backup")
    parser.add_argument("--backup", required=True, help="Path to chroma backup JSON file")
    parser.add_argument("--host", default="http://localhost:8000", help="ChromaDB host URL")
    args = parser.parse_args()
    restore(args.backup, args.host)

#!/bin/bash
set -e

MONGO_URI="mongodb://root:root-password@localhost:27017/rag_demo?authSource=admin&directConnection=true"

echo "Ensuring rag_demo.documents collection exists..."

mongosh "$MONGO_URI" --quiet --eval '
try {
  db.createCollection("documents");
  print("Created collection: documents");
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print("Collection already exists: documents");
  } else {
    throw e;
  }
}
'

echo "Waiting for MongoDB Search commands to become available..."

for i in {1..30}; do
  if mongosh "$MONGO_URI" --quiet --eval 'db.runCommand({ listSearchIndexes: "documents" }).ok' | grep -q 1; then
    echo "Search commands are enabled."
    exit 0
  fi

  echo "Search not ready yet... attempt $i/30"
  sleep 2
done

echo "Search commands did not become available in time."
exit 1

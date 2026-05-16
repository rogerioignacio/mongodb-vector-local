# MongoDB Community 8.3 + Community Search / mongot + Local Voyage 4 Nano

This project runs a fully local development stack for:

- MongoDB Community Server 8.3.2
- MongoDB Community Search / `mongot`
- Single-node replica set: `rs0`
- MongoDB `$vectorSearch`
- MongoDB `$search`
- Local embeddings using `voyageai/voyage-4-nano`
- Docker Compose

The goal is to run local semantic search and RAG-style experiments without using MongoDB Atlas cloud or Voyage hosted APIs.

---

## Architecture

```text
Local Python app
  |
  | Generates embeddings locally with voyageai/voyage-4-nano
  v
MongoDB on localhost:27017
  |
  | Stores documents + embedding vectors
  v
mongod-vector-local
  |
  | Uses gRPC for Search/Vector Search
  v
mongot-vector-local
```

Your application connects only to MongoDB:

```text
mongodb://root:root-password@localhost:27017
```

It does not connect directly to `mongot`.

---

## Prerequisites

Install:

- Docker Desktop
- Git
- GitHub CLI, optional but useful
- MongoDB Shell: `mongosh`
- Python 3.11
- Homebrew, recommended on macOS

Check versions:

```bash
docker version
docker composer --version
git --version
mongosh --version
python3.11 --version
```

If Python 3.11 is missing on macOS:

```bash
brew install python@3.11
```

---

## Quick start

Clone the repo:

```bash
git clone https://github.com/rogerioignacio/mongodb-vector-local.git
cd mongodb-vector-local
```

Run the bootstrap script:

```bash
./scripts/bootstrap.sh
```

This script does the following:

1. Creates local secrets
2. Starts MongoDB
3. Initializes replica set `rs0`
4. Creates `mongotUser`
5. Starts `mongot`
6. Waits for Search commands to become available
7. Creates the vector index

Check status:

```bash
./scripts/check-status.sh
```

---

## Set up local Voyage 4 Nano

Create the Python environment:

```bash
./scripts/setup-python-voyage.sh
```

Activate the environment:

```bash
cd examples/voyage-nano-local
source .venv/bin/activate
```

Generate local embeddings and store them in MongoDB:

```bash
python embed_store.py
```

Expected output includes:

```text
Inserted 5 documents.
Embeddings were generated locally and stored in MongoDB.
```

The first run downloads the model from Hugging Face. After that, the model is cached locally.

---

## Test vector search

From:

```bash
cd examples/voyage-nano-local
source .venv/bin/activate
```

Run:

```bash
python query_vector.py
```

Default query:

```text
How does local MongoDB vector search work?
```

Expected output:

```text
Top matches:
{'title': 'MongoDB Community Search', ...}
{'title': 'Docker Architecture', ...}
...
```

You can override the query:

```bash
QUERY="What is RAG retrieval?" python query_vector.py
```

You can also filter by metadata, for example:

```bash
PLATFORM_FILTER=aws QUERY="What is generative AI on AWS?" python query_vector.py
```

This works because the vector index includes `platform` as a filter field.

---

## Verify stored vectors manually

Connect to MongoDB:

```bash
mongosh "mongodb://root:root-password@localhost:27017/rag_demo?authSource=admin&directConnection=true"
```

Check documents:

```javascript
db.documents.find(
  { source: "local-demo" },
  {
    title: 1,
    platform: 1,
    embeddingModel: 1,
    embeddingDimensions: 1,
    embeddingPreview: { $slice: ["$embedding", 5] }
  }
).pretty()
```

You should see:

```text
embeddingModel: "voyageai/voyage-4-nano"
embeddingDimensions: 1024
embeddingPreview: [ ... ]
```

---

## Verify Search and Vector Search

List Search indexes:

```bash
mongosh "mongodb://root:root-password@localhost:27017/rag_demo?authSource=admin&directConnection=true" --eval '
db.runCommand({ listSearchIndexes: "documents" })
'
```

You should see `vector_index`.

Create or recreate the vector index manually:

```bash
./scripts/create-vector-index.sh
```

Optional: create a text search index for `$search`:

```bash
./scripts/create-text-search-index.sh
```

---

## Test `$vectorSearch` manually

`query_vector.py` is the easiest way because it generates a query vector locally.

The core query it runs is equivalent to:

```javascript
db.documents.aggregate([
  {
    $vectorSearch: {
      index: "vector_index",
      path: "embedding",
      queryVector: [...],
      numCandidates: 50,
      limit: 5
    }
  },
  {
    $project: {
      _id: 0,
      title: 1,
      text: 1,
      platform: 1,
      score: { $meta: "vectorSearchScore" }
    }
  }
])
```

---

## Test `$search`

First create the text search index:

```bash
./scripts/create-text-search-index.sh
```

Then run:

```bash
mongosh "mongodb://root:root-password@localhost:27017/rag_demo?authSource=admin&directConnection=true" --eval '
db.documents.aggregate([
  {
    $search: {
      index: "text_search_index",
      text: {
        query: "MongoDB vector search",
        path: ["title", "text"]
      }
    }
  },
  {
    $project: {
      _id: 0,
      title: 1,
      text: 1,
      score: { $meta: "searchScore" }
    }
  }
])
'
```

---

## Daily commands

Start everything:

```bash
docker compose up -d
```

Stop everything:

```bash
docker compose stop
```

Check containers:

```bash
docker ps
```

Check stack status:

```bash
./scripts/check-status.sh
```

View MongoDB logs:

```bash
docker logs mongod-vector-local --tail 100
```

View mongot logs:

```bash
docker logs mongot-vector-local --tail 100
```

---

## Reset everything

Warning: this deletes all MongoDB and mongot local data.

```bash
docker compose down -v
```

Then rebuild:

```bash
./scripts/bootstrap.sh
```

Then regenerate embeddings:

```bash
./scripts/setup-python-voyage.sh
cd examples/voyage-nano-local
source .venv/bin/activate
python embed_store.py
python query_vector.py
```

---

## Important files

```text
docker-compose.yml
mongot-config/config.yml
scripts/bootstrap.sh
scripts/setup-secrets.sh
scripts/init-mongodb.sh
scripts/wait-for-search.sh
scripts/create-vector-index.sh
scripts/create-text-search-index.sh
scripts/check-status.sh
scripts/setup-python-voyage.sh
examples/voyage-nano-local/embed_store.py
examples/voyage-nano-local/query_vector.py
examples/voyage-nano-local/requirements.txt
examples/voyage-nano-local/.env.example
```

Generated local files not committed to Git:

```text
mongod-keyfile/keyfile
mongot-secrets/passwordFile
examples/voyage-nano-local/.env
examples/voyage-nano-local/.venv/
```

---

## Notes

This setup uses simple local demo credentials:

```text
root / root-password
mongotUser / mongot-password
```

Do not use these credentials for production.

This project is intended for local development and learning.

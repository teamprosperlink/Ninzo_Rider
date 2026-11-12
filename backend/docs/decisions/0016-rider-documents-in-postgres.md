# 0016: Rider document photos are kept in Postgres for the pilot

- Status: Proposed
- Date: 2026-11-11
- Deciders: Owner (to confirm)

## Context
Riders upload photos of their Aadhaar, driving licence, vehicle RC, a selfie and their bank details
while applying, so operations can check them by hand until DigiLocker. `startVerification` returned
no `upload_url`, so the rider app had nowhere to send them, and kept them on the phone. Decision 0004
leaves storage to be chosen separately, and no object store has been chosen.

## Options considered
1. An object store (Supabase Storage, S3, R2): built for files, cheap at scale / needs an account,
   keys and a bucket the owner has not set up yet.
2. Postgres `bytea`, through the rider API: works today with nothing new / grows the database, and the
   request limit (1 MB) caps a photo near 700 KB.

## Decision
Option 2 for the pilot: `rider_documents`, one row per document and side, replaced on re-upload, at
most 700 KB a photo, sent as base64 JSON (`uploadRiderDocument`). The app scales photos to 1400 px at
quality 70, which keeps them well under. The bytes are never written to audit rows, the outbox or
stored idempotent replies, and no endpoint returns them to the app.

## Consequences
- The rider app sends documents now; operations can read them from the database.
- At a few photos per rider the table stays small for the pilot. Moving to an object store later means
  copying the rows and replacing the column with a key; the API does not change.
- Database backups now carry KYC photos, and must be treated as such.

## Links
Rider app gaps (CHANGELOG, Unreleased). Decision 0004.

# yapp

yapp is an E2E encrypted messenger with zero-PII identity. yapp takes your identity as a keypair generated on your device.

## Stack

| Layer | Choice |
|-------|--------|
| App | Flutter (Dart), Android first |
| Crypto | libsignal (Rust, FFI) — AGPL-3.0 |
| Transport | Supabase Realtime + Postgres |
| Media | Supabase Storage |
| Push | FCM via Supabase Edge Function |
| Local store | SQLite via sqflite |

## Security model

- The server is untrusted; it relays and temporarily stores ciphertext, nothing else.
- Keys never leave the device; the secure enclave/keystore guards the identity vault.
- Losing the device + mnemonic means losing the account. That's the deal.
- Android backups are disabled.

## License

AGPL-3.0 — required by the libsignal dependency, and the right license for a private messenger anyway. See `LICENSE`.

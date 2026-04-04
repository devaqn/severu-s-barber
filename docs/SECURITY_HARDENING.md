# Security Hardening

## Offline authentication

Offline login is now disabled by default.

To explicitly enable it, define credentials at build/run time:

```bash
flutter run \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@suaempresa.com \
  --dart-define=OFFLINE_ADMIN_PASSWORD='SenhaForte#2026'
```

```bash
flutter build apk --release \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@suaempresa.com \
  --dart-define=OFFLINE_ADMIN_PASSWORD='SenhaForte#2026'
```

## Production checklist

- Keep Firebase Authentication enabled (Email/Password) and enforce strong passwords.
- Restrict Firestore writes with role-based security rules (`admin` only for user management).
- Never commit runtime memory dumps (`*.hprof`, `*.heapdump`) or local secrets.
- Use release signing keys (never distribute builds signed with debug keys).
- Keep Android cleartext traffic disabled and app backup disabled.


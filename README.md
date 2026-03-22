
# 🔐 Cyra — Privacy-First Secure Messaging App (Flutter)

**Cyra** is a privacy-centric, end-to-end encrypted (E2EE) messaging application built using **Flutter**, designed to demonstrate secure system design, clean architecture, and client-side cryptography.

Unlike typical chat apps, Cyra is built with **privacy as the default**, not an add-on.

---

## 🎯 Why This Project Matters (Recruiter View)

This project showcases my ability to:
- Design secure, scalable mobile architectures
- Implement client-side encryption workflows
- Enforce clean separation of concerns (UI, crypto, network)
- Apply security-first engineering judgment
- Build production-inspired systems, not toy demos

---

## ✨ Core Capabilities

- 🔒 End-to-End Encrypted 1-to-1 Messaging
- 🔑 Client-side key generation & session management
- 🧠 Encryption isolated from UI and network layers
- 🧩 Feature-based, scalable Flutter architecture
- 🛡️ Encrypted local storage (no plaintext messages)
- 🚫 Server has zero access to message content

---

## 🏗️ Architecture Overview

### Privacy-First Principles
- Messages encrypted before leaving the device
- Messages decrypted only on the recipient’s device
- Server acts as a blind relay
- UI never accesses cryptographic keys

### High-Level Flow
```
UI → Encryption Layer → Network → Server
↑                                   ↓
Decryption Layer ← Encrypted Payload ← Storage
```

---

## 📁 Project Structure

```
lib/
├── app/
├── core/
│   ├── crypto/
│   ├── network/
│   ├── storage/
│   └── utils/
├── features/
│   ├── auth/
│   ├── chat/
│   └── settings/
├── providers/
├── bootstrap.dart
└── main.dart
```

---

## 🛠️ Tech Stack

**Frontend**
- Flutter (Dart)
- Riverpod

**Security**
- Client-side cryptography
- Secure key storage (Keystore / Keychain)
- Session-based encryption

**Backend**
- Firebase / REST / WebSockets (transport only)

---

## 🔐 Security Model

- Identity keys generated on first launch
- Session keys per user pair
- Messages encrypted client-side
- Only encrypted data transmitted and stored

---

## 📌 Project Status

- Architecture: Completed
- Encryption Flow: In Progress
- Chat UI: In Progress
- Advanced Privacy Features: Planned

---

## 🚀 Getting Started

```bash
git clone https://github.com/yashpalsince2004/cyra_messaging_application.git
cd cyra_messaging_application
flutter pub get
flutter run
```

---

## 👨‍💻 Author

**Yash Pal**  
Engineering Student — Computer Science (AI & ML)  
Interests: Flutter, Cybersecurity, Privacy-Focused Systems, AI

GitHub: https://github.com/yashpalsince2004

---

## ⚠️ Disclaimer

Cyra is an educational project and not production-ready without a full security audit.

# MeshSync — Offline Emergency SOS Mesh Network
**SIH Internal Hackathon 2026**

---

## 📡 1. Overview & Problem Statement

In severe natural disasters (earthquakes, floods, cyclones, power grid failures), centralized cellular towers and commercial internet backbones are often the first critical infrastructure to collapse. Victims are left stranded without connectivity, while Search and Rescue (SAR) responders operate blind, unable to triage casualties or locate clusters of survivors.

**MeshSync** is a decentralized, serverless, peer-to-peer (P2P) emergency disaster communication network built on **Google Nearby Connections** (`P2P_CLUSTER`). It turns everyday smartphones into encrypted, store-and-forward mesh relay couriers that exchange life-saving distress signals, casualty counts, and triage statuses without cellular data, Wi-Fi routers, or internet infrastructure.

---

## 🏗️ 2. System Architecture & Protocol Design

### 2.1 Cryptographic Device Identity (`DeviceIdentity`)
- Each device generates a persistent random 24-bit hexadecimal origin identifier on initial boot.
- A monotonically incrementing 16-bit sequence number (`seq`) tracks outgoing messages.
- Deterministic Packet ID: `sha256(origin + seq)` truncated to 16 hex characters, guaranteeing collision-free deduplication offline across thousands of nodes.

### 2.2 Packet Architecture (`MeshMessage`)
Every mesh packet is split into two distinct layers:
1. **Core Payload (Frozen at Creation)**:
   - Immutable data: Origin ID, UTC timestamp, Category (`MEDICAL`, `TRAPPED`, `FIRE`, `SUPPLIES`), casualty count ($n$), optional text note (max 140 chars), GPS coordinates, and reference IDs.
2. **Envelope Layer (Travel State)**:
   - Mutable data: Hop counter (incremented on every relay hop) and Time-To-Live (TTL) expiration timestamps.

### 2.3 Store-and-Forward Flooding Router (`MeshRouter`)
- **Multi-Hop Relay**: Every device running MeshSync passively stores and forwards encrypted packets to all reachable peer nodes within Bluetooth/Wi-Fi Direct range.
- **Deduplication Cache**: A bounded LRU history buffer prevents rebroadcasting previously seen packet IDs.
- **Auto-ACK Propagation**: When a SAR Responder node receives a victim distress packet, an automated acknowledgement packet is created and flooded back through the mesh to confirm rescue awareness.
- **Flood Cancellation**: When an incident is resolved ("I Am Safe" or "Mark Rescued"), a `CANCEL` packet purges the incident across the network to free responder bandwidth.

---

## 🔐 3. Authentication & Strict Role Routing

MeshSync provides dedicated, isolated portals for survivors and emergency response teams:

### 3.1 Citizen / Victim Portal
- **Entry**: Sign in or Register with Name, Mobile Number / Emergency ID, and Security PIN.
- **Capabilities**:
  - Broadcast 1-tap emergency SOS beacons with casualty counts and landmark notes.
  - Track real-time broadcast delivery state (*Broadcasting* $\rightarrow$ *Relayed across $N$ nodes* $\rightarrow$ *Responder Acknowledged*).
  - Self-resolve emergencies via the "I Am Safe" trigger.
- **Privacy Enforcement**: Citizens **cannot** view other victims' private distress feeds or access the SAR command interface.

### 3.2 Search & Rescue (SAR) Responder Portal
- **Entry**: Sign in or Register with Responder Name, Official Badge ID, SAR Squad Unit Code, and Access PIN.
- **Capabilities**:
  - Live incident triage stream with real-time casualty counts and proximity hop distances.
  - Emergency category filtering (`MEDICAL`, `TRAPPED`, `FIRE`, `SUPPLIES`).
  - One-tap incident resolution ("Mark Rescued & Close") that floods resolution packets.
- **Operational Safety**: Responders **cannot** create personal SOS distress beacons.

---

## 🎨 4. Design Philosophy: Cognitive Minimalism

MeshSync uses an **exaggerated, cognitive minimalism** layout designed for high-stress disaster conditions:

1. **One Primary Action Per Screen**: Unmistakable focal hierarchy. Citizens have a single dominant emergency SOS trigger, preventing decision fatigue during panic.
2. **Editorial Serif Typography**: Distinctive `Newsreader` / `Georgia` display typography with strong weight contrast and oversized headings for maximum legibility.
3. **Restrained Organic Palette**:
   - **Dark Mode (`#0F0E0D`)**: Glare-free, warm dark background optimized for OLED battery longevity.
   - **Light Mode (`#F7F5F0`)**: High-contrast, warm tone for harsh outdoor sunlight.
   - **Terracotta Crimson (`#C93B2B`)**: Single focal emergency accent color.
   - **Sage Green (`#4A6B53`)**: Subdued confirmation and network status indicator.
4. **Deliberate Whitespace & Seamless Radio Lifecycle**: Background mesh radio runs automatically upon launch without manual toggle buttons cluttering the emergency interface.

---

## 📝 5. Changelog & Version History

### Changes in Version v0.9:
1. **Removed Manual Radio Toggle Buttons**: Eliminated the redundant "Start Radio / Stop Radio" control buttons and status cards from both the mobile app and preview screens. The Nearby Connections radio now boots and operates automatically in the background.
2. **Simplified Interface Hierarchy**: Cleaned up the main screen to dedicate full viewport space to the primary emergency tools (Distress SOS for Citizens, Incident Triage for SAR Teams).
3. **Appended Release Documentation**: Updated changelog and repository push records.

### Changes in Version v0.8:
1. **Removed Superficial Badge Elements**: Completely removed the "ONLINE / OFFLINE" pill indicators across the Flutter application and preview screens for a cleaner, authentic functional design.
2. **Simplified Radio Status Display**: Streamlined node call-sign and network description to show real reachable peer counts and clear Start/Stop action buttons.

### Changes in Version v0.7:
1. **Terminology Standardization**: Removed descriptive color labels ("Linen", "Obsidian") from all UI tooltips, toast notifications, code comments, and documentation in favor of clean, standardized **Light Mode** and **Dark Mode**.
2. **Complete Technical Documentation**: Overhauled `README.md` into comprehensive technical documentation detailing system architecture, packet protocols, role routing, and design guidelines.
3. **Refined Serif Typographic Hierarchy**: Polished `Georgia` / `Newsreader` font rules, letter spacings, and heading weights across Flutter components and the web simulator.

---

## 💻 6. How to Run Locally

### Native Flutter Mobile App (Android / iOS)
```powershell
cd mesh_sync
flutter pub get
flutter run
```

### Localhost Web Simulator (For rapid UI testing)
```powershell
python -m http.server 8000 --directory preview
```
Visit **`http://localhost:8000`** in your browser.

---

v.0.9 Push by - Aryan Time - 21.40 IST

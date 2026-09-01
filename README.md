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

## 🎨 4. Design System & UI Specifications

1. **Functional Sans-Serif System Font**: High-legibility `Inter` / `Roboto` / `SF Pro` system type stack. Eliminates decorative italics in favor of immediate scannability (bold/semibold headers, regular body).
2. **Structured 3-Tier Dark Elevation**:
   - **Background**: `#121212` (subtle base canvas)
   - **Card Surface**: `#1E1E1E` (elevated interaction layer)
   - **Borders & Dividers**: `#2E2E2E` (subtle 1px flat boundaries)
   - **Neutral Light Mode**: Clean `#F8FAFC` background with `#FFFFFF` cards and `#E2E8F0` borders.
3. **Strict Color Discipline**: Primary Red (`#DC2626`) is strictly reserved for the single primary call to action (SOS Button / Broadcast Dispatch). Neutral surfaces are used for toggles and category chips.
4. **Form Stacking & Touch Targets**: Consistent vertical stacking (labels above inputs) and dedicated full-height stepper touch targets (46px height with distinct +/- click areas).

---

## 📝 5. Complete Version History & Changelog

### **v1.0** (Current Release)
- **1.0.1 [Typography]**: Switched to a functional sans-serif typography stack (`Inter` / `Roboto` / `SF Pro`) across both Flutter and web preview environments; eliminated decorative italics in helper text for immediate emergency scannability.
- **1.0.2 [Elevation & Palette]**: Standardized elevation on a structured 3-tier dark surface system: Background `#121212`, Card Surface `#1E1E1E`, and Border `#2E2E2E`.
- **1.0.3 [Color Discipline]**: Primary Red (`#DC2626`) strictly assigned to the single primary call to action (SOS / Broadcast); converted category chips and toggles to neutral surface treatments.
- **1.0.4 [Form & Steppers]**: Enforced vertical label-over-input stacking and upgraded casualty steppers to dedicated full-height touch targets (46px height).
- **1.0.5 [Changelog]**: Restructured full repository changelog mapping every historical change to its exact version release.

### **v0.9**
- **0.9.1 [Radio Lifecycle]**: Completely removed manual "Start Radio / Stop Radio" control buttons and status cards; Nearby Connections radio lifecycle now automated silently in the background upon login.
- **0.9.2 [Viewport Optimization]**: Reclaimed screen real estate for primary incident response cards.

### **v0.8**
- **0.8.1 [UI Integrity]**: Removed artificial "ONLINE / OFFLINE" pill badges from the radio card to prevent visual clutter and maintain functional authenticity.
- **0.8.2 [Network Indicators]**: Simplified reachable peer node indicators into a clean top-bar modal button.

### **v0.7**
- **0.7.1 [Theme Standardization]**: Standardized all UI theme labels, tooltips, and toast notifications to clean **Light Mode** and **Dark Mode**, removing ambiguous descriptive labels.
- **0.7.2 [Documentation]**: Overhauled `README.md` into comprehensive technical architecture and protocol documentation.

### **v0.6**
- **0.6.1 [Focal Hierarchy]**: Implemented single primary action hierarchy per screen (prominent circular SOS button).
- **0.6.2 [Whitespace System]**: Implemented strict 8px layout grid with responsive padding.

### **v0.5**
- **0.5.1 [Authentication]**: Created dedicated entry portals for Citizen / Victim and Search & Rescue (SAR) Responder.
- **0.5.2 [Strict Role Isolation]**: Implemented strict role-based routing (Citizens can only broadcast outgoing SOS; Responders can only triage incoming feeds).
- **0.5.3 [Session Management]**: Added profile sign-out / logout action to top navigation.

### **v0.4**
- **0.4.1 [Header Clean-Up]**: Removed top-left status dot indicator from AppBar for an uncluttered minimalist header.

### **v0.3**
- **0.3.1 [Scope Reduction]**: Completely removed debug Tactical Log views, tab controllers, and terminal logs from the user-facing interface.

### **v0.2**
- **0.2.1 [Minimalist Redesign]**: Removed glassmorphism, blur effects, gradients, and heavy drop shadows in favor of flat high-contrast cards.
- **0.2.2 [Red SOS Trigger]**: Introduced high-visibility emergency Red circular SOS button.
- **0.2.3 [Web Simulator]**: Created interactive localhost web simulator on port 8000 for browser-based UI inspection.

### **v0.1**
- **0.1.1 [Core Architecture]**: Initial implementation of offline mesh engine over Google Nearby Connections (`P2P_CLUSTER`).
- **0.1.2 [Packet Protocol]**: Two-part packet architecture with SHA-256 deterministic deduplication.
- **0.1.3 [Store-and-Forward]**: Flooding router with auto-acknowledgements and flood-cancellation mechanisms.

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

v.1.0 Push by - Aryan Time - 21.43 IST

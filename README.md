# ParishServe

**Enterprise Ecclesiastical Administration & Diocesan Stewardship Platform**

> **Parish Jurisdiction:** St. John Paul II Parish (*Parochia Sancti Ioannis Pauli II*)  
> **Diocese:** Diocese of San Pablo (Brgy. Labuin, Santa Cruz, Laguna, Philippines)  
> **Ecclesiastical Motto:** *TOTUS TUUS*  
> **Version:** `1.0.0+1`  
> **Framework:** Flutter (Dart SDK `^3.12.2`)  
> **Backend Platform:** Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)  
> **Web Portal:** [https://parishserve.web.app](https://parishserve.web.app)

---

## 1. System Overview & Executive Summary

**ParishServe** is an enterprise-grade ecclesiastical administration and pastoral stewardship platform engineered specifically for Catholic parishes under the jurisdiction of the Diocese of San Pablo, Philippines, operating in strict compliance with the **Code of Canon Law** (*Codex Iuris Canonici*).

The platform seamlessly connects seven core operational pillars:
1. **Canonical Sacramental Register Digitization (Canon 535)** & Dynamic PDF/QR Certificate Generation.
2. **Parish Service Appointments, Mass Intention Scheduling** & LitCal Calendar Integration.
3. **POS Cashiering, Financial Ledgering,** & Particulars Catalog Management.
4. **Diocesan Asset Inventory (CustodiaIMS),** Reference Data Management, Security Watermarking, & Sticker Label Printing.
5. **Smart Archive Environmental Telemetry** (ESP32 IoT Conservation Monitoring for Vaults & Reliquaries).
6. **Daily Catholic Mass Readings** & Roman Catholic Lectionary Integration.
7. **Multi-Tier Role-Based Access Control (RBAC)** Governance & Pastoral Audit Logging.

---

## 2. Role-Based Access Control (RBAC) Governance

ParishServe enforces strict, role-based access control across all screens, services, database queries (Supabase RLS), and API routes:

| Role Code | Role Name | Key Responsibilities & Access Scope |
| :--- | :--- | :--- |
| **`superadmin`** | Super Administrator (S) | Unrestricted root system control across all modules, database tables, and settings. User account provisioning, role reassignment, account archiving (`AdminArchivedUsersPage`), hard deletion, global parish branding, certificate templates, and receipt configurations. |
| **`admin`** | Administrator (A) | System manager for user governance, asset inventory, smart archive thresholds, and operational diagnostics. |
| **`parishpriest`** | Parish Priest (P) | Supreme canonical authority and pastor. Full access to all 6 Sacramental Registers (Canon 535), Tuesday appointment approvals, mass intention approvals, official certificate signatory approvals, marginal notations, and immutable pastoral audit logs (`pastoral_audit_logs`). |
| **`secretary`** | Parish Secretary (Sc) | Primary day-to-day administrative user. Operates POS cashiering (`PosCashierPage`), official receipt issuance, particulars catalog management (`ParticularsService`), appointment bookings, sacramental record entry, asset label batch printing, and certificate issuance. |
| **`encoder`** | Records Encoder (E) | Data entry specialist for field digitization of physical ledger books (*Liber Baptismorum*, etc.), OCR scan verification, and physical asset inventory tagging. |
| **`pfc`** | Parish Finance Council (PFC) | Financial auditor access for receipt reviews, particulars catalog oversight, cashiering reports, remittance exports (`RemittanceReportService`), and diocesan asset valuation. |
| **`user`** | Parishioner / Client (U) | Self-service portal access for parishioners to book appointments, request mass intentions, track personal transaction receipts, read daily Catholic mass scriptures, verify official certificate authenticity via QR tokens, and submit Pabuklat requests. |

---

## 3. System Architecture & External APIs

The system architecture combines a Flutter multi-platform frontend with Supabase cloud infrastructure, mobile push services, and IoT hardware telemetry:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          ParishServe Flutter Frontend                           │
│  (Admin Shell • Main Staff Shell • Parishioner Portal • Web Verification Portal)    │
└────────┬───────────────────┬────────────────────┬──────────────────┬────────────┘
         │                   │                    │                  │
         ▼                   ▼                    ▼                  ▼
  ┌──────────────┐   ┌───────────────┐   ┌────────────────┐  ┌───────────────┐
  │ Supabase     │   │ OneSignal     │   │ LitCal API     │  │ ESP32 IoT     │
  │ Platform     │   │ Push Service  │   │ & Lectionary   │  │ Telemetry     │
  │ • Auth       │   │ • Mobile Push │   │ • Liturgical   │  │ • DHT22 Temp/ │
  │ • Postgres   │   │ • User Sync   │   │   Calendar     │  │   Humidity    │
  │ • Storage    │   │ • Targeting   │   │ • Daily Mass   │  │ • Threshold   │
  │ • Realtime   │   └───────────────┘   │   Readings     │  │   Alerts      │
  │ • Edge Func. │                       └────────────────┘  └───────────────┘
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ Brevo SMTP   │
  │ Email API    │
  └──────────────┘
```

### Key External APIs & Libraries:
* **Supabase (`supabase_flutter` `^2.17.2`):** Auth, 21-table PostgreSQL database with RLS, Realtime WebSocket listeners, Storage buckets (`certificate-assets`), and Deno Edge Functions.
* **OneSignal (`onesignal_flutter` `^5.7.0`):** Mobile push notifications for Android and iOS devices synced with Supabase user IDs.
* **LitCal Liturgical Calendar API:** Integrates with `https://litcal.johnromanodorazio.com/api/dev/calendar/nation/PH` for dynamic Catholic feast day and liturgical calendar calculations.
* **Roman Catholic Lectionary Daily Readings API:** Fetches daily First Reading, Responsorial Psalm, Second Reading, and Gospel scripture texts with liturgical color codes and saint/feast commemorations.
* **Brevo Email SMTP API:** Triggered by Supabase Edge Function `send-booking-confirmation` to deliver styled email confirmations attached with document submission checklists.
* **Printing & PDF Rendering (`pdf` `^3.13.1`, `printing` `^5.15.1`):** TrueType Unicode font rendering (`pdf_google_fonts`) supporting special characters (Ñ, ñ, diacritics) and currency symbols.

---

## 4. Core Functional Modules

### 1. Canonical Sacramental Records Digitization & Verification
* **6 Canonical Registers:** *Liber Baptismorum* (Baptisms), *Liber Confirmatorum* (Confirmations), *Liber Primae Communionis* (First Holy Communions), *Liber Matrimoniorum* (Matrimonies), *Liber Defunctorum* (Deaths/Burials), and *Liber Conversorum* (Conversions).
* **Physical Coordinates Validation:** Coordinates check for Book (1–200), Page (1–100), and Line (1–10) to prevent duplicate book/page/line registration.
* **Canon 877 §2 Unwed Paternity Compliance:** Handles unacknowledged paternity ("Not Indicated" fills canonical placeholders and displays "—" on certificates).
* **Certificate Engine & Visual Canvas Designer:** Simple Mode and Canva-Style Visual Designer Mode (`CertificateCanvasDesignerPage`) with drag-and-drop elements, custom styles, resizable text, and seal/signature placements.
* **Cryptographic QR Verification Tokenization:** Generates non-sequential UUID v4 verification tokens (`verification_id`) embedded as QR codes pointing to `https://parishserve.web.app/verify?v=<TOKEN>`.

### 2. Parish Service Appointments & Pastoral Scheduling
* **Service Presets & Durations:** Wedding (90m), Community Baptism (60m), Private Baptism (45m), Funeral Mass (60m), Anointing of the Sick (45m), House Blessing (45m), Thanksgiving Mass Intention (60m), Canonical Interview (45m), Confession (30m).
* **Paramount Canonical Rules:**
  1. *Monday Prohibition:* Mondays are strictly designated as Clergy Rest Days and Parish Office closure.
  2. *Tuesday Priest Approval:* Tuesday bookings require explicit Parish Priest approval before confirmation.
  3. *Liturgical Law Blocking:* Automated blocking on Solemnities, Paschal Triduum, Easter, Christmas, All Saints, All Souls, etc., using LitCal API.
  4. *Operating Window:* 06:00 AM – 07:00 PM.
  5. *Conflict Resolution:* Collision detection for presider and venue.
  6. *Automated Confirmation Emails:* Triggered via Supabase Edge Function attached with canonical document checklists.

### 3. POS Cashiering, Receipts & Financial Ledgering
* **Particulars Catalog (`ParticularsService`):** Stipends and fee catalog across Sacraments, Mass Intentions, Certificates, Devotionals, and Others.
* **POS Terminal (`PosCashierPage`):** Shopping cart UI supporting Cash, GCash/E-Wallet (with reference validation), and Gratis (canonically exempt).
* **Sequential Receipt Numbering:** Format `REC-YYYY-XXXXX`.
* **Multi-Format Receipt Designer:** Supports Ecclesiastical Voucher Slips (8.5 × 4.125 in), A4, Letter, Legal (8.5 × 13 in), and 80mm Thermal Receipt Rolls.
* **Financial Remittance Reports:** Exportable PDF/Excel ledger reports (`RemittanceReportService`).

### 4. Diocesan Asset Inventory (CustodiaIMS)
* **Control Number System:** Format `Location-Classification Year-Sequence` (e.g., `C-SI-2026-001`).
* **Book of Inventory Classification:** Section 1 (≥ ₱10,000.00) vs Section 2 (< ₱10,000.00).
* **Reference Data Management:** Dynamic locations and item classifications.
* **Automated Security Watermarking (`AssetImageWatermarkUtil`):** Embeds native canvas security watermark onto uploaded asset photos containing parish name, timestamp, and Diocesan Control #.
* **Asset Label PDF Printing (`AssetLabelPdfService`):** Generates 70mm × 38mm sticker labels and batch A4 sheets (3×8 grid = 24 labels/page) with QR codes.
* **RFID / NFC & Mobile Field Auditing (`_AuditScanDialog`):** Live camera scanner, 13.56 MHz RFID/NFC UID reading, or manual barcode lookup.

### 5. Smart Archive Environmental Telemetry (ESP32 IoT)
* **Conservation Thresholds:** Ideal Temp 18.0 °C – 24.0 °C (Warning > 26.0 °C), Ideal RH 45% – 55% RH (Warning > 60% RH to prevent mold growth and paper degradation).
* **Real-time Telemetry Ingestion:** DHT22 sensor telemetry transmitted from ESP32 microcontrollers into `storage_nodes` and `sensor_telemetry_logs`.

### 6. Daily Mass Readings & Lectionary
* Integrates Roman Catholic Lectionary scripture texts (`DailyReadingsService` / `DailyReadingsCard`) displaying First Reading, Responsorial Psalm, Second Reading, Gospel, liturgical colors, and saint commemorations.

---

## 5. Database Schema (21 Tables)

| Table Name | Description & Key Columns |
| :--- | :--- |
| **`users`** | User directory (`user_id`, `username`, `email`, `user_role`, `account_status`, `is_archived`). |
| **`appointments`** | Service bookings (`appointment_id`, `service_type`, `requested_date`, `requested_time`, `officiant_name`, `appointment_status`). |
| **`mass_intentions`** | Mass intentions (`intention_id`, `offering_type`, `intention_date`, `offering_amount`, `status`). |
| **`baptism_records`** | Canonical baptismal register under Canon 877 (*Liber Baptismorum*). |
| **`confirmation_records`** | Canonical confirmation register (*Liber Confirmatorum*). |
| **`first_communion_records`** | First Holy Communion register (*Liber Primae Communionis*). |
| **`matrimony_records`** | Canonical matrimony register (*Liber Matrimoniorum*). |
| **`death_records`** | Burial and death register (*Liber Defunctorum*). |
| **`conversion_records`** | Conversion and reception register (*Liber Conversorum*). |
| **`certificate_templates`** | Certificate template layouts, styling JSON, paper sizes, and signatory configurations. |
| **`certificate_issuances`** | Audit log of issued certificates with UUID v4 verification tokens (`verification_id`). |
| **`parish_certificate_settings`** | Global parish logo, seal, and header configuration. |
| **`parish_transactions`** | Financial POS receipt transactions (`receipt_number`, `payor_name`, `transaction_amount`, `transaction_type`). |
| **`parish_particulars`** | Catalog of offerings, stipends, and services (`particular_id`, `title`, `category`, `default_price`). |
| **`receipt_templates`** | Receipt template configurations, paper sizes, and Canva visual canvas JSON. |
| **`parish_assets`** | Registered diocesan assets (`control_number`, `photo_url`, `quantity`, `unit_price`, `condition_status`, `operational_status`). |
| **`asset_locations`** | Reference catalog for asset locations (Church, Sacristy, Office, Pastoral Office, PEAC, Multi-Purpose Hall, Others). |
| **`asset_classifications`** | Reference catalog for asset classifications (Sacred Image, Sacred Vessel, Musical Instrument, Liturgical Book, Furniture, Equipment, Tools, Others). |
| **`asset_audit_logs`** | Physical field audit inspection logs for parish property. |
| **`storage_nodes`** | ESP32 IoT environmental monitoring nodes, thresholds, current readings. |
| **`sensor_telemetry_logs`** | Historical temperature and relative humidity readings log. |
| **`pastoral_audit_logs`** | Immutable security and canonical audit log for priest actions and overrides. |

---

## 6. Brand Palette & UI Design System

ParishServe features an adaptive theme system (`ParishColors`) supporting clean parchment light mode and nocturnal slate dark mode:

* **Marian Blue:** `#164E87` (Primary brand accent, Coat of Arms)
* **Marian Blue Light:** `#246EB9`
* **Eucharistic Gold:** `#D49B18`
* **Mercy Red:** `#B91C1C`
* **Olive Green:** `#2D6A4F`
* **Royal Violet:** `#7C3AED`

---

## 7. Offline Codebase Bundle Directory

The project root directory maintains 6 synchronized text bundle files for offline code review:
1. `parishserve_codebase.txt`: Complete source tree across all 128 Dart files in `lib/`.
2. `receipts_codebase.txt`: All 14 Dart files in the Receipt Management module.
3. `assets_codebase.txt`: All 14 Dart files in the Asset Inventory module.
4. `sacramental_records_code.txt`: All 39 Dart files in the Sacramental Records module.
5. `parishserve_appointments_bundle.txt`: All 22 Dart files in the Appointments module.
6. `parishserve_system_context.txt`: Exhaustive system context documentation.

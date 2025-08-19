# Check-NPSPolicyUsage

A PowerShell script to search the **Windows Security log** for **NPS (RADIUS) policy hits**.  
Use it to verify whether specific **Network Policies** or **Connection Request Policies** are being used, who authenticated, the client IP, and whether access was **Granted** or **Denied**.

---

## ✨ Features

- Search by event XML fields:
  - **NetworkPolicyName**
  - **ProxyPolicyName** (also covers **ConnectionRequestPolicyName** for 6272/6273)
  - **ConnectionRequestPolicyName** (alias of ProxyPolicyName)
  - **CalledStationID**
- Exact or **contains** matching (`-Contains`).
- Time window via **minutes**, **hours**, or **days**.
- Clean, **autosized** console table with:
  - **TimeCreated**
  - **Access** (Granted/Denied, color-coded)
  - **UserName**
  - **ClientIP**
  - **AuthType**
  - **EAPType** (normalized to `EAP-TLS` for “Microsoft: Smart Card or other certificate”)
- Works on **Windows PowerShell 5.1** (and later).

---

## 🧰 Requirements

- Windows with **PowerShell 5.1+**
- Run **as Administrator** (needed to read the Security log)
- NPS role enabled and Security auditing producing 6272/6273 events

---

## 📥 Installation

Clone or download the script:

```powershell
git clone https://github.com/<your-org-or-user>/Check-NPSPolicyUsage.git
cd Check-NPSPolicyUsage
```

---

## 🚀 Usage

### Match a Network Policy (exact)
```powershell
.\Check-NPSPolicyUsage.ps1 -PolicyName "Wireless 802.1x | EAP-TLS | CORP Role" -HoursBack 1 -MatchField NetworkPolicyName
```

### Match a Connection Request Policy (use ProxyPolicyName)
```powershell
.\Check-NPSPolicyUsage.ps1 -PolicyName "Use Windows authentication for all users" -MinutesBack 10 -MatchField ProxyPolicyName
```

### Fuzzy contains match across a field
```powershell
.\Check-NPSPolicyUsage.ps1 -PolicyName "EAP-TLS" -DaysBack 1 -MatchField NetworkPolicyName -Contains
```

### Parameters

| Parameter        | Type    | Default              | Description                                                                                     |
|------------------|---------|----------------------|-------------------------------------------------------------------------------------------------|
| `-PolicyName`    | string  | — (required)         | The value to match against the selected field.                                                  |
| `-MatchField`    | enum    | `NetworkPolicyName`  | One of `NetworkPolicyName`, `ProxyPolicyName`, `ConnectionRequestPolicyName`, `CalledStationID`. |
| `-MinutesBack`   | int     | —                    | Look back this many minutes (takes precedence over hours/days).                                 |
| `-HoursBack`     | int     | —                    | Look back this many hours (takes precedence over days).                                         |
| `-DaysBack`      | int     | `1` (effective)      | Look back this many days (used if minutes/hours not provided).                                  |
| `-Contains`      | switch  | exact match          | Use substring (case-insensitive) instead of exact match.                                        |

**Note:** `ConnectionRequestPolicyName` is stored in 6272/6273 as **ProxyPolicyName**; the script maps this for you automatically.

---

## 📊 Output

- Autosized columns with two spaces between each column.
- **Access** is derived from the event ID: `6272 = Granted`, `6273 = Denied`.
- `EAPType` is normalized to `EAP-TLS` for “Microsoft: Smart Card or other certificate”.

Example:

```
TimeCreated              Access   UserName                              ClientIP        AuthType          EAPType
---------------------------------------------------------------------------------------------------------------
2025-08-19 15:15:33      Granted  host/PER1HJYKX3.jse.com               10.2.8.14       EAP               EAP-TLS
2025-08-19 15:17:56      Denied   host/MONHJS9XM3.jse.com               10.2.8.14       EAP               EAP-TLS
```

---

## 🔎 What it actually searches

The script reads **Security** log events **6272** (granted) and **6273** (denied), parses the **event XML** (not the free-form message), and filters by the selected field:
- `NetworkPolicyName`
- `ProxyPolicyName` (CRP)
- `ConnectionRequestPolicyName` (alias to `ProxyPolicyName`)
- `CalledStationID`

This avoids false matches from unrelated fields (e.g., AP SSIDs or cert subjects).

---

## ⚠️ Troubleshooting

- **“Access denied / unauthorized”** when reading Security logs → Run PowerShell **as Administrator**.
- **No results** → Expand the time window (e.g., `-HoursBack 6`) or confirm the exact policy name in Event Viewer.
- **Policy names** → In Event Viewer, open a 6272/6273 event, view the **XML** tab, and copy the exact field value.

---

## 📄 License

Released under the **MIT License**. See [LICENSE](LICENSE) for details.

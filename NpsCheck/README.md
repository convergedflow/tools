# Check-NPSPolicyUsage

PowerShell script for auditing **Microsoft NPS (Network Policy Server)** logs to see if a specific RADIUS policy is being hit.  
This is especially useful when cleaning up old policies and you want to be certain before disabling them.

---

## ✨ Features

- Searches both **System** and **Security** event logs for policy hits
- Filters results by **minutes**, **hours**, or **days**
- Shows either **all hits** or just the **most recent** with `-LatestOnly`
- Extracts **username** and **client IP/host** (when available)
- Handles empty logs gracefully (no ugly errors if no matches are found)

---

## 🛠 Requirements

- Windows Server with **NPS installed** and auditing enabled  
- **Administrator PowerShell session** (needed to read the Security log)  
- PowerShell **5.1 or later** (works on PowerShell 7+ too)  

---

## 📥 Installation

Clone this repository or download the script file:

```powershell
git clone https://github.com/<yourusername>/Check-NPSPolicyUsage.git
cd Check-NPSPolicyUsage
```

Optionally, add the folder to your `$env:PATH` so you can run the script from anywhere.

---

## 🚀 Usage

### Basic Syntax

```powershell
.\Check-NPSPolicyUsage.ps1 -PolicyName "<PolicyName>" [-MinutesBack <int>] [-HoursBack <int>] [-DaysBack <int>] [-LatestOnly]
```

### Parameters

| Parameter      | Description                                                                 | Default |
|----------------|-----------------------------------------------------------------------------|---------|
| `-PolicyName`  | **(Required)** Name of the NPS policy to search for.                        | —       |
| `-MinutesBack` | Look back over the last X minutes. Overrides `-HoursBack` and `-DaysBack`.  | —       |
| `-HoursBack`   | Look back over the last X hours. Overrides `-DaysBack`.                     | —       |
| `-DaysBack`    | Look back over the last X days (used if neither minutes nor hours provided).| 30      |
| `-LatestOnly`  | Show only the most recent matching event instead of all.                    | False   |

---

### Examples

```powershell
# Check if policy was used in the last 6 hours
.\Check-NPSPolicyUsage.ps1 -PolicyName "JSE-Corp" -HoursBack 6

# Check the last 90 minutes, only show the most recent hit
.\Check-NPSPolicyUsage.ps1 -PolicyName "JSE-Corp" -MinutesBack 90 -LatestOnly

# Check the last 14 days (default is 30 if not supplied)
.\Check-NPSPolicyUsage.ps1 -PolicyName "JSE-Corp" -DaysBack 14
```

---

## 📊 Output

### Standard run
```
TimeCreated           Id   Source        UserName   Client
-----------           --   ------        --------   ------
2025-08-19 13:45:10  6272 Security-NPS  alice      10.10.5.25
2025-08-19 13:47:32  6273 Security-NPS  bob        10.10.8.44
```

### With `-LatestOnly`
```
Most recent hit: 2025-08-19 13:45:10  [Event 6272 / Security-NPS]  User: alice  Client: 10.10.5.25
```

---

## 📌 Notes

- **Security log events** 6272 (*Access granted*) and 6273 (*Access denied*) are where NPS policy matches usually appear.  
- The **System log** may also contain NPS provider events depending on server configuration.  
- If no events are found in the specified time window, the script reports cleanly without errors.  
- Always run the script in an **elevated PowerShell session** to ensure access to the Security log.  

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

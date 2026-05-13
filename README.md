# Auto-Onboarding PowerShell Suite

A PowerShell automation suite that simulates enterprise Active Directory user onboarding — including account provisioning, department OU routing, manager email notification, and timestamped audit logging.

Built to demonstrate real-world IT systems administration skills using the same tools and workflows used in enterprise Windows environments.

---

## Features

- **CSV-driven input** — reads any number of new hire records from a structured CSV file
- **Automatic username generation** — builds usernames from first initial + last name, handles duplicates automatically (e.g. `jrodriguez`, `jrodriguez2`)
- **Department OU routing** — maps each hire to their correct Organizational Unit (IT, HR, Finance, Sales, Operations)
- **Secure password generation** — cryptographically random 14-character temporary passwords using `RandomNumberGenerator`
- **Manager email notification** — sends formatted onboarding emails with credentials to the hiring manager
- **Audit log** — every action is timestamped and written to a `.log` file under `.\Logs\`
- **Simulation mode** — runs fully on any Windows machine without a live AD environment; swap in real AD cmdlets for production use
- **WhatIf support** — built-in `-WhatIf` flag previews all actions without making any changes

---

## How to Run

### Requirements
- Windows 10 or 11
- PowerShell 5.1 or later

### Setup

1. Clone or download this repository
2. Open PowerShell as Administrator
3. Allow the script to run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
```

4. Navigate to the project folder:
```powershell
cd C:\Projects\AutoOnboarding
```

5. Run in simulation (safe preview) mode:
```powershell
.\Invoke-UserOnboarding.ps1 -CsvPath ".\NewHires.csv" -SmtpServer "mail.company.com" -FromAddress "it@company.com" -WhatIf
```

6. Run for real:
```powershell
.\Invoke-UserOnboarding.ps1 -CsvPath ".\NewHires.csv" -SmtpServer "mail.company.com" -FromAddress "it@company.com"
```

---

## CSV Format

| Column | Description | Example |
|---|---|---|
| FirstName | New hire first name | Thanos |
| LastName | New hire last name | Williams |
| Title | Job title | Systems Administrator |
| Department | Department name (must match OU map) | IT |
| EmailDomain | Domain for UPN and email | company.local |
| ManagerName | Hiring manager full name | Maria Santos |
| ManagerEmail | Manager email for notification | msantos@company.local |

---

## Sample Output

```
[2026-05-13 15:49:33] [INFO]    [User: SYSTEM] Loaded 4 new hire record(s).
[2026-05-13 15:49:33] [INFO]    [User: Thanos Williams] Processing: Thanos Williams | Systems Administrator | IT
[2026-05-13 15:49:33] [SUCCESS] [User: Thanos Williams] [SIMULATED] AD account created: jrodriguez | UPN: twilliams@company.local
[2026-05-13 15:49:33] [SUCCESS] [User: Thanos Williams] [SIMULATED] Welcome email sent to: msantos@company.local
[2026-05-13 15:49:33] [SUCCESS] [User: SYSTEM] Succeeded : 4

Name             Status   Username    Email
----             ------   --------    -----
Thanos Williams  SUCCESS  twilliams  twilliams@company.local
Emily Chen       SUCCESS  echen       echen@company.local
Marcus Williams  SUCCESS  mwilliams   mwilliams@company.local
Priya Patel      SUCCESS  ppatel      ppatel@company.local
```

---

## Production Deployment

To use in a live Active Directory environment:

1. Remove the simulation comments and uncomment `New-ADUser @params` in `New-ADUserAccount`
2. Uncomment `Send-MailMessage` in `Send-WelcomeEmail`
3. Update the `$ouMap` dictionary with your domain's actual OU distinguished names
4. Replace `DC=company,DC=local` with your real domain
5. Ensure the script runs under an account with AD user creation permissions

---

## Technologies

- PowerShell 5.1
- Active Directory (RSAT / AD DS)
- SMTP (Send-MailMessage)
- CSV parsing (Import-Csv)
- Cryptographic RNG (System.Security.Cryptography)

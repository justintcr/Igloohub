# Igloo Hub

Sales and operations app for The Cool Roofing Co. Runs on iPad, desktop and
iPhone. Works offline, installs to the home screen, deployed to Netlify.

Build v108 · 4 September 2026

## What is in here

| Path | What it is |
|---|---|
| `Igloo Hub iPad.dc.html` | The app. All seven logins, all screens. This is the file to edit. |
| `deploy/` | The built site. Drag this folder onto Netlify to publish. |
| `brand/` | Logos, product photos, colour swatches. |
| `supabase-schema.sql` | Database schema for the shared backend. Not live yet. |
| `Igloo Hub Build Spec.dc.html` | Technical spec — data model, permissions, sync rules, integrations. |
| `Igloo Hub Build Log.dc.html` | What was built and why, in plain language. |
| `Igloo Hub Working List.dc.html` | Current state and what is outstanding. |
| `Supabase Setup Walkthrough.dc.html` | Step-by-step for standing up the database. |
| `support.js`, `doc-page.js` | Runtime files. Do not edit. |

## Publishing a change

1. Edit `Igloo Hub iPad.dc.html`
2. Rebuild `deploy/index.html` from it
3. Drag the `deploy` folder onto the Deploys tab of the Netlify site
4. Force-close the app on each device so it picks up the new version

The version number lives in `deploy/sw.js` and needs bumping each time,
otherwise devices keep serving the old cached copy.

## Logins

Company code plus a four-digit PIN.

| PIN | Person | Role |
|---|---|---|
| 1101 | David Henry | Owner — every tab |
| 1102 | Justin Lee | Business development — every tab |
| 1103 | Jackson Lee | Sales |
| 1104 | John Nava | Sales |
| 1105 | Dawson Henry | Production — every tab |
| 1106 | Jennifer Henry | Finance — every tab |
| 1107 | Cindy DePree | Office |

## The packages

Marketed name, then the product it is built on. Priced high to low.

| Package | Product |
|---|---|
| Sentinel Select | 26GA Standing Seam Metal (WeatherXL) |
| Titan | Tuff-Rib Metal (WeatherX) |
| Legacy | StormMaster® Shake |
| Fortress | Pinnacle® Impact |
| Stronghold | Pinnacle® Sun |
| Guardian | Pinnacle® Pristine — default recommendation |
| Foundation | ProLam® |

## Known limitations

- **No shared database.** Each device holds its own records. Jennifer only
  sees a worksheet submitted on her machine. The weekly email is the interim
  hand-off. `supabase-schema.sql` is the fix, not yet wired up.
- **Roofr is one-way.** Signed jobs can be pushed out via Zapier. Leads
  cannot flow back in until the database exists.
- **CompanyCam** photo pull is a placeholder pending OAuth.

Full list in `Igloo Hub Working List.dc.html`.

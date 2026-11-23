# Co-hortdinate

Invite-only school holiday planning for a group of friends. Each family says which days they need care, which days they're home and can host (and how many extra kids), and which holiday programmes their kids are booked into. The calendar shows which days are short of spots.

## Try it first (demo mode)
Open `index.html` through any local web server (or deploy it as-is). With no Supabase keys, it runs in **demo mode**: there are 3 sample families, and everything is saved only in your browser. Use **Group → Reset demo data** to start over.

## Go live (about 15 min, same setup as OS:EM)

1. **Create a Supabase project** (free tier) at supabase.com. Use a new project so it stays separate from OS:EM.
2. **Run the schema:** in Supabase → SQL Editor → New query, paste all of `schema.sql` and click Run.
3. **Turn on email login:** Authentication → Sign In / Providers → Email should be on (it is by default).
4. **Add the code to the email (recommended for the installed phone app):** Authentication → Emails → "Magic Link" template. Add a line such as `Your code: {{ .Token }}`. Parents can then type the 6-digit code instead of tapping a link that opens in a different browser.
5. **Set the URL:** Authentication → URL Configuration. Set Site URL to the address where the app will live (for example `https://YOURNAME.github.io/co-hortdinate/`), and add the same address under Redirect URLs.
6. **Paste your keys:** in `index.html`, near the top of the script, fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Both are in Project Settings → API. The anon/publishable key is safe in the page because row-level security protects the data.
7. **Deploy:** push the 5 files (`index.html`, `manifest.webmanifest`, `sw.js`, `icon.svg`, and optionally this README) to a GitHub repo and enable GitHub Pages. Netlify drag-and-drop also works.
8. **Install on your phone:** open the URL, then Share → Add to Home Screen (iPhone) or ⋮ → Install app (Android).

Supabase's built-in email sender only allows a few emails per hour. For a friends' group that's usually fine. If people hit the limit, add a free SMTP provider (e.g. Resend) under Authentication → SMTP.

## How families use it
1. Sign in with email, then **create your family** (or join your partner's family with the partner code from the Family tab).
2. **Create a group** and share the invite code (Group → Copy invite), or **join** one with a code. A family can be in several groups.
3. **Family tab:** add kids (first name, birth month for age, optional gender).
4. **My plan:** use Quick fill to mark every weekday as "Need care", then change individual days to Hosting (set the number of extra kids, plus a note), Home or Away. Add programme bookings; those kids don't count as needing care on those days.
5. **Calendar:** red = short of spots, green = covered. Tap a day to see who needs care, who's hosting, who's at which programme, and who hasn't filled in yet.
6. **Programmes:** see which kids are at which programme on which days. "Book my kids for these days" pre-fills your booking form (you still book with the provider yourself).

## Holiday dates
Pre-filled with the Ministry of Education dates: Summer 2026/27, the Autumn/Winter/Spring 2027 breaks and Summer 2027/28. Terms 2 and 3 are fixed nationally. Each school picks its own Term 4 finish (by 18 Dec 2026) and Term 1 start (28 Jan to 3 Feb 2027), so the group admin should set the summer dates under **Group → Holiday dates** to match your kids' school. Summer 2027/28 is provisional. Auckland public holidays are labelled and skipped by Quick fill.

## Privacy
- A family can only see families it shares a group with (enforced in the database, not just the app).
- Partner codes are visible only to your own family.
- Anyone with a group's invite code can join, so share it only with people you trust.

## Ideas for v2
- Ask a host for a spot → they accept → spots count down (avoids double-booking)
- Reciprocity tally (days hosted vs. days helped)
- AM/PM half-days
- Push or email nudges for families who haven't filled in yet
- Remove a family from a group (admin)

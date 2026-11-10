# Notes for the App Review team (Zieuton)

> Pour Victor : ce texte est à coller dans App Store Connect → ta version → « Informations pour la vérification de l'app » → « Remarques ». Il est en anglais, pour le testeur d'Apple. Ajoute aussi les deux fichiers `exemple/zieuton-exemple-1.zip` et `-2.zip` en pièces jointes au même endroit (tickets FOU-32 et FOU-30).

---

Thank you for reviewing Zieuton. The app is in French; this note explains what it does and how to test it without an Instagram account.

## What the app does

Zieuton shows a person who unfollowed their Instagram account and who started following it. It does this only by comparing the **official data export** that the person requests from Instagram themselves (Accounts Center → Your information and permissions → Export your information, JSON format, "Followers and following" only).

- No Zieuton server, no Zieuton account, no analytics, no ads, no third-party SDK.
- Everything stays on the device. The only copy outside the device is an automatic backup in the user's own iCloud (iCloud Documents container `iCloud.fr.zyeuto.app`).
- No sign-in is required to use the app.

## 1. Why the app opens Instagram's Accounts Center in an in-app web view (Guideline 5.2.2)

To get their data, the user must request an export from Instagram. Many users never find this screen, so Zieuton opens Meta's **official page** `https://accountscenter.instagram.com/info_and_permissions/dyi/` in a `WKWebView`, with the address visible at the top, and shows a small guide banner at the bottom that says which of Instagram's buttons to tap next.

- **Zieuton does not use any Instagram API, does not scrape, and does not automate anything.** The user taps every button themselves, including "Download". The app never taps, fills in or submits anything on Instagram's page.
- **Zieuton never asks for, reads or stores the Instagram password.** If Instagram asks the user to log in, they type their password into Instagram's own form. The session cookies are kept by WebKit on the device, like in Safari; Zieuton has no access to them and sends nothing anywhere.

**What the guide banner reads** (inside the page, on the device only, never sent off the device):

- the visible text of the button the user just tapped (to move the guide to the next step);
- the visible titles and labels of the current Instagram screen (to know which step is shown, e.g. "Confirm your export", "Date range", "Format");
- on the "choose information" screen, which checkboxes are checked and their labels (to tell the user to keep only "Followers and following");
- **whether** a login field or a security-code field is visible, and whether the page says "incorrect password" (to show a hint). The **content** of these fields is never read;
- the number of "Download" buttons on the export page (to know when the file is ready).

**What the banner never reads:** the password or any typed value, messages, posts, contacts, or any other page of Instagram.

**Background check:** while an export is pending, the app may load the same export page in an invisible web view (same on-device session) only to count the "Download" buttons and detect a "pending" state, so it can send a local notification "Your file is ready". It never taps anything there either.

When the user taps "Download", the file is saved on the device and handed to Zieuton, which reads it locally.

## 2. The interface is an embedded HTML page (Guideline 2.5.2)

The app is a native Swift shell (UIKit + `WKWebView`) and its interface is an HTML/JavaScript page **bundled in the app binary**. The app works fully with this bundled page, offline included.

To fix bugs and adjust texts quickly, the app can download a newer copy of **the same page** from our own site (`https://zieuton.com/`). These updates:

- do not change the purpose or the features of the app that you review;
- cannot reach any native capability other than the small fixed message bridge compiled into the binary (file import, notifications, iCloud backup, StoreKit purchases, haptics, photo picker). Any new native capability requires a new binary submitted to App Review;
- do not download or execute native code;
- fall back automatically to the bundled page if a downloaded page fails to start.

## 3. How to test without an Instagram account

**Option A: demo mode (fastest).** On the first screen tap **"C'est parti"**, then **"Voir la démo"**. The whole app is filled with invented followers (all names end with "demo"): home, lists, charts, games. Leave it with **"Quitter la démo"** in the top banner. Demo mode is also in Settings (gear icon, top right) → **"Voir la démo"**. Nothing is saved during the demo.

**Option B: real import with our sample exports.** Two sample Instagram exports (invented accounts, all ending in ".sample") are attached to this submission and also available here:

- https://zieuton.com/exemple/zieuton-exemple-1.zip (40 followers, dated October 1)
- https://zieuton.com/exemple/zieuton-exemple-2.zip (39 followers, dated November 1)

Steps:
1. On the test device, open the first link in Safari and tap "Download".
2. Open the Files app → Downloads, **long-press** `zieuton-exemple-1.zip` → Share → **Zieuton**. The app imports it (first import = starting point).
3. Do the same with `zieuton-exemple-2.zip`. The app now shows **4 unfollowers**, **3 new followers**, and the "not following back" list.

Importing the same file twice is detected and adds nothing. An older export, a partial export or an export of another account is refused with an explanation.

If you prefer to test with a real Instagram account: tap "C'est parti" → "Ouvrir Instagram", log in on Instagram's page, and follow the banner. Instagram usually takes 2 to 10 minutes to prepare the file.

## 4. In-app purchases (Guideline 3.1.1)

Zieuton Plus is sold only through Apple in-app purchases (StoreKit 2). There is no other payment method and no external link to buy.

- Free: the first 2 imports, then 1 update per month.
- Plus removes the limit (unlimited updates) and unlocks a few extra trophies.
- Products for the first account: `fr.zyeuto.plus.mois` (monthly, auto-renewable), `fr.zyeuto.plus.an` (yearly, auto-renewable), `fr.zyeuto.plus.avie` (lifetime, non-consumable).
- The app can follow up to 3 Instagram accounts on one device. Accounts 2 and 3 need their own Plus: `fr.zyeuto.plus2.*` and `fr.zyeuto.plus3.*` (same three durations, lower price).

Where to find them: Settings (gear icon) → **Zieuton Plus** shows the offers, prices from the App Store, the renewal terms, and **"Restaurer mes achats"** (Restore Purchases). To see the offers for accounts 2 and 3: Settings → Mon compte → **"Ajouter un compte"**, type two first names, then try to import for that new account: the app asks for its own Plus first.

## 5. Privacy

The app collects no data (App Privacy: "Data Not Collected"). In Settings → Aide et confidentialité, an optional **"Envoyer un rapport"** button prepares an e-mail in the user's Mail app with the app version, iOS version and a list of technical errors (no Instagram usernames, no export content). The user sees the full text first and decides whether to send it.

Contact: victorfourneret@icloud.com

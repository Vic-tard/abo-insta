# Notes for the App Review team (Zieuton)

> Pour Victor : le champ « Remarques » d'App Store Connect (ta version → « Informations pour la vérification de l'app ») accepte 4 000 caractères au plus. Colle la **version courte** ci-dessous (environ 3 650 caractères). La version complète, plus bas, sert de référence ; tu peux aussi l'envoyer en pièce jointe avec les deux fichiers `exemple/zieuton-exemple-1.zip` et `-2.zip` (tickets FOU-32, FOU-30, FOU-111).
>
> **Mise à jour du 16 nov. 2026 (FOU-51)** : l'ancien chemin vers la démo (« C'est parti », taper un prénom, « Continuer », « Voir la démo ») n'existe plus depuis la suppression de l'écran prénom (PR #129). Chemin vérifié sur la page de `main` (simulation navigateur, pas encore sur iPhone) : à la première ouverture, le parcours guidé couvre tout l'écran et ne montre ni les Réglages ni la démo ; après l'import d'un fichier d'exemple, l'accueil s'affiche et Réglages → « Voir la démo » fonctionne. Section Instagram complétée avec ce que P1 à P6 et FOU-124 ont ajouté (liste des demandes, compte verrouillé, « Revenir dans Zieuton », chemin par l'app Instagram). **À revérifier sur l'iPhone avec le build de soumission avant de coller.**

## Version courte (à coller dans « Remarques »)

```
Zieuton shows a person who unfollowed their Instagram account and who started following it, only by comparing the official data export they request from Instagram themselves (JSON, "Followers and following"). No Zieuton server, no account, no sign-in, no analytics, no ads, no third-party SDK. Data stays on the device, plus an automatic backup in the user's own iCloud.

HOW TO TEST WITHOUT INSTAGRAM
On a fresh install, the app opens a short guided setup ("C'est parti !" then a plan screen). Settings are not shown until a first export is imported, so please start with the sample files:
1) Open https://zieuton.com/exemple/zieuton-exemple-1.zip in Safari and download it. In Files, long-press it > Share > Zieuton. It is imported as the starting point (the guided setup closes).
2) Same with https://zieuton.com/exemple/zieuton-exemple-2.zip (also attached). The app now shows 4 unfollowers and 3 new followers.
3) Demo with richer invented data: Settings (gear, top right) > "Voir la démo". Leave with "Quitter la démo" in the top bar.

1. IN-APP WEB VIEW (5.2.2)
"Ouvrir Instagram" opens Meta's official page accountscenter.instagram.com in a WKWebView, address visible, with a guide banner saying which button to tap next. No Instagram API, no scraping, no automation: the user taps every button, including "Download". The app never asks for, reads or stores the password; the user logs in on Meta's own form. On the device only, the banner reads visible titles, button labels, the list of the user's export requests and their status (a request is confirmed only when a new row appears), whether a login or code field is shown (never typed values), and an explicit "account locked" message, in which case the guide stops and sends the user to the official Instagram app. Nothing is sent anywhere. Once a request is confirmed, the banner offers "Revenir dans Zieuton". Alternative path: "Passer par l'app Instagram" opens Instagram (its own app if installed) and Zieuton shows screenshots of each step; nothing is read there.

2. BACKGROUND CHECK
While an export is pending, the app may load the same page in an invisible web view only to detect that the file is ready and send a local notification. It never taps anything there.

3. BUNDLED HTML INTERFACE (2.5.2)
Native Swift shell + an HTML page bundled in the binary; the app works fully offline with it. To fix bugs and texts, it can download a newer signed copy of the same page from https://zieuton.com/. Same features, no native code downloaded, and it can only use the fixed native bridge compiled in the binary (file import, notifications, iCloud backup, StoreKit, haptics, photo picker). Falls back to the bundled page on failure.

4. DEVELOPER SETTING (2.3.1)
In Settings, tapping the version number 5 times quickly switches this iPhone to a "test" update channel (new versions of the same page a few days early, for the developer). 5 more taps switch back. It unlocks nothing and changes no feature.

5. IN-APP PURCHASES (3.1.1)
Zieuton Plus, StoreKit 2 only, no external link. Free: 2 first imports, then 1 update per month; Plus = unlimited updates. Products: fr.zyeuto.plus.mois / .an (auto-renewable) and .avie (non-consumable). Up to 3 Instagram accounts per device; accounts 2 and 3 have their own Plus (fr.zyeuto.plus2.*, fr.zyeuto.plus3.*). Settings > Zieuton Plus shows offers, terms and "Restaurer mes achats". Account 2: Settings > Mon compte > "Ajouter un compte".

PRIVACY
Data Not Collected. The optional "Envoyer un rapport" button only prepares an e-mail in Mail that the user reads first and chooses to send.

Contact: victorfourneret@icloud.com
```

## Version complète
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
- the number of "Download" buttons on the export page (to know when the file is ready);
- the list of the user's own export requests on that page and their status (for example "Pending"): a request is considered sent **only when a new row appears** in this list, so the app never claims success without proof and never sends a second request on the user's behalf;
- whether Instagram shows an explicit message that the account is locked, suspended or disabled. In that case the guide stops immediately and tells the user, in neutral words, to continue in the official Instagram app.

**What the banner never reads:** the password or any typed value, messages, posts, contacts, or any other page of Instagram.

**Leaving Instagram:** once a request is confirmed, the banner shows a **"Revenir dans Zieuton"** button that closes Instagram's page and brings the user back to a waiting screen ("Instagram prépare ta liste"). That screen gives no time estimate and offers "Découvrir Zieuton en attendant", which opens the demo.

**Alternative path without the in-app web view:** on the plan screen, **"Passer par l'app Instagram"** opens Instagram itself (its own app if installed) and Zieuton shows screenshots of each step. Zieuton reads nothing in that case; the user then shares the downloaded file to Zieuton.

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

On a fresh install the app opens a short guided setup: a welcome screen (**"C'est parti !"**), then a plan screen with **"Ouvrir Instagram"**, **"Passer par l'app Instagram"** and **"J'ai une sauvegarde"**. This setup covers the whole screen, so Settings and the demo are only reachable after a first import. The fastest way is Option A below, then Option B.

**Option A: real import with our sample exports (start here).** Two sample Instagram exports (invented accounts, all ending in ".sample") are attached to this submission and also available here:

- https://zieuton.com/exemple/zieuton-exemple-1.zip (40 followers, dated October 1)
- https://zieuton.com/exemple/zieuton-exemple-2.zip (39 followers, dated November 1)

Steps:
1. On the test device, open the first link in Safari and tap "Download".
2. Open the Files app → Downloads, **long-press** `zieuton-exemple-1.zip` → Share → **Zieuton**. The app imports it (first import = starting point).
3. Do the same with `zieuton-exemple-2.zip`. The app now shows **4 unfollowers**, **3 new followers**, and the "not following back" list.

**Option B: demo mode.** Once the home screen is shown (after the first sample import), open Settings (gear icon, top right) → **"Voir la démo"**. The whole app is filled with invented followers (all names end with "demo"): home, lists, charts, games. Leave it with **"Quitter la démo"** in the top banner. Nothing is saved during the demo, and the imported sample data is kept.

Importing the same file twice is detected and adds nothing. An older export, a partial export or an export of another account is refused with an explanation.

If you prefer to test with a real Instagram account: tap "C'est parti !" → "Ouvrir Instagram", log in on Instagram's page, and follow the banner. Instagram decides how long it takes to prepare the file (often a few minutes, sometimes longer); the app does not promise a delay.

## 4. In-app purchases (Guideline 3.1.1)

Zieuton Plus is sold only through Apple in-app purchases (StoreKit 2). There is no other payment method and no external link to buy.

- Free: the first 2 imports, then 1 update per month.
- Plus removes the limit (unlimited updates) and unlocks a few extra trophies.
- Products for the first account: `fr.zyeuto.plus.mois` (monthly, auto-renewable), `fr.zyeuto.plus.an` (yearly, auto-renewable), `fr.zyeuto.plus.avie` (lifetime, non-consumable).
- The app can follow up to 3 Instagram accounts on one device. Accounts 2 and 3 need their own Plus: `fr.zyeuto.plus2.*` and `fr.zyeuto.plus3.*` (same three durations, lower price).

Where to find them: Settings (gear icon) → **Zieuton Plus** shows the offers, prices from the App Store, the renewal terms, and **"Restaurer mes achats"** (Restore Purchases). To see the offers for accounts 2 and 3: Settings → Mon compte → **"Ajouter un compte"**, type a first name for each account when asked, then try to import for that new account: the app asks for its own Plus first.

## 5. Developer setting: update channel (Guideline 2.3.1)

To be transparent about everything in the app: in Settings, **tapping the version number 5 times quickly** switches this iPhone to a "test" update channel. On that channel the device receives new versions of the same bundled page (see section 2) a few days before other users, so the developer can check them on his own iPhone first. Tapping 5 more times switches back. The version line then shows "canal test".

It changes no feature, unlocks nothing (no free purchase, no hidden content) and does not change which native capabilities the page can reach. It is only meant for the developer; you can ignore it.

## 6. Privacy

The app collects no data (App Privacy: "Data Not Collected"). In Settings → Aide et confidentialité, an optional **"Envoyer un rapport"** button prepares an e-mail in the user's Mail app with the app version, iOS version and a list of technical errors (no Instagram usernames, no export content). The user sees the full text first and decides whether to send it.

Contact: victorfourneret@icloud.com

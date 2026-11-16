# Propositions pour Linear du 16 novembre 2026 (FOU-83, FOU-101, FOU-105)

> **Propositions seulement.** Aucun statut changé, aucun ticket fermé, aucun commentaire posté dans Linear. Victor décide après relecture de ChatGPT. Chaque vérification non faite reste écrite « non faite ».

## 1. FOU-83 : ACRE, délai recalculé

**Faits**
- **[Confirmé, dossier de création du 3 nov.]** Début d'activité déclaré : **3 novembre 2026** (dossier envoyé sur le guichet unique le 3 nov. ; immatriculation le 5 nov.).
- **[Confirmé, Linear]** Le compte autoentrepreneur.urssaf.fr n'a pas pu être créé le 8 nov. : il manque le numéro de compte Urssaf (courrier attendu fin novembre).

**Délai**
- Sources lues le 16 nov. : trois sites spécialisés (portail-autoentrepreneur.fr mis à jour le 3 sept. 2026, legalstart.fr le 25 août 2026, portail-micro-entreprise.com). Les pages officielles de l'Urssaf refusent la lecture automatique : **elles n'ont pas été lues**. Les trois sites citent la LFSS 2026 et le décret n° 2026-69 du 6 février 2026 **[non vérifiés sur Légifrance]**.
- Les trois s'accordent sur **60 jours à partir de la date de début d'activité** (et non de la réception de l'attestation Urssaf).
- Calcul : 3 novembre 2026 + 60 jours = **samedi 2 janvier 2027**. **[Déduit]**
- Aucune source ne dit à partir de quelle date exacte les 60 jours s'appliquent. Si c'était encore 45 jours, la limite serait le **18 décembre 2026** (échéance actuelle dans Linear).
- **Proposition** : garder le **18 décembre** comme objectif de dépôt (sûr dans les deux cas), et noter le 2 janvier 2027 comme limite légale probable, à confirmer auprès de l'Urssaf.

**Dépôt sans compte Urssaf actif**
- Un site indique qu'il ne faut **pas** attendre l'attestation d'affiliation pour faire la demande, et qu'un formulaire de contact existe sur autoentrepreneur.urssaf.fr **sans se connecter**. Il ne dit pas clairement que ce formulaire accepte une demande d'ACRE. **[Inconnu]**
- Les formulaires cités diffèrent (« NAT. 6933/04.2026/FORM » d'un côté, Cerfa 13584-02 de l'autre). Les sites se contredisent aussi sur le silence de l'Urssaf (accord pour deux, refus pour un).
- Aucune adresse postale n'est donnée.
- **Proposition** : Victor appelle l'Urssaf (ou utilise le formulaire de contact sans connexion) **dès maintenant**, sans attendre le courrier, et pose trois questions : délai exact (45 ou 60 jours) pour un début d'activité au 3 nov. 2026 ; peut-on envoyer la demande d'ACRE avant d'avoir le numéro de compte, et par quel canal ; quel formulaire utiliser.
- Taux annoncé par les trois sites pour un début d'activité après le 1er juillet 2026 : **25 %** d'exonération (au lieu de 50 %). **[Non vérifié sur source officielle]**

**Commentaire Linear proposé (à poster seulement si Victor le valide)**

> Délai ACRE recalculé (16 nov.) : 60 jours après le début d'activité selon les sources spécialisées (LFSS 2026, décret 2026-69, non vérifiés sur source officielle) → limite probable le 2 janvier 2027 pour un début au 3 nov. 2026. Objectif de dépôt gardé au 18 décembre par prudence. Action : contacter l'Urssaf sans attendre le courrier (formulaire de contact sans connexion ou téléphone) pour confirmer le délai, le formulaire et le dépôt possible sans numéro de compte.

## 2. FOU-105 : « Envoyer le build 6 et le tester sur iPhone »

**Fait**
- [Vérifié] Build envoyé le 15 nov. sous le numéro 1.0 (7).
- [Déclaré, Victor] 1.0 (15) envoyé le 16 nov., export et import réels réussis.

**Non fait (à garder écrit)**
- Test des **achats** et de la **restauration** : pas refait depuis le build 3.
- Test **iCloud** (sauvegarde, restauration après réinstallation) : non confirmé sur 1.0 (7) ni 1.0 (15).
- Test des **notifications** : non confirmé par écrit.
- **Données gardées** lors de la mise à jour (7 → 15) : non confirmé par écrit.
- Build 16 (FOU-124 côté coque) : pas lancé, attend l'accord de Victor.

**Proposition** : **ne pas fermer tout de suite.** Renommer en « Build de soumission : test complet sur iPhone » et remplacer la description par un lien vers `docs/VALIDATION-BUILD-16.md`, avec les cases non faites ci-dessus. Le fermer seulement quand toutes les cases du plan sont « Fait ». (Option plus simple : le fermer comme « remplacé par 1.0 (15) » et ouvrir un nouveau ticket avec le même contenu. Les deux gardent les vérifications ; la première évite un ticket de plus.)

## 3. FOU-101 : « Perfectionner le build 6 » (parent)

**Fait** : [Vérifié] 8 de ses 10 sous-tickets directs terminés (FOU-45, 78, 97, 100, 102, 103, 104, 115).

**Encore ouvert dessous** : FOU-105 (voir ci-dessus) et FOU-33 (plan B, voir `docs/PLAN-B-APPLE-5-2-2.md`).

**Proposition** : rattacher FOU-105 et FOU-33 directement à FOU-51 (soumission), puis **fermer FOU-101** avec un commentaire : « Objectif du build 6 atteint par 1.0 (7) puis 1.0 (15). Vérifications restantes suivies dans FOU-105 (plan `docs/VALIDATION-BUILD-16.md`) ; plan B dans FOU-33. » Rien n'est perdu : chaque vérification non faite reste dans FOU-105.

## 4. FOU-33 : plan B

**Proposition** : réécrire la description autour de `docs/PLAN-B-APPLE-5-2-2.md` (option A puis B, pas de code avant la soumission), la rattacher à FOU-51, et faire choisir Victor : « en réserve » (recommandé) ou « prêt avant soumission ».

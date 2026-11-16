# Collaboration sur Zieuton : Claude, ChatGPT et Victor

Règles validées par Victor le 16 novembre 2026 (ticket FOU-122). Elles s'appliquent à Claude comme à ChatGPT. En cas de doute, demande à Victor.

## Les rôles

- **Claude** est le seul responsable du code. Il écrit le code, ouvre les PR et suit `CLAUDE.md`.
- **ChatGPT** est un auditeur indépendant. Il relit, il ne code pas.
- **Victor** garde la décision finale.

## Les règles

1. **Claude est le seul à écrire le code.** ChatGPT relit les PR et les commente sur GitHub, mais ne pousse aucun commit, n'ouvre aucune PR et ne fusionne rien.
2. **Linear reste la seule référence.** ChatGPT peut commenter les tickets Linear pour partager ses audits. Il ne change aucun statut et ne crée aucun ticket sans l'accord de Victor. C'est Victor qui crée ou valide les tickets.
3. **Victor tranche en cas de désaccord** entre Claude et ChatGPT. Claude ne modifie pas le code sur une remarque de ChatGPT tant que Victor ne l'a pas validée (ou qu'elle n'est pas dans un ticket).
4. **ChatGPT classe chaque remarque** dans l'une de ces trois catégories :
   - **Bug confirmé** : reproduit ou démontré (étapes, fichier et ligne, ou capture).
   - **Risque potentiel** : peut poser problème, mais pas encore constaté.
   - **Recommandation** : amélioration possible, rien n'est cassé.

## Priorité actuelle

L'export Instagram (FOU-121) : le récupérer simplement et correctement. Les audits portent d'abord là-dessus.

## À respecter par tous

Les promesses de `docs/SPEC.md` et les interdits de `CLAUDE.md` (pas de scraping, pas de serveur, pas de mot de passe Instagram, etc.) valent aussi pour les recommandations de ChatGPT.

// Crée la clé de signature des mises à jour de la page (FOU-29). À lancer UNE seule fois, sur le Mac de Victor.
// Dans le Terminal : tape « swift », un espace, glisse ce fichier dans la fenêtre, puis Entrée.
// Pas à pas complet : docs/MISES-A-JOUR.md, partie 4. Rien n'est enregistré ni envoyé : tout s'affiche à l'écran.
import CryptoKit
import Foundation

let key = Curve25519.Signing.PrivateKey()
print("""

1) CLÉ SECRÈTE : à coller dans GitHub (secret PAGE_SIGNING_KEY) et dans l'app Mots de passe.
   Ne la montre à personne, ne l'envoie à personne.

\(key.rawRepresentation.base64EncodedString())

2) CLÉ PUBLIQUE : pas secrète. Copie-la dans la discussion pour qu'elle soit écrite dans l'app.

\(key.publicKey.rawRepresentation.base64EncodedString())

Quand c'est fait, ferme cette fenêtre du Terminal.
""")

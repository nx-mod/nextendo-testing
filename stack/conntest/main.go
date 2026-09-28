// conntest — serveur :80 pour la vérification de connectivité de la console.
//
// La console teste conntest.nintendowifi.net / ctest.cdn.nintendo.net en HTTP
// clair sur :80. Le fichier hosts DNS-MITM les renvoie vers nous, donc si rien
// n'écoute sur :80 la console conclut « pas d'Internet » et le navigateur ne
// s'ouvre jamais.
//
// Deux modes (CONNTEST_MODE) :
//
//	portal (défaut) — répond notre page à TOUTES les URL. La console voit une
//	                  réponse inattendue, détecte un portail captif et propose
//	                  d'ouvrir le navigateur : c'est comme ça qu'on affiche la
//	                  page de création de compte sur la console.
//	pass            — imite le vrai Nintendo (200 + X-Organization: Nintendo,
//	                  corps vide). La console considère la connexion saine et
//	                  n'ouvre aucun navigateur. À utiliser une fois le compte
//	                  créé.
package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func main() {
	addr := envOr("CONNTEST_LISTEN", ":80")
	mode := strings.ToLower(envOr("CONNTEST_MODE", "portal"))
	static := envOr("NEXTENDO_STATIC", "../web")

	fs := http.FileServer(http.Dir(static))

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s%s", r.Method, r.Host, r.URL.Path)

		if mode == "pass" {
			// Réponse du vrai conntest : la console veut ces en-têtes exacts.
			w.Header().Set("X-Organization", "Nintendo")
			w.Header().Set("Content-Type", "text/html")
			w.WriteHeader(http.StatusOK)
			return
		}

		// Mode portail : tout chemin sans extension sert index.html, pour que la
		// console — qui demande /, /generate_204, /connecttest.txt, ... — reçoive
		// la page plutôt qu'un 404 qu'elle afficherait comme une erreur.
		if filepath.Ext(r.URL.Path) == "" {
			http.ServeFile(w, r, filepath.Join(static, "index.html"))
			return
		}
		fs.ServeHTTP(w, r)
	})

	log.Printf("[conntest] écoute %s mode=%s static=%s", addr, mode, static)
	log.Fatal(http.ListenAndServe(addr, mux))
}

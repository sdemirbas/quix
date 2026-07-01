.PHONY: build bundle run clean debug release

# Hızlı geliştirme (debug) çalıştırma
debug:
	swift run

# Release derleme
build:
	swift build -c release

# .app bundle oluştur
bundle:
	./scripts/bundle.sh

# Bundle oluştur ve aç
run: bundle
	open Quix.app

# İmzalı, notarize, GitHub'a yayınla + otomatik güncelleme (release.config'i güncelle)
release:
	./scripts/release.sh

clean:
	swift package clean
	rm -rf Quix.app .build dist

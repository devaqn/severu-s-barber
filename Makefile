.PHONY: help setup test analyze build deploy-rules deploy-all
help:
	@echo "Targets disponíveis:"
	@echo "  setup        — flutter pub get"
	@echo "  analyze      — flutter analyze"
	@echo "  test         — flutter test"
	@echo "  build        — flutter build apk --release"
	@echo "  deploy-rules — publica firestore.rules no Firebase"
	@echo "  deploy-all   — analyze + test + build + deploy-rules"
setup:
	flutter pub get
analyze:
	flutter analyze
test:
	flutter test
build: analyze test
	flutter build apk --release
deploy-rules:
	firebase deploy --only firestore:rules
deploy-all: analyze test build deploy-rules
	@echo "Deploy completo!"

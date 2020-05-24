.PHONY: build
build: build.fish posts
	mkdir -p ./public; ./build.fish

.PHONY: clean
clean:
	rm -r ./public

.PHONY: deploy
deploy: build
	./deploy.fish

.PHONY: demo build nbconvert

nbconvert:
	docker run \
		-v $(PWD):/home/kelby \
		--rm \
		--cap-drop=all \
		-it hugo:latest jupyter nbconvert --to markdown /home/kelby/notebooks/*

demo:
	docker run \
		-p 1313:1313 \
		-v $(PWD):/home/kelby/ \
		--rm \
		--cap-drop=all \
		-it hugo:latest hugo server -t hugo-notepadium -D -w --bind 0.0.0.0

build:
	docker run \
		-v $(PWD):/home/kelby/ \
		--rm \
		--cap-drop=all \
		-it hugo:latest hugo --gc -b https://kel.bz -t hugo-notepadium

.PHONY: test demo build deploy

test:
	echo "no tests configured"

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
		-it hugo:latest hugo -b https://kel.bz -t hugo-notepadium

deploy: build
	# scp -r public/* blog:/var/www/blog/

.PHONY: test demo deploy

test:
	echo "no tests configured"

demo:
	docker run \
		-p 1313:1313 \
		-v $(PWD):/home/kelby/ \
		--cap-drop=all \
		-it hugo:latest hugo server -t hugo-notepadium -D -w --bind 0.0.0.0

deploy:
	hugo -d ./output -b https://kel.bz -t angels-ladder 
	scp -r output/* blog:/var/www/blog/

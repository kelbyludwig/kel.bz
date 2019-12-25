.PHONY: test demo deploy

test:
	echo "no tests configured"

demo:
	hugo server -t angels-ladder -D -w

deploy:
	hugo -d ./output -b https://kel.bz -t angels-ladder 
	scp -r output/* blog:/var/www/blog/

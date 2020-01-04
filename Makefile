.PHONY: docker demo build nbconvert

image:
	docker build -t kelbz:latest .

nbconvert:
	docker run \
		-v $(PWD):/home/kelby \
		--rm \
		--cap-drop=all \
		-it kelbz:latest jupyter nbconvert --to markdown /home/kelby/notebooks/*


notebook:
	docker run \
		-p 8888:8888 \
		-v $(PWD)/notebooks:/home/kelby \
		--rm \
		--cap-drop=all \
		-it kelbz:latest jupyter notebook --no-browser --ip=0.0.0.0

demo:
	docker run \
		-p 1313:1313 \
		-v $(PWD):/home/kelby/ \
		--rm \
		--cap-drop=all \
		-it kelbz:latest hugo server -t hugo-notepadium -D -w --bind 0.0.0.0

build:
	docker run \
		-v $(PWD):/home/kelby/ \
		--rm \
		--cap-drop=all \
		-it kelbz:latest hugo --gc -b https://kel.bz -t hugo-notepadium

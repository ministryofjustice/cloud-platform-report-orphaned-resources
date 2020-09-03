IMAGE := foo

.built: Dockerfile bin/** lib/**
	docker build -t $(IMAGE) .
	touch .built

build: .built

run: build
	docker run --rm \
		-e AWS_ACCESS_KEY=$${AWS_ACCESS_KEY} \
		-e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} \
		-it $(IMAGE)

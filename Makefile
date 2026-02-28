
.PHONY: all docker docker-test demo test test-unit test-integration test-python clean

all: lib/brain-model

lib/brain-model:
	cat lib/brain-model-split-* > $@

docker:
	docker build -t span-mri:latest .

docker-test: docker
	docker run --rm span-mri:latest bash -c "cd /opt/span-mri && bash tests/run_tests.sh unit && bash tests/run_tests.sh python"

demo: lib/brain-model
	bash demo/run_demo.sh

test: test-unit test-python test-integration

test-unit:
	bash tests/run_tests.sh unit

test-integration:
	bash tests/run_tests.sh integration

test-python:
	python3 -m pytest tests/test_python.py -v

clean:
	rm -f lib/brain-model
	rm -rf demo/output
	rm -rf tests/tmp
	rm -rf lib/unetseg/__pycache__
	rm -rf tests/__pycache__

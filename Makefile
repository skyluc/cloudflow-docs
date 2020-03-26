# Build the Cloudflow documentation

include definitions.mk

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

antora_docker_image     := lightbend/antora-doc
antora_docker_image_tag := 0.1.0

work_dir := target

cloudflow_clone_dir := ${work_dir}/cloudflow

staging_dir := ${work_dir}/staging

javascaladoc_dir := ${staging_dir}/docs/current/api

all: build

clean:
	rm -rf ${work_dir}

build: clean html javascaladoc_staged print-site

html: clean
	docker run \
		-u $(shell id -u):$(shell id -g) \
		--privileged \
		-v ${ROOT_DIR}:/antora \
		--rm \
		-t ${antora_docker_image}:${antora_docker_image_tag} \
		--cache-dir=./.cache/antora \
		--stacktrace \
		docs-source/site.yml
	@echo "Done"

html-with-current: clean
	# copy of cloudflow-docs
	git cl . --branch ${current_version} --single-branch ${work_dir}/cloudflow-docs

	# change version to current in the copy
	awk ' \
		/version:/ {print "version: current"; next} \
		{print} \
	'	${work_dir}/cloudflow-docs/docs-source/docs/antora.yml > ${work_dir}/cloudflow-docs/docs-source/docs/antora.yml.tmp
	mv ${work_dir}/cloudflow-docs/docs-source/docs/antora.yml.tmp ${work_dir}/cloudflow-docs/docs-source/docs/antora.yml

	# create extended site.yml
	awk ' \
		/sources:/ { \
			print; \
			print "  - url: ./../"; \
			print "    branches: [HEAD]"; \
			print "    start-path: ${work_dir}/cloudflow-docs/docs-source/docs "; \
			next; \
		} \
		{print} \
	' docs-source/site.yml > ${work_dir}/site.yml

	docker run \
		-u $(shell id -u):$(shell id -g) \
		--privileged \
		-v ${ROOT_DIR}:/antora \
		--rm \
		-t ${antora_docker_image}:${antora_docker_image_tag} \
		--cache-dir=./.cache/antora \
		--stacktrace \
		${work_dir}/site.yml
	@echo "Done"

html-author-mode: clean
	docker run \
		-u $(shell id -u):$(shell id -g) \
		-v ${ROOT_DIR}:/antora \
		--rm \
		-t ${antora_docker_image}:${antora_docker_image_tag} \
		--stacktrace \
		docs-source/author-mode-site.yml
	@echo "Done"

check-links:
	docker run \
		-v ${ROOT_DIR}:/antora \
		--rm \
		--entrypoint /bin/sh \
		-t ${antora_docker_image}:${antora_docker_image_tag} \
		-c 'find /antora/docs-source -name '*.adoc' -print0 | xargs -0 -n1 asciidoc-link-check -p -c docs-source/asciidoc-link-check-config.json'

list-todos: html
	docker run \
		-v ${ROOT_DIR}:/antora \
		--rm \
		--entrypoint /bin/sh \
		-t ${antora_docker_image}:${antora_docker_image_tag} \
		-c 'find /antora/docs-source/build/site/cloudflow/${version} -name "*.html" -print0 | xargs -0 grep -iE "TODO|FIXME|REVIEWERS|adoc"'

# Generate the ScalaDoc and the JavaDoc, and put it in ${output}/scaladoc and ${output}/javadoc
javascaladoc: cloudflow-clone
	-(cd ${cloudflow_clone_dir}/core && sbt clean unidoc )

javascaladoc_staged: ${javascaladoc_dir} javascaladoc
	cp -r ${cloudflow_clone_dir}/core/target/scala-2.12/unidoc ${javascaladoc_dir}/scaladoc
	cp -r ${cloudflow_clone_dir}/core/target/javaunidoc ${javascaladoc_dir}/javadoc

# Cloudflow streamlets source for java and scala doc
cloudflow-clone: ${work_dir} clean-clone-dir
	git clone https://github.com/lightbend/cloudflow.git ${cloudflow_clone_dir}
	# need to use the release branch during release
	# git clone --single-branch --branch v1.3.1 git@github.com:lightbend/cloudflow.git ${cloudflow_clone_dir}

clean-clone-dir: 
	rm -rf ${cloudflow_clone_dir}

${work_dir}: 
	mkdir -p ${work_dir}


${staging_dir}:
	mkdir -p ${staging_dir}

${javascaladoc_dir}: 	
	mkdir -p ${javascaladoc_dir}/scaladoc
	mkdir -p ${javascaladoc_dir}/javadoc

print-site:
	# The result directory with the contents of this build:
	@echo "${staging_dir}"

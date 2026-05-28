#!/bin/bash

source $(dirname "$(realpath "$0")")/env

PROJECT_DIR=${THIS_DIR}/..

docker run -u "$(id -u):$(id -g)" -it --rm \
	--net=host \
	-v ${PROJECT_DIR}/:${CONTAINER_HOME}/clangtail/ \
	-v ${HOME}/.ssh/:${CONTAINER_HOME}/.ssh/ \
	${IMAGE_NAME} \
	bash

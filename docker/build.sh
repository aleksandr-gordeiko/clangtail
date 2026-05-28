#!/bin/bash

source $(dirname "$(realpath "$0")")/env

docker build -t $IMAGE_NAME $THIS_DIR


#!/bin/sh

case "$1" in
    build)
        echo "Building..."
        mkdir -p ./public
        ./build.sh
        echo "Done"
        ;;
    clean)
        echo "Cleaning..."
        rm -r ./public
        echo "Done"
        ;;
    deploy)
        echo "Deploying..."
        ./deploy.fish
        echo "Done"
        ;;
esac

# vim ft:sh

#!/bin/sh

case "$1" in
    install)
        ln -sfr ./pre-push .git/hooks/pre-push
        ;;
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
        ./deploy.sh
        echo "Done"
        ;;
esac

# vim ft:sh

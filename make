#!/usr/bin/env fish

switch "$argv[1]"
    case build
        echo "Building..."
        mkdir -p ./public
        ./build.sh
        echo "Done"
    case clean
        echo "Cleaning..."
        rm -r ./public
        echo "Done"
    case deploy
        echo "Deploying..."
        ./deploy.fish
        echo "Done"
end


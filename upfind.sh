#!/bin/bash

echo "Is this the directory you want to \"find\" from?"
echo "dir: $(pwd)"
read -p "(Y/n): " choice
case "$choice" in
  y*|Y*|"" ) ;;
  n*|N* ) echo "exit" && exit 0;;
  * ) echo "invalid choice" && exit 1 ;;
esac

# TODO: this script should return an error is the file wasn't found.
# If the file wasn't found in any of the parent dirs - return error.
# If at least one file was found - exit code should be 'success'.

while [[ $PWD != / ]] ; do
    find "$PWD"/ -maxdepth 1 "$@"
    cd ..
done

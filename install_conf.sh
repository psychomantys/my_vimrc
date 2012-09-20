#!/bin/bash

if [  -d "$( dirname "$0" )" \
	-a -d "$( dirname "$0" )/vim" \
	-a -r "$( dirname "$0" )/vimrc" ]
then
	ln -s "$( dirname "$0" )/vim" .vim
	ln -s "$( dirname "$0" )/vimrc" .vimrc
fi


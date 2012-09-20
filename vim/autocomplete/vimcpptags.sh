#/bin/bash

make_tags(){
	FILE=$(basename $1)
	TEMPFILE="/tmp/.${USER}%${FILE}"

	OPTIMIZE_SIZE='no'

	CPP_PREPROCESSOR="g++ -E -P ${CPPFLAGS}"
	CPP_CTAGS="ctags --c++-kinds=+p-d+t+x+l --language-force=c++ --fields=+iaS --extra=+q"
	C_PREPROCESSOR="gcc -E -P ${CFLAGS}"
	C_CTAGS="ctags --c-kinds=+p-d+t+x+l --language-force=c --fields=+iaS --extra=+q"




	CPP_CTAGS="ctags --c++-kinds=+csvpx-d+t --language-force=c++ --fields=+iaS --extra=+q"
	C_CTAGS="ctags --c-kinds=+csvpx-d+t --language-force=c --fields=+iaS --extra=+q"



	source "${HOME}/.vim/autocomplete/conf"

	if [ "${FILE%%.c}" != "$FILE" ] ; then
		CC="${C_PREPROCESSOR}" ;
		CTAGS="${C_CTAGS}" ;
	else
		CC="${CPP_PREPROCESSOR}" ;
		CTAGS="${CPP_CTAGS}" ;
	fi

	mkdir -p "$HOME/.vim/autocomplete/"

	if [ ! -f "${TEMPFILE}" ] ; then
		#${CC} -E "${1}" | fgrep -v -e '#' > "${TEMPFILE}"
		time ${CC} "${1}" > "${TEMPFILE}"
		if [ ! -f "$HOME/.vim/autocomplete/${FILE}.temp" ] ; then
			time ${CTAGS} -f "$HOME/.vim/autocomplete/${FILE}.temp" "${TEMPFILE}"
#			${CTAGS} -f "$HOME/.vim/autocomplete/${FILE}.tag" "${TEMPFILE}"
#			> "$HOME/.vim/autocomplete/${FILE}.tag"
		else
			echo "$HOME/.vim/autocomplete/${FILE}.temp existe"
			rm -f "${TEMPFILE}"
			exit 0 ;
		fi

		if [ "${OPTIMIZE_SIZE}" = 'yes' ] ; then
			echo grep
			time grep -v -e '^__' -e '^aux' "$HOME/.vim/autocomplete/${FILE}.temp" \
			| fgrep -v -e '~' -e 'access:private' -e 'operator' \
			| sed s:/tmp/.$USER%${FILE%?.*}:: \
			> "$HOME/.vim/autocomplete/${FILE}.tag"
		else
			echo grep
			time grep -v -e '^__' -e '^aux' "$HOME/.vim/autocomplete/${FILE}.temp" \
			| fgrep -v -e '~' -e 'access:private' -e 'operator' \
			> "$HOME/.vim/autocomplete/${FILE}.tag"
		fi

		rm -f "${TEMPFILE}" "$HOME/.vim/autocomplete/${FILE}.temp"
	else
		echo "${TEMPFILE} existe"
	fi
}

clean_tags(){
	FILE=$(basename $1)
	TEMPFILE="/tmp/.${USER}%${FILE}"

	rm -f "$HOME/.vim/autocomplete/${FILE}.temp"
	rm -f "$HOME/.vim/autocomplete/${FILE}.tag"
	rm -f "${TEMPFILE}"
}

case "$1" in
	make)
		shift
		make_tags $* &>/dev/null
	;;
	clean)
		shift
		clean_tags $* &>/dev/null
	;;
esac


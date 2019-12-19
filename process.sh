#!/usr/bin/env bash

print_help_and_exit() {
	# TODO
	echo 'Usage:'
	exit 1
}

create_chapter_image() {
	first_image="$(find "$1" -maxdepth 1 -type f | sort -V | head -n 1)"
	image_size="$(identify -format '%[w]x%[h]' "$first_image")"
	extension="${first_image##*.}"

	filename="$3"

	while [ "${#filename}" -lt 5 ];
	do
		filename="0$filename"
	done

	convert \
		-background white \
		-pointsize 24 -fill black \
		-size "$image_size" \
		-gravity center \
		label:"$2" \
		"$4/$filename.$extension"
}

if [ $# -lt 1 ];
then
	print_help_and_exit
fi

for manga_path in "$@";
do
	manga_name=$(basename "$manga_path")

	echo "$manga_name:"

	if [[ ! -d "$manga_path" ]];
	then
		echo "  Path '$manga_path' was not found, skipping"
		continue
	fi

	cbz_path="$(pwd)/$(basename "$manga_name").cbz"

	if [ -f "$cbz_path" ];
	then
		echo "  Target .cbz file '$cbz_path' already exists, skipping"
		continue
	fi

	process_path="./.process/$manga_path"

	if [[ -d "$process_path" ]];
	then
		echo "  Removing old process files at '$process_path'.."
		rm -r "$process_path"
	fi

	echo "  Creating process directory '$process_path'.."
	mkdir -p "$process_path"

	counter_path="$process_path/.counter"

	echo 1 > "$counter_path"

	# Using find seems to be the best way of filtering/sorting files
	# It does look really bad, but whatever
	#
	# https://askubuntu.com/questions/343727/filenames-with-spaces-breaking-for-loop-find-command
	find "$manga_path" \
		-maxdepth 1 \
		! -path "$manga_path" -type d \
		-regextype egrep -regex '.*/c[0-9.]+ \[.*\]$' \
		-print0 |
		sort -z -V |
		while IFS= read -r -d '' chapter_path;
		do
			chapter="$(basename "$chapter_path" | sed -E 's/.*c0*([0-9.]+).*/\1/')"
			echo "  Processing chapter $chapter.."

			counter=$(cat "$counter_path")
			echo $((counter + 1)) > "$counter_path"

			create_chapter_image "$chapter_path" "$chapter" "$counter" "$process_path"

			find "$chapter_path" \
				-maxdepth 1 \
				! -path "$chapter_path" -type f \
				-regextype egrep -regex '.*/[0-9.]+.(jpg|png)$' \
				-print0 |
				sort -z -V |
				while IFS= read -r -d '' image_path;
				do
					# Oh boy this is ugly as all hell
					counter=$(cat "$counter_path")
					echo $((counter + 1)) > "$counter_path"

					image=$(basename "$image_path")
					extension="${image##*.}"

					while [ "${#counter}" -lt 5 ];
					do
						counter="0$counter"
					done

					cp "$image_path" "$process_path/$counter.$extension"
				done
		done

	# zip is annoying and requires us to change the working directory,
	# therefore we just have to deal with the output being relative to the
	# current working directory.
	back="$(pwd)"

	# shellcheck disable=SC2164
	cd "$process_path"
	echo "  Compressing to '$cbz_path'.."
	zip "$cbz_path" ./* > /dev/null
	# shellcheck disable=SC2164
	cd "$back"
done

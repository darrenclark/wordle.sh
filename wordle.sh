#!/usr/bin/env bash

set -euo pipefail

flash_duration=0.2

esc_prev_line="\033[1A"
esc_clear_line="\033[2K"

esc_normal="\e[0m"
esc_black="\e[30m"
esc_dark_gray_bg="\e[100m"
esc_dark_red_bg="\e[41m"
esc_dark_green_bg="\e[42m"
esc_dark_yellow_bg="\e[43m"

words=/usr/share/dict/words
length=5

max_guesses=6

answer="$(grep '^[a-z]\{'"$length"'\}$' $words | shuf -n 1)"

padding="            "
prompt="$length letters > "

function give_up() {
	echo -e "\n\nYou gave up.  The word was:  $answer"
	exit
}

trap give_up SIGINT

function is_word() {
	grep '^'"$1"'$' $words > /dev/null
}

function reset_line() {
	printf "$esc_prev_line$esc_clear_line"
}

function clear_line() {
	echo -en "$esc_clear_line\r"
}

function repeat() {
	printf "$1"'%.0s' $(seq $2)
}

# evaluate <guess>
function evaluate() {
	echo -e "A $answer\nI $1" | awk '

		# Expects two lines of input:
		#
		#  A <answer>
		#  I <guess>
		#
		# And prints out one line per character in guess:
		#
		#  Y <character>   (correct)
		#  y <character>   (in word, but wrong position)
		#  N <character>   (not in word at all)

		/^A / {answer=$2}

		/^I / {
				input=$2
				n = length(input)

				# determine all correct characters
				for(i = 1; i <= n; i++) {
						ch=substr(input,i,1)
						if (ch == substr(answer,i,1)) {
								# remove characters (set to space)
								answer=substr(answer,1,i-1) " " substr(answer,i+1,length(answer)-i)
								input=substr(input,1,i-1) " " substr(input,i+1,length(input)-i)

								res[i] = "Y " ch
						}
				}

				# determine all characters in word, but wrong position
				for(i = 1; i <= n; i++) {
						ch=substr(input,i,1)

						# skip over characters that were correct
						if (ch != " ") {
								for (j = 1; j <= length(answer); j++) {
										if (substr(answer,j,1) == ch) {
												answer=substr(answer,1,j-1) " " substr(answer,j+1,length(answer)-j)
												res[i] = "y " ch
												break;
										}
								}
						}
				}

				for(i = 1; i <= n; i++) {
						if (i in res) {
								printf("%s\n", res[i])
						} else {
								printf("N %s\n", substr(input,i,1))
						}
				}

		}'

}

echo ""

guess_count=0

while :
do
	read -e -n $length -p "$prompt" input

	if [[ ${#input} -ne $length ]]; then
		n=$(($length - ${#input}))
		reset_line

		for _ in $(seq 3); do
			clear_line
			echo -en "$prompt${input}"
			printf "$esc_dark_gray_bg"
			echo -n $(repeat _ $n)
			printf "$esc_normal"
			sleep $flash_duration

			clear_line
			echo -en "$prompt${input}$(repeat ' ' $n)"
			sleep $flash_duration
		done

		clear_line
		continue
	fi
	
	if ! is_word $input ; then
		reset_line

		for _ in $(seq 3); do
			clear_line
			echo -en "$prompt"
			printf "$esc_dark_red_bg"
			echo -n "${input}"
			printf "$esc_normal"
			sleep $flash_duration

			clear_line
			echo -en "$prompt${input}"
			sleep $flash_duration
		done

		clear_line
		continue
	fi

	guess_count=$(($guess_count + 1))

	reset_line
	echo -n "$padding"

	evaluate $input | while read l; do
		ch=$(echo $l | cut -d ' ' -f 2)
		case $l in
		Y*)
			printf "$esc_black$esc_dark_green_bg$ch"
			;;
		y*)
			printf "$esc_black$esc_dark_yellow_bg$ch"
			any_wrong=yes
			;;
		N*)
			printf "$esc_normal$ch"
			any_wrong=yes
			;;
		esac
	done

	printf "$esc_normal\n"

	if [ $input = $answer ]; then
		echo -e "\nYou win!  ($guess_count/$max_guesses)"
		break
	elif [[ $guess_count -ge $max_guesses ]]; then
		echo -e "\nYou lose.  The word was:  $answer"
		break
	fi
done

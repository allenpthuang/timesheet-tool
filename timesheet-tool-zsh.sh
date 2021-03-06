#!/bin/zsh

[[ ! -z $ZSH_VERSION ]] || exit 1

# Term colors
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
LIGHTGREEN='\033[0;32m'
NC='\033[0m' # No Color

PRINT_CSV_METHOD='print_table_csv'

readonly SAVED_STATUS_FOLDER="$HOME/.timesheet_tool/saved"
readonly ARRAY_LIST=(tasks durations num_of_subtasks_under_tasks subtasks sub_durations)

declare -a tasks
declare -a durations
declare -a num_of_subtasks_under_tasks
declare -A subtasks
declare -A sub_durations


function roundhalves() {
  printf '%s * 0.5\n' "$(printf '%1.f' "$(printf '%s * 2\n' "$1" | bc)")" | bc
}

function displaytime() {
  printf '%02dh:%02dm:%02ds\n' $(($1/3600)) $(($1%3600/60)) $(($1%60))
}

function yes_no_prompt() {
  local yesno
  echo -n "Are you really sure? (y/n) "
  read yesno
  [[ "$yesno" =~ ^(y|yes|Y)$ ]] && return 0 || (echo "OK :)"; return 1)
}

function get_pause_duration() {
  read -s -r -k 1 "?Press any key to continue..."
  echo $(( $SECONDS - $1 ))
}

function safe_select_array_index() {
  local raw_input='NULL'
  local attempt_count=0
  until (( $raw_input >= 1 && $raw_input <= $1 )); do
    (( $attempt_count >= 1 )) && echo >&2 -n "Sorry, please input the right number (index): "
    read raw_input
    (( attempt_count++ ))
  done
  echo $raw_input
}

function end_task() {
  local end="false"
  local -a marks=( '/' '-' '\' '|' )
  local -a hourglasses=( '⏳' '⌛️' )
  
  echo -e "${WHITE}(e)${NC}nd the task, ${WHITE}(s)${NC}tart, ${WHITE}(c)${NC}ontinue a subtask or ${WHITE}(p)${NC}ause"
  until [[ $end == "e" ]] || [[ $end == "s" ]] || [[ $end == "c" ]]; do
	  printf "\r%s %s  %s  %s" \
      "${hourglasses[n++ % ${#hourglasses[@]} +1]}" \
      "$(displaytime $(( ${durations[$1]} + $(( $SECONDS - $2 )) )))" \
      "${marks[m++ % ${#marks[@]} +1]}" \
      "🤖️ (e/s/c/p) "
    
    read -t 1 -k 1 end
    if [[ $end == "p" ]]; then
      echo ""
      time_blew_by=$(get_pause_duration $SECONDS)
      durations[$1]=$(( ${durations[$1]} - $time_blew_by ))
      end="false"
      echo ""
    elif [[ $end == "e" ]] || [[ $end == "s" ]] || [[ $end == "c" ]]; then
      echo ""
	    durations[$1]=$(( ${durations[$1]} + $(( $SECONDS - $2 )) ))
      if [[ $end == "s" ]]; then
        start_subtask $1
      elif [[ $end == "c" ]]; then
        continue_subtask $1
      fi
    fi
  done
}

function end_subtask() {
  local end="false"
  local -a marks=( '/' '-' '\' '|' )
  local -a hourglasses=( '⏳' '⌛️' )
  
  echo -e "${WHITE}(e)${NC}nd the subtask or ${WHITE}(p)${NC}ause"
  until [[ $end == "e" ]]; do
	  printf "\r%s %s  %s  %s" \
      "${hourglasses[n++ % ${#hourglasses[@]} +1]}" \
      "$(displaytime $(( ${sub_durations[$1,$2]} + $(( $SECONDS - $3 )) )))" \
      "${marks[m++ % ${#marks[@]} +1]}" \
      "🤖️ (e/p) "
    
    read -t 1 -k 1 end
    if [[ $end == "p" ]]; then
      echo ""
      time_blew_by=$(get_pause_duration $SECONDS)
      sub_durations[$1,$2]=$(( ${sub_durations[$1,$2]} - $time_blew_by ))
      durations[$1]=$(( ${durations[$1]} - $time_blew_by ))
      end="false"
      echo ""
    elif [[ $end == "e" ]]; then
      echo ""
	    sub_durations[$1,$2]=$(( ${sub_durations[$1,$2]} + $(( $SECONDS - $3 )) ))
      durations[$1]=$(( ${durations[$1]} + $(( $SECONDS - $3 )) ))
    fi
  done
}

function start_subtask {
  (( num_of_subtasks_under_tasks[$1]++ ))
  subindex=${num_of_subtasks_under_tasks[$1]}
  subtask=$(bash -c 'read -e -p "What is your subtask? " tmpvar; echo "$tmpvar"')
  subtasks[$1,$subindex]="$subtask"
  echo -e "${LIGHTGREEN}OK, starting to work on [${subtasks[$1,$subindex]}]...${NC} 💪"
  end_subtask $1 $subindex $SECONDS
}

function start_task() {
  task=$(bash -c 'read -e -p "What is your task? " tmpvar; echo "$tmpvar"')
  tasks+=( "$task" )
  index=${#tasks[@]}
  echo -e "${LIGHTGREEN}OK, starting to work on [${tasks[$index]}]...${NC} 💪"
  end_task $index $SECONDS
}

function continue_subtask() {
  if [[ ! -z ${num_of_subtasks_under_tasks[$1]} ]]; then
    echo "-----------------------------------------------"
    for ((m = 1; m <= ${num_of_subtasks_under_tasks[$1]}; m++)); do
      printf "%-4s %s\n" "$m" "${subtasks[$1,$m]}"
    done 2>/dev/null
    echo "-----------------------------------------------"

    echo -n "Select which subtask you want to continue working on: "
    subindex=$(safe_select_array_index ${num_of_subtasks_under_tasks[$1]})
    echo -e "${LIGHTGREEN}OK, continuing [${subtasks[$1,$subindex]}]...${NC} 💪"
    end_subtask $1 $subindex $SECONDS
  else
    echo "No subtasks under Task [${tasks[$1]}]! 🤔"
  fi
}

function continue_task() {
  if (( ${#tasks[@]} == 0 )); then
    echo "You don't have any existing tasks!"
    continue
  else
    echo "-----------------------------------------------"
    for i in {1..$#tasks}; do
      printf "%-4s %s\n" "$i" "${tasks[$i]}"
    done
    echo "-----------------------------------------------"

    echo -n "Select which task you want to continue working on: "
    index=$(safe_select_array_index ${#tasks[@]})
    echo -e "${LIGHTGREEN}OK, continuing [${tasks[$index]}]...${NC} 💪"
    end_task $index $SECONDS
  fi
}

function print_table() {
  echo "============================================"
  echo "Your day: "
  echo "--------------------------------------------"
  if (( ${#tasks[@]} == 0 )); then
    echo "...is empty!"
  else
    for k in {1..$#tasks}; do
      printf "%-6s %-15s %s\n" "$k" "$(displaytime ${durations[$k]})" "${tasks[$k]}"
      if [[ ! -z ${num_of_subtasks_under_tasks[$k]} ]]; then
        local misc_duration=${durations[$k]}
        for ((m = 1; m <= ${num_of_subtasks_under_tasks[$k]}; m++)); do
          printf "%-8s %-17s %s\n" " |__ ${m}" "|__ $(displaytime ${sub_durations[$k,$m]})" "${subtasks[$k,$m]}"
          misc_duration=$(( $misc_duration - ${sub_durations[$k,$m]} ))
        done
        if (( $misc_duration != 0 )); then
          printf "%-8s %-17s %s\n" " |__ *" "|__ $(displaytime $misc_duration)" "misc."
        fi
      fi
    done
  fi
  echo "============================================"
}

function print_table_csv() {
  echo "============================================"
  echo "Copy to the SS: (rounded to 0.5 hours)"
  echo "--------------------------------------------"
  if (( ${#tasks[@]} == 0 )); then
    echo "...it is empty!"
  else
    for k in {1..$#tasks}; do
      printf "%s%s%s\n" "${tasks[$k]}" ",," "$(roundhalves $(bc -l <<<"${durations[$k]}/3600"))"
    done
  fi
  echo "============================================"
}

function print_results() {
  echo ""
  echo "Let's call it a day! 😎"
  echo ""
  echo "Your time sheet for $(TZ=":Asia/Hong_Kong" date +"%b %d (%a)")"
  print_table
  echo ""
  $PRINT_CSV_METHOD
  echo ""
  echo "Have a lovely evening! 🤗"
  exit
}

function save_to_file() {
  echo ""
  echo -n "Make up a filename to save current timesheet status (don't be too creative!): "
  read filename  

  if [[ ! -d "$SAVED_STATUS_FOLDER" ]]; then
    mkdir -p "$SAVED_STATUS_FOLDER"
  fi
  
  if [[ -f "$SAVED_STATUS_FOLDER/$filename" ]]; then
    echo "It seems you already have saved status under this name!"
    echo -n "If we proceed, your previous record will be lost. "
    yes_no_prompt || return
  fi
  
  declare -p "${ARRAY_LIST[@]}" > "$SAVED_STATUS_FOLDER/$filename"
  if [[ $? == 0 ]]; then
    echo "Current status saved to $SAVED_STATUS_FOLDER/$filename!"
  else
    echo "Something went wrong! Status not saved."
  fi
}

function read_from_file() {
  echo ""
  local saved_files=( )
  for i in $SAVED_STATUS_FOLDER/*(N); do
    [[ -f "$i" ]] && saved_files+=( "$i" )
  done

  if [[ -z $saved_files ]]; then
    echo "There seems no saved status to load!"
  else
    echo "-----------------------------------------------"
    for k in {1..$#saved_files}; do
      printf "%-4s %s\n" "$k" "${saved_files[$k]}"
    done
    echo "-----------------------------------------------"
    echo -n "Choose from the above: "
    local chosen_file_index=$(safe_select_array_index ${#saved_files[@]})
    echo "I'm going to load records from ${saved_files[$chosen_file_index]}."
    echo "This will OVERRIDE the current timesheet!"
    if yes_no_prompt; then
      echo -n "OK, loading... "
      source "${saved_files[$chosen_file_index]}"
      echo "done!"
    fi
  fi
}

function delete_status_file() {
  echo ""
  if yes_no_prompt; then
    local saved_files=( )
    for i in $SAVED_STATUS_FOLDER/*(N); do
      [[ -f "$i" ]] && saved_files+=( "$i" )
    done

    if [[ -z $saved_files ]]; then
      echo "There seems no saved status to delete!"
    else
      echo "-----------------------------------------------"
      for k in {1..$#saved_files}; do
        printf "%-4s %s\n" "$k" "${saved_files[$k]}"
      done
      echo "-----------------------------------------------"
      echo -n "Choose from the above: "
      local chosen_file_index=$(safe_select_array_index ${#saved_files[@]})
      echo "I'm going to DELETE records from ${saved_files[$chosen_file_index]}."
      echo "THERE IS NO UNDO."
      if yes_no_prompt; then
        echo -n "OK, deleting... "
        rm "${saved_files[$chosen_file_index]}"
        echo "done!"
      fi
    fi
  fi
}

function save_load_delete_status() {
  echo ""
  echo -e "${WHITE}(s)${NC}ave, ${WHITE}(l)${NC}oad or ${WHITE}(d)${NC}elete timesheet status?" \
          "Or anything else to return."
  echo -n "🤖️ (s/l/d) "
  read -k 1 sol
  case $sol in
    s|S) save_to_file ;;
    l|L) read_from_file ;;
    d|D) delete_status_file ;;
  esac
}

function main() {
  echo -e "Do you want to ${WHITE}(s)${NC}tart or ${WHITE}(c)${NC}ontinue a task?"
  echo -e "You can also print the current ${WHITE}(t)${NC}imesheet or e${WHITE}(x)${NC}it."
  echo -n "🤖️ (s/c/t/x) "
  read -k 1 mode
  echo ""
  case $mode in
    s|S) start_task ;;
    c|C) continue_task ;;
    t|T) print_table ;;
    x|X) yes_no_prompt && print_results ;;
    m|M) save_load_delete_status ;;
    *) echo "I don't understand! 🤔" ;;
  esac
  echo ""
}

while true; do
  main
done

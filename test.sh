#!/bin/bash
GREEN='\e[1;32m'
PURPLE='\e[1;35m'
RED='\e[1;31m'
WHITE='\e[1;37m'
RESET='\033[0m'

# Function to test error cases. Checks that something is written to either stdout or stderr.
# Will also report segmentation fault and report which arguments caused it.

run_err() 
{
	local test_desc=$1
	shift
	> .julestestfile
	> .julestestout
	./philo $@ > .julestestout 2> .julesstderr
	exit_code=$?
	if [ $exit_code -eq 139 ]; then
		echo -n "❌"
		echo -e "$test_desc: Segmentation Fault\n" >> philo_trace
	elif [ ! -s .julestestout ] && [ ! -s .julesstderr ]; then
		echo -n "❌"
		echo -e "$test_desc: No error message found\n" >> philo_trace
	else
		echo -n "✅"
	fi
}

# Function to test one philosopher. Will check to make sure they die and at the correct time.
# Test also implicitly tests that 4 arguments are valid as this is not tested explicitly elsewhere.

run_one()
{
	local test_desc=$1
	local min=$3
	local max=$((min + 10))
	shift
	> .julestestout
	> .julesone
	./philo $@ 1> .julesone 2> /dev/null
	time=$(tail -n 1 .julesone | awk '{print $1}')
	if ((time >= min)) && ((time <= max)); then
		tail -n 1 .julesone | sed 's/[0-9]\+ //' > .julestestout
		if diff .julestestout .julestestfile > /dev/null; then
			echo -n "✅"
		else
			echo -n "❌"
			echo -e "$test_desc: Philosopher did not die\n" >> philo_trace
		fi
	else
		echo -n "❌"
		echo -e "$test_desc: Philosopher did not die on time\n" >> philo_trace
	fi
}

# Function to test valid input. Checks timestamps of philo 1 to make sure actions are correctly timed.

run_full()
{
	local test_desc=$1
	local philo=$2
	local time_eat=$4
	local time_sleep=$5
	local eat=$6
	local forks=$(( eat * philo * 2))
	local tolerance=1
	shift
	> .julestestout
	> .julesphilolog
	./philo $@ 1> .julestestout 2> /dev/null
	awk '$2 == "1"' .julestestout > .julesphilolog
	read eat_time sleep_time think_time < <(awk '
    $4 == "eating" && !eat_time {
        eat_time = $1
    }  
    eat_time && $4 == "sleeping" && !sleep_time {
        sleep_time = $1
    }  
    sleep_time && $4 == "thinking" {
        think_time = $1
        print eat_time, sleep_time, think_time
        exit
    }
	' .julesphilolog)
	if grep -q " died" .julestestout; then
		echo -n "❌"
		echo -e "$test_desc: Philosopher died\n" >> philo_trace
	elif [ "$(grep "is eating" .julestestout | wc -l)" -lt $eat ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not eat enough\n" >> philo_trace
	elif [ "$(grep "has taken a fork" .julestestout | wc -l)" -lt $forks ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not take enough forks\n" >> philo_trace
	elif [ "$(grep "is sleeping" .julestestout | wc -l)" -lt $eat ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not sleep enough\n" >> philo_trace
	elif ((sleep_time - eat_time < time_eat || sleep_time - eat_time > time_eat + tolerance)); then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not eat for the correct time\n" >> philo_trace
	elif ((think_time - sleep_time < time_sleep || think_time - sleep_time > time_sleep + tolerance)); then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not sleep for the correct time\n" >> philo_trace
	else
		echo -n "✅"
	fi
}

# Function to test cases where philosophers should die. Will check the log ends with death message.
# Also tests whether philosophers died at appropriate times.

run_death()
{
	local test_desc=$1
	local philo=$2
	local min=$3
	local max=$((min + 10))
	local time_eat=$4
	local time_sleep=$5
	local eat=$6
	shift
	> .julestestout
	> .julesphilolog
	./philo $@ 1> .julestestout 2> /dev/null
	time=$(tail -n 1 .julestestout | awk '{print $1}')
	dead_id=$(awk '$3 == "died" {id = $2} END {print id}' .julestestout)
	awk -v id="$dead_id" '$2 == id' .julestestout > .julesdeathlog
	last_meal=$(awk '$3 == "eating" {time = $1} END {print time}' .julesdeathlog)
	: "${last_meal:=0}"
	awk '$2 == "1"' .julestestout > .julesphilolog
	variance=$((time - last_meal))
	if ! tail -n 1 .julestestout | grep -q "died"; then
		echo -n "❌"
		echo -e "$test_desc: Philosopher did not die\n" >> philo_trace
	elif ((variance < min)) && ((variance > max)); then
		echo -n "❌"
		echo -e "$test_desc: Philosopher did not die on time\n" >> philo_trace
	else
		echo -n "✅"
	fi
}

# If the program doesn't exist, compile it then clean up objects.
# If program still doesn't exist after compilation, terminate testing.

if [ ! -f "./philo" ]; then
	make
	make clean
fi
if [ ! -f "./philo" ]; then
	echo -e "${RED}Cannot create program. Exiting test...\n${RESET}"
	exit 1
fi
echo -e "----- TRACE BEGINS -----\n" >> philo_trace

# Run basic tests to check error cases

echo -e "${PURPLE}--- ${WHITE}Basic Error Tests${PURPLE} ---\n${RESET}"
echo -e "-- Basic Error Tests --\n" >> philo_trace

echo -n > .julestestfile

run_err "No arguments" ""
run_err "1" 1
run_err "1 1" 1 1
run_err "1 1 1" 1 1 1
run_err "1 1 1 1 1 1" 1 1 1 1 1 1
run_err "a a a a" a a a a
run_err "-1 1 1 1 1" -1 1 1 1 1
run_err "1 -1 1 1 1" 1 -1 1 1 1
run_err "1 1 -1 1 1" 1 1 -1 1 1
run_err "1 1 1 -1 1" 1 1 1 -1 1
run_err "1 1 1 1 -1" 1 1 1 1 -1
run_err "-1 -1 -1 -1 -1" -1 -1 -1 -1 -1
run_err "0 1 1 1" 0 1 1 1
run_err "1 0 1 1" 1 0 1 1
run_err "1 1 0 1" 1 1 0 1
run_err "1 1 1 0" 1 1 1 0
run_err "1 1 1 1 0" 1 1 1 1 0
rm -rf .julestestfile .julestestout .julesstderr

# Run tests for one philosopher

echo -e "${PURPLE}\n\n--- ${WHITE}One Philosopher Tests${PURPLE} ---\n${RESET}"
echo -e "-- One Philosopher Tests --\n" >> philo_trace

echo -e "1 died" > .julestestfile
run_one "1 1 1 1 1" 1 200 60 60 1
run_one "1 2 1 1 2" 1 200 60 60 2
run_one "1 10 5 5 2" 1 100 60 60 2
run_one "1 50 10 10 2" 1 500 100 100 2
run_one "1 50 10 10 10" 1 500 100 100 10
run_one "1 100 25 25 2" 1 1000 250 250 2
run_one "1 100 150 150 10" 1 100 150 150 10
rm -rf .julestestout .julesone .julestestfile

# Run tests where no philosophers should die.

echo -e "${PURPLE}\n\n--- ${WHITE}No Death Tests${PURPLE} ---\n${RESET}"
echo -e "-- No Death Tests --\n" >> philo_trace

run_full "2 15 5 5 2" 2 130 60 60 2
run_full "2 50 10 10 2" 2 300 100 100 2
run_full "2 50 10 10 5" 2 300 100 100 5
run_full "3 100 25 25 5" 3 200 65 65 5
run_full "3 310 100 200 5" 3 310 100 200 5
run_full "4 210 100 100 10" 4 210 100 100 10
run_full "4 410 200 200 10" 4 410 200 200 10
run_full "4 600 200 200 5" 4 600 200 200 5
run_full "5 610 200 200 5" 5 610 200 200 5
run_full "5 600 100 200 5" 5 600 100 200 5
run_full "5 800 200 200 7" 5 800 200 200 7
run_full "5 100 25 25 15" 5 300 60 60 15
run_full "10 50 10 10 50" 10 500 100 100 50
run_full "11 900 150 90 20" 11 900 150 90 20

rm -rf .julestestout .julesphilolog

# Run tests where a philosopher should die.

echo -e "${PURPLE}\n\n--- ${WHITE}Death Tests${PURPLE} ---\n${RESET}"
echo -e "-- Death Tests --\n" >> philo_trace

run_death "2 10 50 50 5" 2 100 60 60 5
run_death "2 100 50 50 5" 2 100 100 100 5
run_death "3 210 100 100 5" 3 210 100 100 5
run_death "3 1 2 2 5" 3 61 60 60 5
run_death "4 190 100 100 5" 4 190 100 100 5
run_death "5 1 1 1 3" 5 90 60 60 3
run_death "10 200 100 100 10" 10 200 100 100 10
echo -e "\n"
rm -rf .julestestout .julesphilolog .julesdeathlog
echo -e "---- TRACE ENDS ----\n" >> philo_trace

# Created by Jules Pierce @ Hive Helsinki 2025/03/11 - https://github.com/Jules478

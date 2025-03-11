#!/bin/bash
GREEN='\e[1;32m'
PURPLE='\e[1;35m'
RED='\e[1;31m'
WHITE='\e[1;37m'
RESET='\033[0m'

echo -n > julestestfile
echo -e "139" > julessegcheck

run_err() 
{
	local test_desc=$1
	shift
	> julestestfile
	> julestestout
	./philo $@ > julestestout 2> julesstderr
	exit_code=$?
	if [ $exit_code -eq 139 ]; then
		echo -n "❌"
		echo -e "$test_desc: Segmentation Fault\n" >> philo_trace
	elif [ ! -s julestestout ] && [ ! -s julesteststderr ]; then
		echo -n "❌"
		echo -e "$test_desc: No error message found\n" >> philo_trace
	else
		echo -n "✅"
	fi
}

run_one()
{
	local test_desc=$1
	local min=$3
	local max=$((min + 10))
	shift
	> julestestout
	> julesone
	./philo $@ 1> julesone 2> /dev/null
	time=$(tail -n 1 julesone | awk '{print $1}')
	if ((time >= min)) && ((time <= max)); then
		tail -n 1 julesone | sed 's/[0-9]\+ //' > julestestout
		if diff julestestout julestestfile > /dev/null; then
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

run_full()
{
	local test_desc=$1
	local philo=$2
	local time_eat=$4
	local time_sleep=$5
	local eat=$6
	local forks=$(( eat * philo * 2))
	local tolerance=2
	shift
	> julestestout
	> julesphilolog
	./philo $@ 1> julestestout 2> /dev/null
	awk '$2 == "1"' julestestout > julesphilolog
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
	' julesphilolog)
	if grep -q " died" julestestout; then
		echo -n "❌"
		echo -e "$test_desc: Philosopher died\n" >> philo_trace
	elif [ "$(grep "is eating" julestestout | wc -l)" -lt $eat ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not eat enough\n" >> philo_trace
	elif [ "$(grep "has taken a fork" julestestout | wc -l)" -lt $forks ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not take enough forks\n" >> philo_trace
	elif [ "$(grep "is sleeping" julestestout | wc -l)" -lt $eat ]; then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not sleep enough\n" >> philo_trace
	elif ((sleep_time - eat_time < time_eat || sleep_time - eat_time > time_eat + tolerance)); then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not spend enough time eating\n" >> philo_trace
	elif ((think_time - sleep_time < time_sleep || think_time - sleep_time > time_sleep + tolerance)); then
		echo -n "❌"
		echo -e "$test_desc: Philosophers did not spend enough time sleeping\n" >> philo_trace
		echo -e "desc: $test_desc philo: $philo time_eat: $time_eat time_sleep: $time_sleep eat: $eat"
	else
		echo -n "✅"
	fi
}

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
	> julestestout
	> julesphilolog
	./philo $@ 1> julestestout 2> /dev/null
	time=$(tail -n 1 julestestout | awk '{print $1}')
	dead_id=$(awk '$3 == "died" {id = $2} END {print id}' julestestout)
	awk -v id="$dead_id" '$2 == id' julestestout > julesdeathlog
	last_meal=$(awk '$3 == "eating" {time = $1} END {print time}' julesdeathlog)
	: "${last_meal:=0}"
	awk '$2 == "1"' julestestout > julesphilolog
	variance=$((time - last_meal))
	if ((variance >= min)) && ((variance <=max)); then
		if ! grep -q " died" julestestout; then
			echo -n "❌"
			echo -e "$test_desc: Philosopher did not die die\n" >> philo_trace
		else
			echo -n "✅"
		fi
	else
		echo -n "❌"
		echo -e "$test_desc philosopher did not die on time\n" >> philo_trace
	fi
}

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

echo -e "${PURPLE}\n\n--- ${WHITE}One Philosopher Tests${PURPLE} ---\n${RESET}"
echo -e "-- One Philosopher Tests --\n" >> philo_trace

echo -e "1 died" > julestestfile
run_one "1 1 1 1 1" 1 1 1 1 1
run_one "1 2 1 1 2" 1 2 1 1 2
run_one "1 10 5 5 2" 1 10 5 5 2
run_one "1 50 10 10 2" 1 500 10 10 2
run_one "1 50 10 10 10" 1 50 10 10 10
run_one "1 100 25 25 2" 1 100 25 25 2
run_one "1 100 150 150 10" 1 100 150 150 10

echo -e "${PURPLE}\n\n--- ${WHITE}No Death Tests${PURPLE} ---\n${RESET}"
echo -e "-- No Death Tests --\n" >> philo_trace

run_full "2 15 5 5 2" 2 15 5 5 2
run_full "2 50 10 10 2" 2 50 10 10 2
run_full "2 50 10 10 5" 2 50 10 10 5
run_full "3 100 25 25 5" 3 100 25 25 5
run_full "3 310 100 200 5" 3 310 100 200 5
run_full "4 210 100 100 10" 4 210 100 100 10
run_full "4 410 200 200 10" 4 410 200 200 10
run_full "4 600 200 200 5" 4 600 200 200 5
run_full "5 610 200 200 5" 5 610 200 200 5
run_full "5 600 100 200 5" 5 600 100 200 5
run_full "5 800 200 200 7" 5 800 200 200 7
run_full "5 100 25 25 15" 5 100 25 25 15
run_full "10 50 10 10 50" 10 50 10 10 50
run_full "11 900 150 90 20" 11 900 150 90 20

echo -e "${PURPLE}\n\n--- ${WHITE}Death Tests${PURPLE} ---\n${RESET}"
echo -e "-- Death Tests --\n" >> philo_trace

run_death "2 10 50 50 5" 2 10 50 50 5
run_death "2 100 50 50 5" 2 100 50 50 5
run_death "3 210 100 100 5" 3 210 100 100 5
run_death "3 1 2 2 5" 3 1 2 2 5
run_death "4 190 100 100 5" 4 190 100 100 5
run_death "5 1 1 1 3" 5 1 1 1 3
run_death "10 200 100 100 10" 10 200 100 100 10
echo -e "\n"
rm -rf jules*
echo -e "---- TRACE ENDS ----\n" >> philo_trace
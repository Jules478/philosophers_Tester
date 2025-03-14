# Philosophers Tester

## What is it?

This is my custom tester for the 42 school project 'Philosophers'. This project is variant of the [Dining Philosophers Problem](https://en.wikipedia.org/wiki/Dining_philosophers_problem) to demonstrate the use of threads and concurrency issues that can arise from multiple threads attempting to access the same data.

## What does it test?

This tester is designed to check the basic running of the program which can be difficult to parse visually. It will check that the timestamps for the actions of the philosophers are accurate and check whether death occurs depending on whether it should or not. It will check that basic error checking is handled. It will also check that philosophers pick up the correct number of forks for the amount of times they eat. If the program runs for too long suggesting that it is stuck in an infinite loop then the tester will kill the program and flag this as an error. This tester does not check valgrind or helgrind as the results are too unreliable for this project.

## How to run it

Simply drop the shell script file wherever your philo executable is and run it. The tester will create the files it requires and cleans them up when it is finished. A trace file is produced during the test and any test failures will have their input and a brief explanation of what caused the failure sent to the trace. This file will not be overwritten on subsequent runs so a constant log of issues is kept. 

> [!NOTE]
> This tester is not a definitive guide on the functionality of philosophers. This is only my own personal tests. There may be edge cases that are not considered here. This tester should be used as a tool and not a replacement for a full evaluation. 

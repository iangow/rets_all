#!/usr/bin/env bash 
#
# Run script using this command:
# ./script.sh 2>&1 | tee ./rets_all_R.log
printf "\nrets_all_pg.R:"
time ./rets_all_pg.R 
printf "\nrets_all_compute_pg.R:"
time ./rets_all_compute_pg.R
printf "\nrets_all_compute_pg_wrds.R:"
time ./rets_all_compute_pg_wrds.R
printf "\nrets_all_pq.R:"
time ./rets_all_pq.R
printf "\nrets_all_compute_pq.R:"
time ./rets_all_compute_pq.R
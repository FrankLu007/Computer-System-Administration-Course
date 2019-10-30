#!/bin/sh
ls -lAR | sort -nr -k5,5 | awk '/^d/ {dir++;} /^-/ {file++; print NR":"$5 " " $9;size=size+$5} END{printf("Dir num: %d \nFile num: %d \nTotal: %d \n",dir,file,size)}' | awk 'NR==1,NR==5{print $0 $4} /^(Dir|File|Total)/ {print $0}'
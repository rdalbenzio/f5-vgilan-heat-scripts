#!/bin/bash
for i in `seq 1 10`;
        do
                echo $i
		./delslice.sh -n $i CTRLPLANE1
                ./delscaleout.sh -n $i CTRLPLANE1
        done


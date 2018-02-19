#!/bin/bash
for i in `seq 1 10`;
        do
                echo $i
                ./newslice.sh -n $i CTRLPLANE1
                ./newscaleout.sh -n $i CTRLPLANE1
        done


#!/usr/bin/env bash
my_own_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
simoutfile=simout.vvp

iverilogcmd="iverilog -g2012 -I ${my_own_dir}/.. -y ${my_own_dir}/.. "

excluded_tests=("2.v" "3.v" "5.v")

for testfile in *.v ; do
    if [[ ${excluded_tests[@]} =~ ${testfile} ]]; then
        echo "Test ${testfile} excluded, skipping it"
        continue
    fi
    name=${testfile%%.v}
    vcdfile=${name}.vcd
    #simoutfile=${name}.vvp
    ${iverilogcmd} -o${simoutfile} -D"DUMP_FILE_NAME=\"${vcdfile}\"" ${testfile} && vvp ${simoutfile}
done


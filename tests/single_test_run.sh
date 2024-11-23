#!/usr/bin/env bash
my_own_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
simoutfile=simout.vvp
iverilogcmd="iverilog -g2012 -I ${my_own_dir}/.. -y ${my_own_dir}/.."

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename ${BASH_SOURCE[0]}) testfilename.v"
    exit 1
fi

testfile="$1"
name=${testfile%%.v}
vcdfile=${name}.vcd

${iverilogcmd} -o${simoutfile} -D"DUMP_FILE_NAME=\"${vcdfile}\"" ${testfile} && vvp ${simoutfile}

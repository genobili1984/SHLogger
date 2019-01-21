#!/bin/bash
set -e

:<<!EOF!
这个一个协助过滤日志的脚本， 用户可以通过命令行支持的参数来过滤脚本日志
调用方式 sh ./fileterLog.sh -p mylog.log -f "\[MyTestFunction\]" -m "\[NetworkModule\]" -l SHLogFlagInfo -o ./output.log
!EOF!

usage() { echo "Usage: $0 [-p <filepath>] [-f <function name>] [-m <module name>] [-l <level name>] [-o <output file>]" 1>&2; exit 1; }

while getopts ":p:f:m:l:o:" option; do
   case "${option}" in 
      p)
        path=${OPTARG}
        ;;
      f) 
        function=${OPTARG}
        ;;
      m) 
        module=${OPTARG}
        ;;
      l)
        level=${OPTARG}
        ;;
      o)
        outfile=${OPTARG}
        ;;
      *)
        usage
        ;;
   esac
done
shift $((OPTIND-1))

echo "filename=${path}"
echo "function name=${function}"
echo "module name=${module}"
echo "level name=${level}"
echo "outfile = ${outfile}"

if [ -z "${path}" ]; then
   usage
fi

ll=""
if [ -n "${level}" ]; then
   case "${level}" in
        SHLogFlagVerbose)
            ll="\[Level:1\]"
            ;;
        SHLogFlagDebug)
            ll="\[Level:2\]"
            ;;
        SHLogFlagInfo)
            ll="\[Level:4\]"
            ;;
        SHLogFlagWarning)
            ll="\[Level:8\]"
            ;;
        SHLogFlagError)
            ll="\[Level:16\]"
            ;;
        *)
            echo "level can just one of SHLogFlagVerbose|SHLogFlagDebug|SHLogFlagInfo|SHLogFlagWarning|SHLogFlagError"
            exit 1
            ;;
   esac
fi

#判断文件路径是绝对路径还是相对路径
if [[ $path = /* ]]; then
   echo "filepath is absolute path"
else
   path=$(pwd)/$path
fi

echo "input filepath = ${path}"

if [ -n "${outfile}" ]; then
if [[ $outfile = /* ]]; then
   echo "outfile path is absolte path"
else
   outfile=$(pwd)/$outfile
fi
fi

command="cat ${path} "

if [ -n "${module}" ]; then
   command="${command} | grep \"${module}\" "
fi

if [ -n "${function}" ]; then
   command="$command | grep \"${function}\""
fi

if [ -n ${ll} ]; then
   command="$command | grep \"${ll}\""
fi

if [ -n "${outfile}" ]; then
   command="$command >> ${outfile}"
fi

echo "command = ${command}"
echo ${command} | sh

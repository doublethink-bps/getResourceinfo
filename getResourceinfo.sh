#!/bin/bash

#display Resource information
showPerf(){
    phycpu=1
    getcount=0
    # display Total resource
    echo "Total Disk Size:`df -h |awk '/\/dev\/..[a-z][0-9]/{print $2}'`"
    echo "Total Memory Size:`free -h -t |awk '/Total:/{print $2}'`"
    mapfile cpu < <( cat /proc/cpuinfo|awk '/cpu cores/{print $4}'|sort -u)
    for cpucore in ${cpu[@]}; do  
        echo "Number of cpu core in Physical CPU$phycpu: $cpucore"
        phycpu=`echo $phycpu+1|bc`
    done
    # display resource info by Specified number of times
    while [ $getcount -lt $1 ]; do
        echo "########################################"
        echo "START Get Performance information!!"
        echo "START Day and Time:"`date`
        echo "########################################"
        echo " "
        echo "########################################"
        echo "# DISK INFO"
        echo "########################################"
        df -h |grep Filesystem
        df -h |grep -e \/dev\/..[a-z][0-9]
        echo " "
        echo "########################################"
        echo "# MEMORY INFO"
        echo "########################################"
        free -h -t
        echo " "
        echo "########################################"
        echo "# CPU INFO"
        echo "########################################"
        output=$(top -n 1)
        syUsage=$(echo "$output"|awk '/Cpu/{ print $2 }')
        usUsage=$(echo "$output"|awk '/Cpu/{ print $4 }')
        echo "System CPU use rate:" $syUsage"%"
        echo "User CPU use rate:" $usUsage"%"
        echo "scale=1; $syUsage + $usUsage"|bc|xargs printf "%.1f\%\n"|xargs echo "Total CPU use rate:" 
        echo " "
        echo "########################################"
        echo "END Get Performance information!!"
        echo "END Day and Time:"`date`
        echo "########################################"
        getcount=`echo "$getcount+1"|bc`
        
        # Finish showing resource when getcount equals specified number of times
        if [ $getcount -eq $1 ]; then
            exit 0
        fi
        # sleep at specified interval
        sleep $2
    done
}

# Take statistics resource inforamtion
calcPef(){
    getcount=0
    sum_mempused=0
    max_mempused=0
    sum_cpupused=0
    max_cpupused=0
    avg_mempused=0
    avg_cpupused=0
    memArr=()
    cpuArr=()
    timeArr=()
    tmpCount=0
    memstarttime=""
    cpustarttime=""
    # show resource info by Specified number of times
    while [ $getcount -lt $1 ]; do
        
        # get time that execute command 
        timeArr+=(`date +'%Y%m%d%H%M%S'`)
        
        # get memory resource info  
        memoutput=`free`
        memtotal=`echo "$memoutput" |awk '/Mem:/{print$2}'`
        memused=`echo "$memoutput" |awk '/Mem:/{print$3}'`
        memArr+=(`echo $memused/$memtotal|bc -l|xargs printf '%.2f'`)
        
        # get cpu resource info  
        cpuoutput=$(top -n 1)
        syUsage=$(echo "$cpuoutput"|awk '/Cpu/{ print $2 }')
        usUsage=$(echo "$cpuoutput"|awk '/Cpu/{ print $4 }')
        cpuArr+=(`echo $syUsage + $usUsage|bc|xargs printf "%.1f"`)

        getcount=`echo $getcount+1|bc`
        # Finish showing resource when getcount equals specified number of times
        if [ $getcount -eq $1 ]; then
            break
        fi

        # sleep at specified interval
        sleep $2
    done
    # Repeat for memory resource info acquisition
    for mempusedes in ${memArr[@]}; do
        # calc sum of memory usage
        sum_mempused=`echo $sum_mempused+$mempusedes|bc -l|xargs printf '%.2f'`
        # calc max of memory usage
        if [ `echo "$max_mempused < $mempusedes"|bc -l` == 1 ]; then
            max_mempused=$mempusedes
            memstarttime=${timeArr[$tmpCount]}
        fi
        tmpCount=`echo $tmpCount+1|bc`
    done
    tmpCount=0

    # Repeat for cpu resource info acquisition
    for cpupusedes in ${cpuArr[@]}; do
        # calc sum of memory usage
        sum_cpupused=`echo $sum_cpupused+$cpupusedes|bc -l|xargs printf '%.2f'`
        # calc max of memory usage
        if [ `echo "$max_cpupused < $cpupusedes"|bc -l` == 1 ]; then
            max_cpupused=$cpupusedes
            cpustarttime=${timeArr[$tmpCount]}
        fi
        tmpCount=`echo $tmpCount+1|bc`
    done
    # calc avg of resource usage
    avg_mempused=`echo $sum_mempused/$getcount|bc -l|xargs printf '%.2f'`
    avg_cpupused=`echo $sum_cpupused/$getcount|bc -l|xargs printf '%.2f'`

    # create display message and request data to OpenAI
    # get total resource infomation
    requestData=`echo "Total Memory Size:"``free -h -t |awk '/Total:/{print $2}'`
    requestData=$requestData`echo "MAX Memory pused: "$max_mempused"%"`$'\n'
    requestData=$requestData`echo "MAX Memory Time: " $memstarttime ""`$'\n'
    requestData=$requestData`echo "AVG Memory pused: "$avg_mempused"%"`$'\n'
    phycpu=1
    mapfile cpu < <( cat /proc/cpuinfo|awk '/cpu cores/{print $4}'|sort -u)
    for cpucore in ${cpu[@]}; do  
        requestData=$requestData`echo "Number of cpu core in Physical CPU$phycpu: $cpucore"`$'\n'
        phycpu=`echo $phycpu+1|bc`
    done
    requestData=$requestData`echo "MAX CPU pused: "$max_cpupused"%"`$'\n'
    requestData=$requestData`echo "MAX CPU Time: " $cpustarttime ""`$'\n'
    requestData=$requestData`echo "AVG CPU pused: "$avg_cpupused"%"`$'\n'
    echo "$requestData"
}

#request to OpenAI
analyze(){
    request=`echo $requestData`
    curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $1" \
    -d "{\"model\": \"gpt-4\",
    \"messages\": [
    {
        \"role\": \"system\",
        \"content\": \"You are a Server performance improvement assistant.\"
    },
    {
        \"role\": \"user\",
        \"content\": \"$request\"
    }
    ]
    }"
}

#display how to getPerfinfo.sh 
usage(){
    cat 1>&2 <<EOF
Usage: bash getResourceinfo.sh [OPTIONS]
Options:
    -c  count of getting resource information
    -p  interval of getting resource information
    -t  output log of result getting resource info
    -a  analyze getting resource info
Example:
    if execute get perf info at 2 times for 2 seconds interval ,
    you execute command the following.
    command: bash getPefinfo.sh -c 10 -p 2
EOF
exit 1
}


count=1
interval=1
OUTPUT_FLAG=0
ANALYZE_FLAG=0

# Get argument
while getopts c:p:ta opt;do
    case $opt in
        c)
            count=${OPTARG} ;;
        p)
            interval=${OPTARG} ;;
        t)
            next_arg=${!OPTIND}
            if [[ $next_arg != -* && ! -z $next_arg ]]; then
                echo "Error: Option '-t' dose not take an argument"
                exit 1
            fi
            OUTPUT_FLAG=1 ;;
        a)
            ANALYZE_FLAG=1 ;;
        *)
            usage ;;
    esac
done


# exec showPerf function and analyze function
if [[ $OUTPUT_FLAG -eq 1 && $ANALYZE_FLAG -eq 1 ]]; then
    echo "Error: Option '-t' and '-a' cannot be executed together."
elif [ $OUTPUT_FLAG -eq 1 ]; then
    showPerf $count $interval > getResourceinfo.log
elif [ $ANALYZE_FLAG -eq 1 ]; then
    echo "###################################################"
    echo "# SHOW STATISTICS RESULT"
    echo "###################################################"
    calcPef $count $interval
    openai_api_key=`env|grep OPENAI_API_KEY|sed -e 's/OPENAI_API_KEY=//'`
    analyzeResult=`analyze $openai_api_key |grep "content"|sed -e 's/"content"://'`
    echo "###################################################"
    echo "# ANALYZE RESULT(As peformance improvement assistant)"
    echo "###################################################"
    echo $analyzeResult
    echo "###################################################"
    echo "###################################################"
else
    showPerf $count $interval
fi
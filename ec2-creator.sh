#!/bin/bash
# Shell script for creating multiple EC2 instances quickly, each with a unique
# Tag.Name value.


# USAGE
#
# 1.    In this script, update values of 7 variables to match your environment.
#       These are the first 7 variables in this script.
#       To find out how to get the values, check
#       https://paulcodr.co/2017/use-shell-script-awscli-to-create-multiple-ec2/
#
#       Lines 48 - 54
#
#
# 2.  Virtualenv in use
# 2.1.  If you are NOT using virtualenv to use AWS CLI,
#       comment out 2 lines that activate and deactivate virtualenv.
#
#       Lines 60, 209
#
# 2.2.  If you ARE using virtualenv for AWS CLI, update the path where
#       you activate it.
#
#       Line    60
#
#       Check following lines are not commented output.
#
#       Lines 60, 209
#
#
# 3.    Running the script
#       ex: ./ec2-creator.sh webserver 1 3
#
#       Script needs 3 parameters given in order.
#       webserver:  Base hostname to use
#       1:          beginning number of instances
#       3:          total quantity of instances to provision.
#
#       Above would create 3 x EC2 instances:
#       webserver1, webserver2, and webserver3


####################################
# Variables

# awscli parameters. These need to be updated
_imageid="ami-46c1b650"
_ec2type="t2.micro"
_key="aws-sshkey2"
_sec_group_id="sg-7643b804"
_block_dev_map="file:///Users/paul/codes/aws-scripts/mapping.json"
_subnet="subnet-e8b790b1"
_user_data="file:///Users/paul/codes/scripts/setup01.sh"




# virtualenv path
_virtualenv_on="${HOME}/python-envs/awscli/bin/activate"



# Following variables are set by arguments given when running this script
declare _basename
declare _start_num
declare _total_count

_basename=$1
_start_num=$2
_total_count=$3



# Filename for logging
_nowDate=`date -u "+%Y%m%d-%H%M%S-%Z" | tr [A-Z] [a-z]`
_logsDir="${HOME}/Documents/awscli-logs"   # ex: /Users/paul/Documents/awscli-logs/
_logFile="awscli-ec2-create-$_nowDate.log"

# END of Variables
####################################



# To allow the script to abort when necessary.
trap "exit 1" TERM
export TOP_PID=$$


# To allow the script to abort when necessary.
function func_quit()
{
   kill -s TERM $TOP_PID
}


# Activate virtualenv for awscli
# source ~/python-envs/awscli/bin/activate
source $_virtualenv_on


# Verify 3 required variables are provided with the script. If it fails, instruction on how to execute properly is shown.
function func-check-3-variables-simple(){
  if [[ -z ${_basename} || -z ${_start_num} || -z ${_total_count} ]]; then
    printf '=%.0s' {1..10} && echo ""

    echo -e "\nScript aborted withOUT performing any changes in AWS because necessary parameters were  not  given with the script."
    echo -e "\nPlease provide 3 variables with the script and try again.\n"
    printf '=%.0s' {1..10} && printf " Script example " && printf '=%.0s' {1..10} && echo ""
    echo "./script.sh webserver 1 3"
    printf '=%.0s' {1..10} && printf " END Script example " && printf '=%.0s' {1..10} && echo ""
    echo -e "\n\n"

    printf '=%.0s' {1..10} && printf " Details of the script and parameters " && printf '=%.0s' {1..10} && echo ""
    echo "webserver   -> Hostname you are using for the EC2"
    echo "1       -> Start number of the instances to build. This gives you webserver1."
    echo "3       -> Total quantity of instances to create. With 3 here, last EC2 instance created is webesrver3."

    echo -e "\nAbove script example creates 3 x EC2 instances: webserver1, webserver2, and webserver3"
    printf '=%.0s' {1..10} && printf " END Details of the script and parameters " && printf '=%.0s' {1..10} && echo ""
    echo -e "\n\n"

    printf '=%.0s' {1..10} && printf " Script exiting without making any changes. " && printf '=%.0s' {1..10} && echo ""

    echo $(func_quit)
  else
    echo -e "\nProceeding with building EC2 instances:\n"
  fi
}


# Run awscli command
function func-run() {
  _end=$((${_start_num} + ${_total_count} - 1))

  mkdir -p ${_logsDir} 2> /dev/null

  printf '=%.0s' {1..10} && printf " Complete log saved in: " && printf '=%.0s' {1..10} && echo -e ""
  echo -e "  ${_logsDir}/${_logFile}\n\n"


  #_new_ec2[0]=${_basename}${_start_num}
  declare -a _new_ec2

  for ((i=${_start_num};i<=${_end};i++)); do
    _new_ec2=("${_new_ec2[@]}" "${_basename}${i}")

    aws ec2 run-instances \
    --image-id $_imageid \
    --count 1 \
    --instance-type $_ec2type \
    --key-name $_key \
    --security-group-ids $_sec_group_id \
    --block-device-mappings $_block_dev_map \
    --subnet-id $_subnet \
    --user-data $_user_data \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$_basename$i}]" \
    --output json >> ${_logsDir}/${_logFile}
  done

  printf '=%.0s' {1..10} && printf " Following EC2 instances will be launched " && printf '=%.0s' {1..10} && echo ""
  echo "Total Quantity: ${#_new_ec2[@]}"
  echo ""
  printf '%s\n' "${_new_ec2[@]}"
  printf '=%.0s' {1..10} && printf " END = Following EC2 instances will be launched " && printf '=%.0s' {1..10} && echo -e "\n\n"
}


# Pull Tag.Name, InstanceID and PublicDNSName
function func-result-query(){

  printf '=%.0s' {1..10} && printf " AWS instances containing name: ${_basename} " && printf '=%.0s' {1..10} && echo ""
  echo -e "NOTE: An instance with no PublicDNSName is either shut off or was recently deleted (takes 10 min+ to completely disappear).\n"
  echo -e "Tag.Name        InstanceID          PublicDNSName\n"

  aws ec2 describe-instances --filters "Name=tag:Name,Values=${_basename}*" --output text --query 'Reservations[].Instances[].[Tags[?Key==`Name`] | [0].Value,   InstanceId,   PublicDnsName]' | sort -n

  printf '=%.0s' {1..10} && printf " END = AWS instances containing name: ${_basename} " && printf '=%.0s' {1..10} && echo -e "\n\n"


  printf '=%.0s' {1..10} && printf " Pulling metadata of EC2 instances " && printf '=%.0s' {1..10} && echo ""
  echo -e "To pull   | Tag.Name | InstanceID | PublicDNSName |   of the EC2 instances with Tag.Name containing ${_basename}, following aws cli command was executed by this script."
  echo -e "\nYou can copy/paste the command below and run it again to pull metadata of EC2 instances."
  echo -e "\nMake sure your virtualenv environment for AWS-cli is active.\n"


  printf '=%.0s' {1..5} && printf " AWS cli command executed " && printf '=%.0s' {1..5} && echo ""

  # Followng 4 lines of code combine to show the exact AWS command to pull metadata of EC2 instances.
  printf "aws ec2 describe-instances --filters \"Name=tag:Name,Values=${_basename}*\""

cat << 'EOF'
 --output text --query 'Reservations[].Instances[].[Tags[?Key==`Name`] | [0].Value, InstanceId, PublicDnsName]' | sort -n
EOF

  printf '=%.0s' {1..5} && printf " END = AWS cli command executed " && printf '=%.0s' {1..5} && echo ""
  printf '=%.0s' {1..10} && printf " END = Pulling metadata of EC2 instances " && printf '=%.0s' {1..10} && echo -e "\n\n"
}    # End of func-result-query





func-check-3-variables-simple
func-run
func-result-query

# Exit from virtualenv environment
deactivate


# END OF SCRIPT

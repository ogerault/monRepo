#!/bin/bash
#title           : deploy.sh
#description     : Pull the code of Taekwonkido and deploy it
#author		 : ogerault
#date            : 20241005
#version         : 1.0    
#usage		 : ./deploy.sh
#notes           : Assume git is installed on the server
#==============================================================================

#
# Functions
#
# logPrint ERR_LEVEL MESSAGE
# ERR_LEVEL:
#   0: OK
#   1: INFO
#   2: WARNING
#   3: ERROR
#   4: FATAL
function logPrint() {
  ERROR_LEVEL=$1
  LOG_MESSAGE=$2
  HTML_MESSAGE=$(echo $LOG_MESSAGE | sed 's/\n/<br \/>\n/g')

  case "$ERROR_LEVEL" in
    4)
      COLOR=$(tput setaf 1) # red
      HTML_COLOR="red"
      TEXT_ERROR_LEVEL=FATAL
      ;;
    3)
      COLOR=$(tput setaf 1) # red
      HTML_COLOR="red"
      TEXT_ERROR_LEVEL=ERROR
      ;;
    2)
      COLOR=$(tput setaf 3) # yellow
      HTML_COLOR="yellow"
      TEXT_ERROR_LEVEL=WARNING
      ;;
    1)
      COLOR=$(tput setaf 4) # blue
      HTML_COLOR="blue"
      TEXT_ERROR_LEVEL=INFO
      ;;
    0)
      COLOR=$(tput setaf 2) # green
      HTML_COLOR="green"
      TEXT_ERROR_LEVEL=OK
      ;;
    *)
      COLOR=$(tput setaf 2) # green
      HTML_COLOR="green"
      TEXT_ERROR_LEVEL=OK
      ;;
  esac
  COLOR_NORMAL=$(tput sgr0) # normal
  printf "%s %s%-9s %s%s\n" "$(date '+%Y/%m/%d %H:%M:%S')" ${COLOR} "[${TEXT_ERROR_LEVEL}]" "${LOG_MESSAGE}" ${COLOR_NORMAL} | tee -a ${LOG_FILE}
  printf "%s <span style='color:%s'>%-9s %s</span><br />\n" "$(date '+%Y/%m/%d %H:%M:%S')" ${HTML_COLOR} "[${TEXT_ERROR_LEVEL}]" "${LOG_MESSAGE}" >> ${TMP_HTML_BODY_MAIL}
}
#
# Mail the report
#
function send_report_mail() {
  if test "${DEST_MAIL}" != ""; then
    (
      echo To: ${DEST_MAIL}
      echo Subject: [TAEKWONKIDO] Deploy result
      echo Content-Type: text/html
      echo
      echo "<span style='font-family: Courier New, Courier'>"
      cat ${TMP_HTML_BODY_MAIL}
      echo "</span>"
    ) | sendmail -t
  fi
}
#
# Do an action with return code control and log
#
function DoAction(){
  ACTION=$1
  LOG_FILE=/tmp/do_action.log

  logPrint 0 "Try to '${ACTION}'..."

  test -f ${LOG_FILE} && rm ${LOG_FILE}
  $(${ACTION}>${LOG_FILE} 2>&1)

  if test $? -ne 0; then
    logPrint 3 "Failed"
    logPrint 1 "Action produced the log:\n$(cat ${LOG_FILE})"
    send_report_mail
    rm ${LOG_FILE}
    exit 1
  fi
  logPrint 0 "Succeed"
  logPrint 1 "Action produced the log:\n$(cat ${LOG_FILE})"
  rm ${LOG_FILE}
}

#
# Define variables
#
SCRIPT_NAME=$0
WORK_DIR=~/ogerault/monRepo
LOG_FILE=~/log/deploy.log
TMP_HTML_BODY_MAIL=/tmp/tmp_mail_body
DEST_MAIL=ogerault@itsgroup.com
BRANCH_NAME=develop

#
# Args management
#
while getopts u:b: flag; do
  case "${flag}" in
    u)
      echo Usage: ${SCRIPT_NAME} [u|b]
      ;;
    b)
      BRANCH_NAME=${OPTARG}
      ;;
  esac
done
if test "${BRANCH_NAME}" != "develop" && test "${BRANCH_NAME}" != "master"; then
  logPrint 4 "Branch name can only be 'develop' or 'master'"
  send_report_mail
  exit 1
fi

#
# Prepare environment
#
cd ${WORK_DIR}
test -f ${TMP_HTML_BODY_MAIL} && rm ${TMP_HTML_BODY_MAIL}
test -d tmp_git_dir && rm -rf tmp_git_dir
mkdir tmp_git_dir
cd tmp_git_dir

#
# Synchronize local repository with GitHub
#
DoAction "git clone --branch ${BRANCH_NAME} https://github.com/stephtkd/tkkd.git"
logPrint 1 "Last commit of the pulled repository \"$(git show --stat)\""
logPrint 1 "Work on branch \"$(git branch)\""

#
# No need to keep github link, so remove .git folder
#
rm -rf .git

#
# Do a composer update
#
DoAction "composer update"

#
# Npm install
#
DoAction "npm install"

#
# Migrate DB (if needed)
#
DoAction "php bin/console doctrine:migrations:migrate"

#
# Send report
#
#send_report_mail
#rm ${TMP_HTML_BODY_MAIL}

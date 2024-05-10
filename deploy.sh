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
  if [[ "${DEST_MAIL}" != "" ]]; then
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
# Compare version of the current script and the pulled one
#
function compareVersion() {
  ACTUAL_SCRIPT=$1
  NEW_SCRIPT=$2

  if [[ ! -f ${NEW_SCRIPT} ]]; then
    logPrint 2 "Unable to find new script. Go on with the current one"
    return
  fi

  VERSION_ACTUAL=$(grep ^#version ${ACTUAL_SCRIPT} | cut -d: -f2 | sed 's/ //g')
  VERSION_NEW=$(grep ^#version ${NEW_SCRIPT} | cut -d: -f2 | sed 's/ //g')

  if [[ ${VERSION_NEW} > ${VERSION_ACTUAL} ]]; then
    logPrint 2 "Pulled script is the latest. Launch it instead"
    chmod +x ${NEW_SCRIPT}
    cd ${SCRIPT_DIR}
    ${NEW_SCRIPT}
    logPrint 0 "Leave the oldest script to avoid duplicate operations"
    exit 0
  fi

  logPrint 0 "Current script seems to be the latest"
}

#
# Define variables
#
SCRIPT_NAME=$0
SCRIPT_DIR=$(pwd)
WORK_DIR=~/ogerault/monRepo
LOG_FILE=~/log/deploy.log
TMP_HTML_BODY_MAIL=/tmp/tmp_mail_body
GIT_BRANCH=$(git branch | cut -d' ' -f2)
DEST_MAIL=ogerault@itsgroup.com

#
# Prepare environment
#
cd ${WORK_DIR}
if [[ -f ${TMP_HTML_BODY_MAIL} ]]; then
  rm ${TMP_HTML_BODY_MAIL}
fi

#
# Synchronize local repository with GitHub
#
logPrint 1 "Working on branch \"${GIT_BRANCH}\""
logPrint 1 "Last commit of the local repository \"$(git show --stat)\""
git pull
logPrint 1 "Last commit of the pulled repository \"$(git show --stat)\""

#
# Compare version of the current script and the pulled one.
# If the new script has a higher version, launch it
#
compareVersion ${SCRIPT_DIR}/${SCRIPT_NAME} ${SCRIPT_DIR}/newScript.sh

#
# Send report
#
#send_report_mail
#rm ${TMP_HTML_BODY_MAIL}

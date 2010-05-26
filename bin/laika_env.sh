#!/bin/sh
# Determines and prints the classpath needed by Laika.  Use this to set the
# environment CLASSPATH, or as the -cp setting on a java or jruby call
FILE_PATH=$BASH_SOURCE
if [ -z $FILE_PATH ]; then
  FILE_PATH=$0
fi
FULL_SCRIPT_PATH="$(cd "${FILE_PATH%/*}" 2>/dev/null; echo "$PWD"/"${FILE_PATH##*/}")"

#echo $FILE_PATH
#echo $0
#echo ${FILE_PATH%/*}
#echo ${FILE_PATH##*/}

PATH_ONLY=`dirname "$FULL_SCRIPT_PATH"`
RAILS_ROOT=${PATH_ONLY%/bin}

#echo $FULL_SCRIPT_PATH
#echo $PATH_ONLY
#echo $RAILS_ROOT

CLASSPATH=$RAILS_ROOT/lib/saxon/saxon9.jar:$RAILS_ROOT/lib/saxon/saxon9-dom.jar

# If the Waldren ccr validator code and supporting libraries have been installed, then
# add them to the class path so that we can validate through them.
CCR_VALIDATION_SERVICE_PATH=vendor/ccr-validation-service
FULL_CCR_PATH=$RAILS_ROOT/$CCR_VALIDATION_SERVICE_PATH
#echo $FULL_CCR_PATH
if [ -d $FULL_CCR_PATH/WEB-INF/lib ]; then
  # add all the jars
  CLASSPATH=$CLASSPATH:$FULL_CCR_PATH/WEB-INF/lib/*
fi
if [ -d $FULL_CCR_PATH/WEB-INF/classes ]; then
  CLASSPATH=$CLASSPATH:$FULL_CCR_PATH/WEB-INF/classes
fi
echo $CLASSPATH
export CLASSPATH

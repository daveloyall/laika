#!/bin/sh
# Determines and prints the classpath needed by Laika.  Use this to set the
# environment CLASSPATH, or as the -cp setting on a java or jruby call
FULL_SCRIPT_PATH="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
PATH_ONLY=`dirname "$FULL_SCRIPT_PATH"`
RAILS_ROOT=${PATH_ONLY%/bin}

CLASSPATH=$RAILS_ROOT/lib/saxon/saxon9.jar:$RAILS_ROOT/lib/saxon/saxon9-dom.jar

# If the Waldren ccr validator code and supporting libraries have been installed, then
# add them to the class path so that we can validate through them.
CCR_VALIDATION_SERVICE_PATH=vendor/ccr-validation-service
if [ -d $RAILS_ROOT/$CCR_VALIDATION_SERVICE_PATH/WEB-INF/lib ]; then
  # add all the jars
  CLASSPATH=$CLASSPATH:/home/jpartlow/dev/osourcery/elbe/ccrvalidator/ccrvalidator-0.9-war/WEB-INF/lib/*
fi
if [ -d $RAILS_ROOT/$CCR_VALIDATION_SERVICE_PATH/WEB-INF/classes ]; then
  CLASSPATH=$CLASSPATH:/home/jpartlow/dev/osourcery/elbe/ccrvalidator/ccrvalidator-0.9-war/WEB-INF/classes
fi
echo $CLASSPATH
export CLASSPATH

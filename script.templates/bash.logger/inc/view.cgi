#!/bin/sh

cd "../${logDirs[$LOG_FILE_DIR]}"

echo "<div class='log-viewer'>"
echo "<pre id='code'>"

#LogLineNum=$( tail -n 100 "$LOG_FILE_NAME" | grep "getModels" | wc -l )
#Grep=$( tail -n 100 "$LOG_FILE_NAME" | grep "getModels")

LogBody=$( tail -n 200 $LOG_FILE_NAME )

LogBody=$(echo "${LogBody//$'\n'/</code><code>}") #Replace /n to <code> tag
LogBody=$(echo "${LogBody//$'[32m'/<span style='color: #00A000;' />}") #Green
LogBody=$(echo "${LogBody//$'[36m'/<span style='color: #009E9E;' />}") #Blue
LogBody=$(echo "${LogBody//$'[35m'/<span style='color: #A000A0;' />}") #Purple
LogBody=$(echo "${LogBody//$'[0;39m'/</span />}") #End of tag

echo "<code>$LogBody</code>"
echo "</pre>"
echo "</div>"

echo '<script type="text/javascript"> $(document).ready(function(){setTimeout(function(){'
echo 'window.location.reload(1) }, 15000); });'
echo '</script>'
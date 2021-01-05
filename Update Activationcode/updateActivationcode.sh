#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
# THE SCRIPTS ARE PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
# I BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, 
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
# THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# 
# This script is designed to update Jamf Pro Server activationcode
#
# version 1.0
# Written by: 	Mischa van der Bent	2020
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Directory/Path
projectfolder=$(dirname "$0")
file=${projectfolder}/activationcode.csv			#Path to the CSV

# Path to CSV file
updateLogPath=${projectfolder}
updateLog=${updateLogPath}/Activationcode-$(date '+%d-%m-%Y_%H:%M:%S')".csv"

### Create the CSV file with headers ###
function updateLogFile () {
	if [[ ! -d ${updateLogFile} ]] ; then
		/bin/mkdir -p ${updateLogPath}
	fi
}

updateLogFile

# Creat csv file headers
echo "Jamf Pro Server;Organization Name;Updated-Activationcode;Previous-Activationcode;Alerts;Status" >> ${updateLog}

#Variables
APIuser="apiuser"                           		#JPS username with API privileges
#APIpassword=""                           			#Password for the JPS account

# Add APIpassword in your macOS Keychain, and add the security binary to "Always allow access by these applications:" list in this entry
# security add-generic-password -s APIHash -a apiuser -w ############ -T /usr/bin/security
APIpassword=$(security find-generic-password -s "APIHash" -w) 	#Use your service name by [-s "APIHash"]

#Option to read in the path from Terminal
if [[ "$file" == "" ]]; then
	echo "Please enter the path to the CSV"
	read file
fi

#Verify we can read the file
data=`cat $file`
if [[ "$data" == "" ]]; then
	echo "Unable to read the file path specified"
	echo "Ensure there are no spaces and that the path is correct"
	exit 1
fi

#Find how many activationcode to update
activationcodeqty=`awk -F, 'END {printf "%s\n", NR}' $file`

#Set a counter for the loop
counter="0"

#Loop through the CSV and submit data to the API
while [ $counter -lt $activationcodeqty ]
do
	counter=$[$counter+1]
	line=`echo "$data" | head -n $counter | tail -n 1`
	JamfProURL=`echo "$line" | awk -F , '{print $1}'`
	activationcode=`echo "$line" | awk -F , '{print $2}'`

	echo "Attempting to update code on ${JamfProURL} : ${activationcode}"
	
	# credentials check
	credentialscheck=$(curl -s -k --header "Accept: application/xml" -u ${APIuser}:${APIpassword} https://$JamfProURL/JSSResource/activationcode | grep activation_code | wc -l | xargs)
	if [ "$credentialscheck" == "0" ]; then
		echo "${JamfProURL};;${activationcode};;Error connecting to Jamf API. Incorrect URL or Credentials" >> ${updateLog}
	else

	# Organization name 
	organizationName=$(curl -s -k --header "Accept: application/xml" -u $APIuser:${APIpassword}  https://$JamfProURL/JSSResource/activationcode | xmllint --format - | awk -F'>|<' '/<organization_name>/{print $3}')

	# Previous-Activationcode 
	oldActivationcode=$(curl -s -k --header "Accept: application/xml" -u ${APIuser}:${APIpassword} https://$JamfProURL/JSSResource/activationcode | xmllint --format - | awk -F'>|<' '/<code>/{print $3}')
	
	# Construct the XML
	XMLData="<activation_code><organization_name>${organizationName}</organization_name><code>${activationcode}</code></activation_code>"

	# flattened XML
	flatXML=$( /usr/bin/xmllint --noblanks - <<< "$XMLData" )
	
	# API PUT Command
#	curl -ksu ${APIuser}:${APIpassword} https://$JamfProURL/JSSResource/activationcode --header "Content-Type: text/xml" --request PUT --data $flatXML
		
	# Log Result
	echo "${JamfProURL};${organizationName};${activationcode};${oldActivationcode};;Completed" >> ${updateLog}
	
	fi
done

open -a Numbers ${updateLog}
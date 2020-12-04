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
# This script is designed to check Jamf Pro Server version
#
# version 1.0
# Written by: 	Mischa van der Bent	2020
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Directory/Path
projectfolder=$(dirname "$0")
file=${projectfolder}/serverlist.csv

# Path to CSV file
updateLogPath=${projectfolder}
updateLog=${updateLogPath}/JPSversions-$(date '+%d-%m-%Y_%H:%M:%S')".csv"

# Check if Python is installed.
if which python > /dev/null 2>&1;
then
	echo "Python is installed"
else
	echo "Python is not installed, please install Python to run this script"
	exit 1
fi

### Create the CSV file with headers ###
function updateLogFile () {
	if [[ ! -d ${updateLogFile} ]] ; then
		/bin/mkdir -p ${updateLogPath}
	fi
}

updateLogFile

# Create csv file headers
echo "Jamf Pro Server,Organization Name,Version,Method,Alerts,Status" >> ${updateLog}

# Login credentials
APIuser="apiuser"		#JPS username with API privileges
#APIpassword=""			#Password for the JPS account

# Add APIpassword in your macOS Keychain, and add the security binary to "Always allow access by these applications:" list in this entry
# security add-generic-password -s APIHash2 -a apiuser -w ############ -j versioncheck -T /usr/bin/security
APIpassword=$(security find-generic-password -s "APIHash" -w)		#Use your service name by [-s "APIHash"]

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

#Find how many Servers to check
serverqty=`awk -F, 'END {printf "%s\n", NR}' $file`

#Set a counter for the loop
counter="0"

#Loop through the CSV and submit data to the API
while [ $counter -lt $serverqty ]
do
	counter=$[$counter+1]
	line=`echo "$data" | head -n $counter | tail -n 1`
	JamfProURL=`echo "$line" | awk -F , '{print $1}'`
	organization_name=`echo "$line" | awk -F , '{print $2}'`
	
	
	version=$(curl -sL https://"$JamfProURL"/ | grep "<title>" | cut -d">" -f2 | cut -d"<" -f1 | cut -d" " -f7)
	if [[ ${version} ]]; then
		method="HTML"
		echo "$version - $server"
		echo ${JamfProURL},${organization_name},${version},"${method}",,Completed >> ${updateLog}
		else

	method="New UAPI"
	# credentials check
	credentialscheck=$(curl -s -k --header "Accept: application/xml" -u ${APIuser}:${APIpassword} https://$JamfProURL/JSSResource/activationcode | grep activation_code | wc -l | xargs)
		if [ "$credentialscheck" == "0" ]; then
			echo "${JamfProURL},${organization_name},${activationcode},${method},Error connecting to Jamf API. Incorrect URL or Credentials" >> ${updateLog}
		else
			
	organizationName=$(curl -s -k --header "Accept: application/xml" -u $APIuser:${APIpassword}  https://$JamfProURL/JSSResource/activationcode | xmllint --format - | grep "<organization_name>" | sed -e 's/<[^>]*>/ /g')
	
	# created base64-encoded credentials
	encodedCredentials=$( printf "${APIuser}:${APIpassword}" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
		
	# generate an auth token
	authToken=$( /usr/bin/curl "https://$JamfProURL/uapi/auth/tokens" \
	--silent \
	--request POST \
	--header "Authorization: Basic $encodedCredentials" )
	
	# parse authToken for token, omit expiration
	token=$( /usr/bin/awk -F \" '{ print $4 }' <<< "$authToken" | /usr/bin/xargs )
	
	version=$(curl -X GET "https://$JamfProURL/api/v1/jamf-pro-version" -H "accept: application/json" -H "Authorization: Bearer ${token}" | python -m json.tool | awk -F\" '/version/{print $4}')
	
	echo "${version} - ${JamfProURL} - ${organizationName}"

	# expire the auth token
	curl "https://${JamfProURL}/uapi/auth/invalidateToken" \
	--silent \
	--request POST \
	--header "Authorization: Bearer ${token}"
		
	# Log Result
	echo ${JamfProURL},${organizationName},${version},${method},,Completed >> ${updateLog}
	
	fi
	fi
	
done

open -a Numbers ${updateLog}

	
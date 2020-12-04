#!/bin/sh

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
# This script is designed to preform a Device Count on an Jamf Pro Server and make a report
#
# version 1.0
# Written by: 	Mischa van der Bent	2020
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


# Directory/Path
projectfolder=$(dirname "$0")

# Path to CSV file
devicesCSVPath=${projectfolder}
devicesCSV=${devicesCSVPath}/Devices-list-$(date '+%d-%m-%Y_%H:%M:%S').csv

### Create the CSV file ###
function devicesCSVFile () {
	if [[ ! -d ${devicesCSVFile} ]] ; then
		/bin/mkdir -p ${devicesCSVPath}
	fi
}

devicesCSVFile

function check_jamf {
	echo "Checking credentials..."
	jssURL=$1
	APIuser=$2
	APIpassword=$3
	
	# credentials check
	credentialscheck=$(curl -s -k --header "Accept: application/xml" -u $APIuser:${APIpassword} https://$JamfProURL/JSSResource/activationcode | grep activation_code | wc -l | xargs)
	if [ "$credentialscheck" == "0" ]; then
		echo "Error connecting to Jamf API. Incorrect URL or Credentials"
		exit
	fi
	
	activationcode=$(curl -s -k --header "Accept: application/xml" -u $APIuser:${APIpassword}  https://$JamfProURL/JSSResource/activationcode | xmllint --format - | grep "<code>" | sed -e 's/<[^>]*>/ /g')
	organizationName=$(curl -s -k --header "Accept: application/xml" -u $APIuser:${APIpassword}  https://$JamfProURL/JSSResource/activationcode | xmllint --format - | grep "<organization_name>" | sed -e 's/<[^>]*>/ /g')
}



if [ -z "$1" ]; then
	echo "Please enter your Jamf Pro URL (example mdm.jamfcloud.com or mdm.domain.com:8443)"
	read -p "JamfProURL :	" JamfProURL
else
	JamfProURL=$1
fi

if [ -z "$2" ]; then
	echo "\nPlease enter your Jamf Pro API account name for"
	read -p "$JamfProURL :	" APIuser
else
	APIuser=$2
fi

if [ -z "$3" ]; then
	echo "\nPlease enter your password for API account"
	read -p "$APIuser :	" -s APIpassword
else
	APIpassword=$3
fi

echo "\n"
check_jamf $JamfProURL $APIuser $APIpassword

echo "checking $JamfProURL..."	
sleep 5

# get managed computers

managedComp=0
unManagedComp=0

for i in $(/usr/bin/curl -sku $APIuser:${APIpassword} -H "Accept: application/xml" https://$JamfProURL/JSSResource/computers | xmllint --xpath "/computers/computer/id" - | sed -e 's/<[^>]*>/ /g'); do
#for i in $(/usr/bin/curl -k -s -H "Accept: application/xml" -u $jamfUser:${jamfPass} https://$jamfUrl/JSSResource/computers | xmllint --xpath /computers/computer/id - | sed -e 's/<[^>]*>/ /g'); do
	
	status=$(/usr/bin/curl -sku $APIuser:${APIpassword} -H "Accept: application/xml" https://$JamfProURL/JSSResource/computers/id/$i/subset/general | xmllint --xpath "/computer/general/remote_management/managed/text()" -)
			if [[ $status = true ]];then
				#echo $status
					managedComp=$(( managedComp+1 ))
				else
					unManagedComp=$(( unManagedComp+1 ))
			fi
	done

computerCount=$(/usr/bin/curl -s -u $APIuser:${APIpassword} https://$JamfProURL/JSSResource/computers | sed -n -e 's/.*<size>\(.*\)<\/size>.*/\1/p')
mobiledevicesCount=$(/usr/bin/curl -s -u $APIuser:${APIpassword} https://$JamfProURL/JSSResource/mobiledevices | sed -n -e 's/.*<size>\(.*\)<\/size>.*/\1/p')

managediOS=0
unManagediOS=0
managedTV=0
unManagedTV=0

for i in $(/usr/bin/curl -sku $APIuser:${APIpassword} -H "Accept: application/xml" https://$JamfProURL/JSSResource/mobiledevices | xmllint --xpath "/mobile_devices/mobile_device/id" - | sed -e 's/<[^>]*>/ /g'); do
	
	# For Testing
	#echo $i
	
	inv=$(/usr/bin/curl -sku $APIuser:${APIpassword} -H “Accept: application/xml” https://$JamfProURL/JSSResource/mobiledevices/id/$i/subset/general)
	status=$(echo $inv | xmllint --xpath "/mobile_device/general/managed/text()" -)
	model=$(echo $inv | xmllint --xpath "/mobile_device/general/model/text()" - | awk '{print $1}')
	
	# For Testing
	# echo $i - $status - $model
	
			if [[ $status = true ]];then
				
					if [[ $model  = Apple ]];then
						managedTV=$(( managedTV+1 ))
						else
						managediOS=$((managediOS+1))
					fi
				else
					if [[ $model  = Apple ]];then
						unManagedTV=$(( unManagedTV+1 ))
						else
						unManagediOS=$((unManagediOS+1))
					fi

			fi
	done

echo $managedComp macOS managed
echo $unManagedComp macOS unmanaged
echo $managediOS iOS managed
echo $unManagediOS iOS unmanaged
echo $managedTV Apple TV managed
echo $unManagedTV Apple TV unManagediOS

# Creat csv file headers
echo ",," > "$devicesCSV"
echo Jamf Pro Server,$JamfProURL >> "$devicesCSV"
echo Activationcode,$activationcode >> "$devicesCSV"
echo Organization Name,$organizationName >> "$devicesCSV"
echo ",," >> "$devicesCSV"
echo Total Computers,$computerCount >> "$devicesCSV"
echo Total Mobile Devices,$mobiledevicesCount >> "$devicesCSV"
#echo ",Managed,unManaged" > "$devicesCSV"
echo "",Managed,Unmanaged >> "$devicesCSV"
echo Managed Computers,$managedComp >> "$devicesCSV"
echo unmanaged Computers,,$unManagedComp >> "$devicesCSV"
echo Managed iPhones and iPads,$managediOS >> "$devicesCSV"
echo unManaged iPhones and iPads,,$unManagediOS >> "$devicesCSV"
echo Managed AppleTVs,$managedTV >> "$devicesCSV"
echo unManaged AppleTVs,,$unManagedTV >> "$devicesCSV"
echo "">> "$devicesCSV"

open -a Numbers "$devicesCSV"

exit 0
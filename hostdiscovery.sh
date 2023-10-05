#!/bin/bash

CYAN="\033[0;36m";
RED="\033[0;31m";
C="\033[0m";

discover_hosts() {
	PROJECT=$1;
	echo -e "${CYAN}[#] Beginning host discovery...${C}";
	
	# ping scan with TCP SYN/ACK
	nmap -sn -PS -n --min-hostgroup 256 --min-rate 1000 --max-rate 2500 --max-rtt-timeout 200ms --max-retries 2 -oA "./${PROJECT}/nmap/ping" -iL "./${PROJECT}/fullscope.txt";

	# common ports
	COMMON="-PS21,22,23,25,135,139,445,3389,1433,80,443,8080,8443,90,3268,110,53,3306,1723,111,995,993,5900,1025,1720,465,548,5060,8000,515,2049,6000,389,5432";
	nmap -iL "./${PROJECT}/fullscope.txt" -PE -PP -PM -sn -T4 --max-retries 3 --max-rtt-timeout 300ms -oA "./${PROJECT}/nmap/common" -n --reason --open "${COMMON}";
	
	# SYN scan for top 1000 ports
	nmap -sS -Pn -n --open --top-ports 1000 --min-hostgroup 256 --min-rate 1000 --max-rate 2500 --max-rtt-timeout 200ms --max-retries 2 -oA "./${PROJECT}/nmap/top1000" -iL "./${PROJECT}/fullscope.txt";

	# combine the results into a temp file
	echo -e "${CYAN}[#] Host discovery scans completed. Extracting results..${C}";
	cat "./${PROJECT}/nmap/common.gnmap" | grep -v '# Nmap'| awk '/Status:\/\s/Up {print $2}' | sort -u > "./${PROJECT}/tmp_discovered.txt";
	cat "./${PROJECT}/nmap/ping.gnmap" | grep -v '# Nmap' | awk '/Status:\/\s/Up {print $2}' | sort -u | tee -a "./${PROJECT}/tmp_discovered.txt";
	cat "./${PROJECT}/nmap/top1000.gnmap" | grep -v '# Nmap' | awk '/Status:\/\s/Up {print $2}' | sort -u | tee -a "./${PROJECT}/tmp_discovered.txt";
	
	# export the results to the "discovered_hosts.txt" file
	echo -e "${CYAN}[#] Live hosts extracted, compiling results..${C}";
	cat "./${PROJECT}/tmp_discovered.txt" | sort -u > "./${PROJECT}/discovered_hosts.txt" && rm "./${PROJECT}/tmp_discovered.txt";
	
	echo -e "${CYAN}[#] Host discovery completed!${C}";
}

zip_results() {
	PROJECT=$1;
	# ensure zip is installed
	if [ "$(which zip > /dev/null; echo $?;)" -ne 0 ]; then
		echo -e "${RED}[! ERROR]  Zip isn't found. Unable to compress the results for you.${C}";
		echo -e "${CYAN}[# ACTION] Copy the files/folders out yourself, re-run the script, or zip manually${C}";
	else
		# zip up up the project
		RESULTS_FILENAME="${PROJECT}_$(date '+%F').zip";
		zip -r "./${RESULTS_FILENAME}" "./${PROJECT}";
		echo -e "${CYAN}[#] Resulting files compressed into ${RESULTS_FILENAME}${C}";
		ls -la | grep "${PROJECT}";
	fi
}

pre_req() {
	# nmap should be installed
	if [ "$(which nmap >/dev/null; echo $?)" -ne 0 ]; then
		echo -e "${RED}[! ERROR]  Nmap isn't found. That means this isn't going to work out well for you.${C}";
		echo -e "${CYAN}[# ACTION] Install Nmap and execute this script again.${C}";
		exit 1;
	fi

	# the script should have elevated priv
	if [ "${EUID}" -ne 0 ]; then
		echo  -e "${RED}[! ERROR]  Nmap needs to be run with root privileges to execute particular scans.${C}";
		echo  -e "${CYAN}[# ACTION] Execute this script with \"sudo\" or as the \"root\" user account.${C}";
		exit 1;
	fi

	# the fullscope.txt file should be in the same directory
	if [ ! -f "./fullscope.txt" ]; then
		echo  -e "${RED}[! ERROR]  Please ensure all inscope ranges and hosts are in a file named 'fullscope.txt'.${C}";
		echo  -e "${CYAN}[# ACTION] Populate the file and rerun this script.${C}";
		exit 1;
	fi
}

# ensure we are good to go
pre_req;

# prompt for the project name
echo  -e "${CYAN}[>] Provide a Name for the Project:${C}";
read PROJECT;

# create the project directory
PROJECTPATH="./${PROJECT}";
if [ -d "${PROJECTPATH}" ]; then
	echo  -e "${RED}[! ERROR]  A project directory with this name already exists.${C}";
	echo  -e "${CYAN}[# ACTION] Rename or remove the existing project named ${PROJECT} and execute this script again.${C}";
	exit 1;
else
	# create the project directory
	/bin/mkdir -p "./${PROJECTPATH}/nmap";
fi

# convert the fullscope to a new list, to ensure that all of the ranges are exploded:
nmap -sL -n -iL "./fullscope.txt" | cut -d " " -f 5 | grep -iv "addresses\\|nmap" | sort -u > "./${PROJECTPATH}/fullscope.txt";
echo -e "${CYAN}[#] The scope file has been exploded and moved into project directory.";

# do additional work
discover_hosts "${PROJECT}";
zip_results "${PROJECT}";

exit 0;
